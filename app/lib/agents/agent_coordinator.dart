import 'dart:async';

import 'package:dio/dio.dart';
import 'package:eyesense/agents/agent_task.dart';
import 'package:eyesense/agents/conversation_agent.dart';
import 'package:eyesense/agents/reading_agent.dart';
import 'package:eyesense/agents/output_policy.dart';
import 'package:eyesense/agents/scene_agent.dart';
import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:eyesense/models/app_operation.dart';
import 'package:eyesense/models/presentation_record.dart';
import 'package:eyesense/models/scene_result.dart';
import 'package:eyesense/services/camera_service.dart';
import 'package:eyesense/services/credential_service.dart';
import 'package:eyesense/services/diagnostic_log_service.dart';
import 'package:eyesense/services/earcon_service.dart';
import 'package:eyesense/services/haptic_service.dart';
import 'package:eyesense/services/ocr_service.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:eyesense/services/providers/openai_compatible_provider.dart';
import 'package:eyesense/services/providers/hosted_provider.dart';
import 'package:eyesense/services/speech_feedback_coordinator.dart';
import 'package:eyesense/services/speech_service.dart';
import 'package:eyesense/services/tts_service.dart';
import 'package:eyesense/services/vision_api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

enum ActiveWork { voiceCommand, describe, readText, ask }

class AgentCoordinator extends ChangeNotifier {
  final CameraService cameraService;
  final TtsService ttsService;
  final SpeechService speechService;
  final OcrService ocrService;
  final HapticService hapticService;
  final PreferencesService preferencesService;
  final CredentialService credentialService;
  final DiagnosticLogService logService;
  final DateTime Function() _nowProvider;
  late final SpeechFeedbackCoordinator speechFeedbackCoordinator;
  late final EarconService earconService;

  late SceneAgent sceneAgent;
  late final ReadingAgent readingAgent;
  late final ConversationAgent conversationAgent;

  OperationState _state = OperationState.idle;
  AppMode _currentMode = AppMode.describe;
  int _currentGeneration = 0;
  String? _lastResultText;
  SceneResult? _lastSceneResult;
  PresentationRecord? _lastPresentation;
  String? _errorMessage;
  CancelToken? _activeCancelToken;
  ActiveWork? _activeWork;
  DateTime? _lastGuidanceCueAt;
  String? _lastGuidancePhrase;
  late bool _previousCloudConsent;

  bool get _acceptsTask =>
      _state == OperationState.idle || _state == OperationState.error;

  OperationState get state => _state;
  AppMode get currentMode => _currentMode;
  ActiveWork? get activeWork => _activeWork;
  String? get lastResultText => _lastResultText;
  SceneResult? get lastSceneResult => _lastSceneResult;
  PresentationRecord? get lastPresentation => _lastPresentation;
  String? get errorMessage => _errorMessage;

  AgentCoordinator({
    required this.cameraService,
    required this.ttsService,
    required this.speechService,
    required this.ocrService,
    required this.hapticService,
    required this.preferencesService,
    required this.credentialService,
    required this.logService,
    VisionApiService? visionApi,
    DateTime Function()? nowProvider,
    EarconService? earcons,
  }) : _nowProvider = nowProvider ?? DateTime.now {
    speechFeedbackCoordinator = SpeechFeedbackCoordinator(
      ttsService: ttsService,
      hapticService: hapticService,
      now: nowProvider,
    );
    earconService = earcons ?? EarconService(preferencesService, ttsService);
    _currentMode = preferencesService.appMode;
    refreshVisionProvider(visionApi);
    readingAgent = ReadingAgent(
      prefs: preferencesService,
      logService: logService,
    );
    conversationAgent = ConversationAgent(logService: logService);
    _previousCloudConsent = preferencesService.cloudConsentGranted;
    preferencesService.addListener(_onPreferencesChanged);
  }

  void _onPreferencesChanged() {
    final consent = preferencesService.cloudConsentGranted;
    if (_previousCloudConsent &&
        !consent &&
        (_activeWork == ActiveWork.describe ||
            _activeWork == ActiveWork.ask ||
            _activeCancelToken != null)) {
      cancelActiveWork();
    }
    _previousCloudConsent = consent;
  }

  void refreshVisionProvider([VisionApiService? visionApi]) {
    final api = visionApi ?? _createVisionApi();
    sceneAgent = SceneAgent(visionApi: api, logService: logService);
  }

  VisionApiService _createVisionApi() {
    if (preferencesService.providerMode == ProviderMode.byok) {
      final provider = preferencesService.directAiProvider;
      return OpenAiCompatibleVisionProvider(
        credentialService: credentialService,
        provider: provider,
        model: preferencesService.visionModelFor(provider),
      );
    }
    return HostedVisionProvider(
      credentialService: credentialService,
      baseUrl: preferencesService.apiBaseUrl,
    );
  }

  void _setState(OperationState newState, {String? announcement}) {
    _state = newState;
    notifyListeners();
    if (announcement != null &&
        announcement.isNotEmpty &&
        newState != OperationState.speaking) {
      speechFeedbackCoordinator.speakStatus(announcement);
    }
  }

  void setMode(AppMode mode) {
    if (_currentMode == mode) return;
    stop();
    _currentMode = mode;
    unawaited(preferencesService.setAppMode(mode));
    notifyListeners();
    speechFeedbackCoordinator.speakStatus(mode.displayName);
  }

  void announceCurrentMode() {
    speechFeedbackCoordinator.speakStatus(
      'Current mode: ${currentMode.displayName}',
    );
  }

  /// Cancels network work and playback without a spoken announcement.
  /// Used when the app is backgrounded, including during a permission dialog
  /// that has already been separated from the operation.
  Future<void> suspend() async {
    cancelActiveWork();
    await cameraService.dispose();
  }

  /// Cancels route-owned work without speaking after the user has left it.
  void cancelActiveWork() {
    _currentGeneration++;
    _activeCancelToken?.cancel('Cancelled');
    _activeCancelToken = null;
    _activeWork = null;
    unawaited(cameraService.cancelPendingCapture());
    unawaited(speechService.cancel());
    unawaited(earconService.stopLoop());
    unawaited(speechFeedbackCoordinator.stopAll());
    _errorMessage = null;
    _state = OperationState.idle;
    notifyListeners();
  }

  /// Cancels all active operations, stops speech, invalidates generations.
  void stop() {
    cancelActiveWork();
    unawaited(speechFeedbackCoordinator.interruptWith('Stopped'));
  }

  void dismissError() {
    if (_state != OperationState.error) return;
    _errorMessage = null;
    _state = OperationState.idle;
    notifyListeners();
  }

  Future<void> repeatLast() async {
    if (_state == OperationState.capturing ||
        _state == OperationState.processingCloud ||
        _state == OperationState.processingLocal ||
        _state == OperationState.listening) {
      speechFeedbackCoordinator.speakStatus(
        'Cannot repeat while an operation is in progress. Use Stop first.',
      );
      return;
    }

    if (_lastPresentation != null) {
      _lastPresentation = _lastPresentation!.asPrevious();
      notifyListeners();
      await _speakText(
        _lastPresentation!.toSpokenText(),
        _currentGeneration,
        force: true,
      );
    } else if (_lastResultText != null && _lastResultText!.isNotEmpty) {
      await _speakText(
        'Previous result: $_lastResultText',
        _currentGeneration,
        force: true,
      );
    } else {
      speechFeedbackCoordinator.speakStatus(
        'No previous description available.',
      );
    }
  }

  Future<void> executeDescribe() async {
    if (!_acceptsTask) return;
    if (!preferencesService.cloudConsentGranted) {
      await _handleError(
        const AppException(
          code: ErrorCode.cloudConsentRequired,
          userMessage: 'Cloud processing requires consent. Enable it in Settings, or use Read Text offline.',
        ),
      );
      return;
    }

    final gen = ++_currentGeneration;
    _activeCancelToken?.cancel('Superseded by new operation');
    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;
    _activeWork = ActiveWork.describe;
    _errorMessage = null;
    CapturedImageData? captured;

    try {
      _setState(OperationState.capturing, announcement: 'Taking a picture');
      await hapticService.confirmAction();
      if (gen != _currentGeneration) return;
      unawaited(earconService.play(Earcon.shutter));

      captured = await _captureWithGuidance(gen);
      if (gen != _currentGeneration) return;

      if (!preferencesService.cloudConsentGranted) {
        throw const AppException(
          code: ErrorCode.cloudConsentRequired,
          userMessage: 'Cloud consent was revoked.',
        );
      }

      unawaited(earconService.play(Earcon.processing));
      _setState(
        OperationState.processingCloud,
        announcement: 'Describing scene',
      );

      final task = AgentTask(
        requestId: const Uuid().v4(),
        generation: gen,
        role: AgentRole.scene,
        providerMode: preferencesService.providerMode,
        captureTimestamp: captured.timestamp,
        maxCalls: AppConfig.maxModelCallsPerOperation,
        timeout: AppConfig.clientTimeout,
      );

      final result = await sceneAgent.execute(
        task: task,
        base64Jpeg: captured.base64Jpeg,
        language: preferencesService.language,
        currentGeneration: _currentGeneration,
        cancelToken: cancelToken,
        nowProvider: _nowProvider,
      );
      if (gen != _currentGeneration) return;

      final presentation = PresentationRecord(
        kind: TaskKind.describe,
        timestamp: _nowProvider(),
        responseText: result.summary,
        possibleConcern: result.possibleConcern,
        concernDescription: result.concernDescription,
        uncertainty: result.uncertainty,
        status: PresentationStatus.current,
      );

      _lastSceneResult = result;
      _lastResultText = result.summary;
      _lastPresentation = presentation;
      notifyListeners();

      if (result.possibleConcern) {
        await hapticService.indicateConcern();
        unawaited(earconService.play(Earcon.concern));
      } else {
        unawaited(earconService.play(Earcon.success));
      }
      await earconService.stopLoop();
      await _speakPresentation(presentation, gen);
    } catch (e) {
      if (gen != _currentGeneration) return;
      await earconService.stopLoop();
      await _handleError(e);
    } finally {
      if (gen == _currentGeneration && _activeWork == ActiveWork.describe) {
        _activeWork = null;
      }
      if (_activeCancelToken == cancelToken) _activeCancelToken = null;
      await cameraService.deleteTemporaryCapture(captured?.file);
      notifyListeners();
    }
  }

  /// On-device OCR. ML Kit's processImage cannot be aborted; Stop invalidates
  /// the generation, halts playback and discards the text when it arrives.
  /// The recognition itself keeps running until the platform call returns.
  Future<void> executeReadText() async {
    if (!_acceptsTask) return;
    final gen = ++_currentGeneration;
    _activeCancelToken?.cancel('Superseded by new operation');
    _activeCancelToken = null;
    _activeWork = ActiveWork.readText;
    _errorMessage = null;
    CapturedOcrData? captured;

    try {
      _setState(OperationState.capturing, announcement: 'Taking a picture');
      await hapticService.confirmAction();
      if (gen != _currentGeneration) return;
      unawaited(earconService.play(Earcon.shutter));

      captured = await cameraService.captureForOcr(
        onGuidance: preferencesService.aimingGuidance
            ? (phrase) {
                if (gen == _currentGeneration) _onGuidance(phrase);
              }
            : null,
      );
      if (gen != _currentGeneration) return;

      _setState(OperationState.processingLocal, announcement: 'Reading text');

      final text = await ocrService.recognizeText(captured.file);
      if (gen != _currentGeneration) return;

      _lastSceneResult = null;
      final presentation = PresentationRecord(
        kind: TaskKind.readText,
        timestamp: _nowProvider(),
        responseText: text,
        possibleConcern: false,
        status: PresentationStatus.current,
      );

      _lastResultText = text;
      _lastPresentation = presentation;
      notifyListeners();
      unawaited(earconService.play(Earcon.success));
      await _speakPresentation(presentation, gen);
    } catch (e) {
      if (gen != _currentGeneration) return;
      await _handleError(e);
    } finally {
      if (gen == _currentGeneration && _activeWork == ActiveWork.readText) {
        _activeWork = null;
      }
      await cameraService.deleteTemporaryCapture(captured?.file);
      notifyListeners();
    }
  }

  Future<void> executeAskQuestion(String question) async {
    if (!_acceptsTask) return;
    if (OutputPolicy.isNavigationQuestion(question)) {
      final gen = ++_currentGeneration;
      _activeWork = null;
      _errorMessage = null;
      _lastSceneResult = null;
      final text = OutputPolicy.navigationLimitation(
        preferencesService.language,
      );
      final presentation = PresentationRecord(
        kind: TaskKind.askQuestion,
        timestamp: _nowProvider(),
        responseText: text,
        possibleConcern: false,
        status: PresentationStatus.current,
      );
      _lastResultText = text;
      _lastPresentation = presentation;
      notifyListeners();
      await _speakPresentation(presentation, gen);
      return;
    }
    if (!preferencesService.cloudConsentGranted) {
      await _handleError(
        const AppException(
          code: ErrorCode.cloudConsentRequired,
          userMessage: 'Cloud processing requires consent. Enable it in Settings, or use Read Text offline.',
        ),
      );
      return;
    }

    final trimmedQuestion = question.trim();
    if (trimmedQuestion.isEmpty) {
      await speechFeedbackCoordinator.interruptWith(
        'Say or type a question first.',
      );
      return;
    }

    if (trimmedQuestion.length > AppConfig.maxQuestionCharacters) {
      await _handleError(
        const AppException(
          code: ErrorCode.validationFailed,
          userMessage: 'That question is longer than 300 characters. Ask a shorter question.',
        ),
      );
      return;
    }

    final gen = ++_currentGeneration;
    _activeCancelToken?.cancel('Superseded by new operation');
    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;
    _activeWork = ActiveWork.ask;
    _errorMessage = null;
    CapturedImageData? captured;

    try {
      _setState(OperationState.capturing, announcement: 'Taking a picture');
      await hapticService.confirmAction();
      if (gen != _currentGeneration) return;
      unawaited(earconService.play(Earcon.shutter));

      captured = await _captureWithGuidance(gen);
      if (gen != _currentGeneration) return;

      if (!preferencesService.cloudConsentGranted) {
        throw const AppException(
          code: ErrorCode.cloudConsentRequired,
          userMessage: 'Cloud consent was revoked.',
        );
      }

      unawaited(earconService.play(Earcon.processing));
      _setState(
        OperationState.processingCloud,
        announcement: 'Answering question',
      );

      final task = AgentTask(
        requestId: const Uuid().v4(),
        generation: gen,
        role: AgentRole.scene,
        providerMode: preferencesService.providerMode,
        captureTimestamp: captured.timestamp,
        maxCalls: AppConfig.maxModelCallsPerOperation,
        timeout: AppConfig.clientTimeout,
      );

      final result = await sceneAgent.execute(
        task: task,
        base64Jpeg: captured.base64Jpeg,
        question: trimmedQuestion,
        language: preferencesService.language,
        currentGeneration: _currentGeneration,
        cancelToken: cancelToken,
        nowProvider: _nowProvider,
      );
      if (gen != _currentGeneration) return;

      final answerText =
          (result.answer != null && result.answer!.trim().isNotEmpty)
          ? result.answer!.trim()
          : result.summary;

      final presentation = PresentationRecord(
        kind: TaskKind.askQuestion,
        timestamp: _nowProvider(),
        responseText: answerText,
        possibleConcern: result.possibleConcern,
        concernDescription: result.concernDescription,
        uncertainty: result.uncertainty,
        status: PresentationStatus.current,
      );

      _lastSceneResult = result;
      _lastResultText = answerText;
      _lastPresentation = presentation;
      notifyListeners();

      if (result.possibleConcern) {
        await hapticService.indicateConcern();
        unawaited(earconService.play(Earcon.concern));
      } else {
        unawaited(earconService.play(Earcon.success));
      }
      await earconService.stopLoop();
      await _speakPresentation(presentation, gen);
    } catch (e) {
      if (gen != _currentGeneration) return;
      await earconService.stopLoop();
      await _handleError(e);
    } finally {
      if (gen == _currentGeneration && _activeWork == ActiveWork.ask) {
        _activeWork = null;
      }
      if (_activeCancelToken == cancelToken) _activeCancelToken = null;
      await cameraService.deleteTemporaryCapture(captured?.file);
      notifyListeners();
    }
  }

  Future<void> startVoiceAsk() async {
    if (!_acceptsTask) return;
    if (!preferencesService.cloudConsentGranted) {
      await _handleError(
        const AppException(
          code: ErrorCode.cloudConsentRequired,
          userMessage: 'Cloud processing requires consent. Enable it in Settings, or use Read Text offline.',
        ),
      );
      return;
    }

    final gen = ++_currentGeneration;
    _activeWork = ActiveWork.ask;
    _setState(OperationState.listening);
    await speechFeedbackCoordinator.interruptWith(
      'Say your question after the vibration.',
    );
    if (gen != _currentGeneration) return;
    await speechFeedbackCoordinator.playReadinessCue();
    if (gen != _currentGeneration) return;

    try {
      await speechService.listen(
        localeId: preferencesService.language == 'sw' ? 'sw-KE' : 'en-US',
        onResult: (words, isFinal) {
          if (isFinal && words.trim().isNotEmpty && gen == _currentGeneration) {
            _setState(OperationState.idle);
            unawaited(executeAskQuestion(words));
          }
        },
        onOutcome: (outcome) => _onSpeechOutcome(outcome, gen, question: true),
      );
    } catch (e) {
      if (gen == _currentGeneration) await _handleError(e);
    }
  }

  Future<void> executeVoiceCommand() async {
    if (!_acceptsTask) return;
    final gen = ++_currentGeneration;
    _activeWork = ActiveWork.voiceCommand;
    _setState(OperationState.listening);
    await speechFeedbackCoordinator.interruptWith(
      'Say describe, read text, repeat, or a question after the vibration.',
    );
    if (gen != _currentGeneration) return;
    await speechFeedbackCoordinator.playReadinessCue();
    if (gen != _currentGeneration) return;

    try {
      await speechService.listen(
        localeId: preferencesService.language == 'sw' ? 'sw-KE' : 'en-US',
        onResult: (words, isFinal) async {
          if (!(isFinal &&
              words.trim().isNotEmpty &&
              gen == _currentGeneration)) {
            return;
          }
          final task = AgentTask(
            requestId: const Uuid().v4(),
            generation: gen,
            role: AgentRole.conversation,
            providerMode: preferencesService.providerMode,
            maxCalls: 1,
          );
          final intent = await conversationAgent.resolveIntent(
            task: task,
            input: words,
            language: preferencesService.language,
          );
          if (gen != _currentGeneration) return;
          _activeWork = null;
          _setState(OperationState.idle);
          switch (intent) {
            case 'stop':
              stop();
            case 'repeat':
              repeatLast();
            case 'describe_scene':
              executeDescribe();
            case 'read_text':
              executeReadText();
            case 'ask_scene':
              executeAskQuestion(words);
            default:
              if (_activeWork == ActiveWork.voiceCommand) _activeWork = null;
              _setState(
                OperationState.idle,
                announcement:
                    'Say describe, read text, repeat, stop, or ask a question.',
              );
          }
        },
        onOutcome: (outcome) => _onSpeechOutcome(outcome, gen),
      );
    } catch (e) {
      if (gen == _currentGeneration) await _handleError(e);
    }
  }

  void _onSpeechOutcome(
    SpeechOutcome outcome,
    int generation, {
    bool question = false,
  }) {
    if (generation != _currentGeneration ||
        outcome.type == SpeechOutcomeType.recognized) {
      return;
    }
    _activeWork = null;
    switch (outcome.type) {
      case SpeechOutcomeType.noSpeech:
      case SpeechOutcomeType.timeout:
        _setState(
          OperationState.idle,
          announcement: question
              ? 'No speech heard. Try again or type the question.'
              : 'No voice command heard. Use a button, or try again.',
        );
      case SpeechOutcomeType.cancelled:
        _setState(OperationState.idle);
      case SpeechOutcomeType.permissionDenied:
        unawaited(
          _handleError(
            const AppException(
              code: ErrorCode.microphonePermissionDenied,
              userMessage: 'Microphone permission was denied. Use a button or type your question instead.',
            ),
          ),
        );
      case SpeechOutcomeType.unavailable:
      case SpeechOutcomeType.error:
        unawaited(
          _handleError(
            const AppException(
              code: ErrorCode.speechRecognitionUnavailable,
              userMessage: 'Speech recognition is unavailable. Use a button or type your question instead.',
            ),
          ),
        );
      case SpeechOutcomeType.recognized:
        break;
    }
  }

  Future<void> runCurrentMode() {
    switch (_currentMode) {
      case AppMode.describe:
        return executeDescribe();
      case AppMode.readText:
        return executeReadText();
      case AppMode.ask:
        return startVoiceAsk();
      case AppMode.awareness:
        return executeDescribe();
    }
  }

  void cycleMode(int direction) {
    const order = [AppMode.describe, AppMode.readText, AppMode.ask];
    final index = order.indexOf(_currentMode);
    final raw = (index < 0 ? 0 : index) + direction;
    var wrapped = raw % order.length;
    if (wrapped < 0) wrapped += order.length;
    final next = order[wrapped];
    // setMode calls stop(); cycling should not announce Stop over the mode name.
    _currentMode = next;
    unawaited(preferencesService.setAppMode(next));
    notifyListeners();
    speechFeedbackCoordinator.speakStatus(next.displayName);
  }

  Future<CapturedImageData> _captureWithGuidance(int generation) =>
      cameraService.captureAndCompress(
        onGuidance: preferencesService.aimingGuidance
            ? (phrase) {
                if (generation == _currentGeneration) _onGuidance(phrase);
              }
            : null,
      );

  void _onGuidance(String phrase) {
    final now = _nowProvider();
    if (_lastGuidancePhrase == phrase &&
        _lastGuidanceCueAt != null &&
        now.difference(_lastGuidanceCueAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastGuidancePhrase = phrase;
    _lastGuidanceCueAt = now;
    speechFeedbackCoordinator.speakStatus(phrase);
  }

  Future<void> _speakPresentation(
    PresentationRecord presentation,
    int generation,
  ) async {
    await _speakText(presentation.toSpokenText(), generation);
  }

  Future<void> speakMoreDetail() async {
    final text = _lastPresentation?.toSpokenText() ?? _lastResultText;
    if (text == null || text.trim().isEmpty) {
      speechFeedbackCoordinator.speakStatus(
        'No previous description available.',
      );
      return;
    }
    if (!_acceptsTask && _state != OperationState.speaking) return;
    await _speakText(text, _currentGeneration, force: true);
  }

  Future<void> _speakText(
    String text,
    int generation, {
    bool force = false,
  }) async {
    if (generation != _currentGeneration) return;
    if (!force && !preferencesService.autoRead) {
      await speechFeedbackCoordinator.speakResult(text, autoRead: false);
      if (generation == _currentGeneration && _state != OperationState.error) {
        _setState(OperationState.idle);
      }
      return;
    }
    await speechFeedbackCoordinator.speakResult(
      text,
      autoRead: true,
      onBegin: () {
        if (generation != _currentGeneration) return;
        _state = OperationState.speaking;
        notifyListeners();
      },
    );
    if (generation != _currentGeneration) return;
    _setState(OperationState.idle);
  }

  Future<void> _handleError(Object e) async {
    final appEx = AppException.fromError(e);
    if (appEx.code == ErrorCode.operationCancelled) {
      _setState(OperationState.idle);
      return;
    }

    if (_lastPresentation != null) {
      _lastPresentation = _lastPresentation!.asPrevious();
    }

    _errorMessage = appEx.userMessage;
    _state = OperationState.error;
    notifyListeners();
    unawaited(earconService.play(Earcon.error));
    if (preferencesService.autoRead) {
      await speechFeedbackCoordinator.speakError(
        appEx.userMessage,
        autoRead: true,
      );
    }
  }

  @visibleForTesting
  void debugSetOperationState(OperationState value) {
    _state = value;
    notifyListeners();
  }

  @visibleForTesting
  void debugSetActiveWork(ActiveWork? work) {
    _activeWork = work;
    notifyListeners();
  }

  @override
  void dispose() {
    preferencesService.removeListener(_onPreferencesChanged);
    _currentGeneration++;
    _activeCancelToken?.cancel('Disposed');
    _activeCancelToken = null;
    speechService.dispose();
    ttsService.stop();
    unawaited(ocrService.dispose());
    unawaited(cameraService.dispose());
    unawaited(earconService.stopLoop());
    ttsService.dispose();
    super.dispose();
  }
}
