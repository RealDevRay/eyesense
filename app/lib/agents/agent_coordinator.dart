import 'dart:async';

import 'package:dio/dio.dart';
import 'package:eyesense/agents/agent_task.dart';
import 'package:eyesense/agents/conversation_agent.dart';
import 'package:eyesense/agents/reading_agent.dart';
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
import 'package:eyesense/services/providers/groq_direct_provider.dart';
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
    readingAgent = ReadingAgent(prefs: preferencesService, logService: logService);
    conversationAgent = ConversationAgent(logService: logService);
  }

  void refreshVisionProvider([VisionApiService? visionApi]) {
    final api = visionApi ?? _createVisionApi();
    sceneAgent = SceneAgent(visionApi: api, logService: logService);
  }

  VisionApiService _createVisionApi() {
    if (preferencesService.providerMode == ProviderMode.byok) {
      return GroqDirectVisionProvider(credentialService: credentialService);
    }
    return HostedVisionProvider(
      credentialService: credentialService,
      baseUrl: preferencesService.apiBaseUrl,
    );
  }

  void _setState(OperationState newState, {String? announcement}) {
    _state = newState;
    notifyListeners();
    if (announcement != null && announcement.isNotEmpty && newState != OperationState.speaking) {
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
    speechFeedbackCoordinator.speakStatus('Current mode: ${currentMode.displayName}');
  }

  /// Cancels network work and playback without a spoken announcement.
  /// Used when the app is backgrounded, including during a permission dialog
  /// that has already been separated from the operation.
  Future<void> suspend() async {
    _currentGeneration++;
    _activeCancelToken?.cancel('Suspended');
    _activeCancelToken = null;
    _activeWork = null;
    await speechService.cancel();
    await speechFeedbackCoordinator.stopAll();
    await earconService.stopLoop();
    await cameraService.dispose();
    _state = OperationState.idle;
    notifyListeners();
  }

  /// Cancels all active operations, stops speech, invalidates generations.
  void stop() {
    _currentGeneration++;
    _activeCancelToken?.cancel('Stopped by user');
    _activeCancelToken = null;
    _activeWork = null;
    speechService.cancel();
    unawaited(earconService.stopLoop());
    unawaited(speechFeedbackCoordinator.interruptWith('Stopped'));
    _errorMessage = null;
    _state = OperationState.idle;
    notifyListeners();
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
      speechFeedbackCoordinator.speakStatus('Cannot repeat while an operation is in progress. Use Stop first.');
      return;
    }

    if (_lastPresentation != null) {
      _lastPresentation = _lastPresentation!.asPrevious();
      notifyListeners();
      await _speakPresentation(_lastPresentation!, _currentGeneration);
    } else if (_lastResultText != null && _lastResultText!.isNotEmpty) {
      await _speakText('Previous result: $_lastResultText', _currentGeneration);
    } else {
      speechFeedbackCoordinator.speakStatus('No previous description available.');
    }
  }

  Future<void> executeDescribe() async {
    if (!preferencesService.cloudConsentGranted) {
      await _handleError(const AppException(
        code: ErrorCode.cloudConsentRequired,
        userMessage: 'Cloud processing requires consent. Enable it in Settings, or use Read Text offline.',
      ));
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
      await hapticService.confirmAction();
      unawaited(earconService.play(Earcon.shutter));
      _setState(OperationState.capturing, announcement: 'Taking a picture');

      captured = await cameraService.captureAndCompress();
      if (gen != _currentGeneration) return;

      if (!preferencesService.cloudConsentGranted) {
        throw const AppException(
          code: ErrorCode.cloudConsentRequired,
          userMessage: 'Cloud consent was revoked.',
        );
      }

      unawaited(earconService.play(Earcon.processing));
      _setState(OperationState.processingCloud, announcement: 'Describing scene');

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
      if (_activeWork == ActiveWork.describe) _activeWork = null;
      if (_activeCancelToken == cancelToken) _activeCancelToken = null;
      await cameraService.deleteTemporaryCapture(captured?.file);
      notifyListeners();
    }
  }

  /// On-device OCR. ML Kit's processImage cannot be aborted; Stop invalidates
  /// the generation, halts playback and discards the text when it arrives.
  /// The recognition itself keeps running until the platform call returns.
  Future<void> executeReadText() async {
    final gen = ++_currentGeneration;
    _activeCancelToken?.cancel('Superseded by new operation');
    _activeCancelToken = null;
    _activeWork = ActiveWork.readText;
    _errorMessage = null;
    CapturedOcrData? captured;

    try {
      await hapticService.confirmAction();
      unawaited(earconService.play(Earcon.shutter));
      _setState(OperationState.capturing, announcement: 'Taking a picture');

      captured = await cameraService.captureForOcr(
        onGuidance: preferencesService.aimingGuidance ? _onGuidance : null,
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
      if (_activeWork == ActiveWork.readText) _activeWork = null;
      await cameraService.deleteTemporaryCapture(captured?.file);
      notifyListeners();
    }
  }

  Future<void> executeAskQuestion(String question) async {
    if (!preferencesService.cloudConsentGranted) {
      await _handleError(const AppException(
        code: ErrorCode.cloudConsentRequired,
        userMessage: 'Cloud processing requires consent. Enable it in Settings, or use Read Text offline.',
      ));
      return;
    }

    final trimmedQuestion = question.trim();
    if (trimmedQuestion.isEmpty) {
      await speechFeedbackCoordinator.interruptWith('Say or type a question first.');
      return;
    }

    if (trimmedQuestion.length > AppConfig.maxQuestionCharacters) {
      await _handleError(const AppException(
        code: ErrorCode.validationFailed,
        userMessage: 'That question is longer than 300 characters. Ask a shorter question.',
      ));
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
      await hapticService.confirmAction();
      unawaited(earconService.play(Earcon.shutter));
      _setState(OperationState.capturing, announcement: 'Taking a picture');

      captured = await cameraService.captureAndCompress();
      if (gen != _currentGeneration) return;

      if (!preferencesService.cloudConsentGranted) {
        throw const AppException(
          code: ErrorCode.cloudConsentRequired,
          userMessage: 'Cloud consent was revoked.',
        );
      }

      unawaited(earconService.play(Earcon.processing));
      _setState(OperationState.processingCloud, announcement: 'Answering question');

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

      final answerText = (result.answer != null && result.answer!.trim().isNotEmpty)
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
      if (_activeWork == ActiveWork.ask) _activeWork = null;
      if (_activeCancelToken == cancelToken) _activeCancelToken = null;
      await cameraService.deleteTemporaryCapture(captured?.file);
      notifyListeners();
    }
  }

  Future<void> startVoiceAsk() async {
    if (!preferencesService.cloudConsentGranted) {
      await _handleError(const AppException(
        code: ErrorCode.cloudConsentRequired,
        userMessage: 'Cloud processing requires consent. Enable it in Settings, or use Read Text offline.',
      ));
      return;
    }

    final gen = ++_currentGeneration;
    _activeWork = ActiveWork.ask;
    await ttsService.stop();
    unawaited(earconService.play(Earcon.listening));
    _setState(OperationState.listening, announcement: 'Listening for a question');

    try {
      await speechService.listen(
        localeId: preferencesService.language == 'sw' ? 'sw-KE' : 'en-US',
        onResult: (words, isFinal) {
          if (isFinal && words.trim().isNotEmpty && gen == _currentGeneration) {
            executeAskQuestion(words);
          }
        },
        onOutcome: (outcome) {
          if (gen != _currentGeneration) return;
          if (outcome.type == SpeechOutcomeType.noSpeech) {
            if (_activeWork == ActiveWork.ask) _activeWork = null;
            _setState(OperationState.idle, announcement: 'No speech heard. You can try again or type the question.');
          } else if (outcome.type == SpeechOutcomeType.permissionDenied) {
            _handleError(const AppException(
              code: ErrorCode.microphonePermissionDenied,
              userMessage: 'Microphone permission was denied. You can type the question instead.',
            ));
          } else if (outcome.type == SpeechOutcomeType.unavailable) {
            _handleError(const AppException(
              code: ErrorCode.speechRecognitionUnavailable,
              userMessage: 'Speech recognition is unavailable. You can type the question instead.',
            ));
          }
        },
      );
    } catch (e) {
      if (gen == _currentGeneration) await _handleError(e);
    } finally {
      if (_activeWork == ActiveWork.ask && _state == OperationState.listening) {
        _activeWork = null;
      }
    }
  }

  Future<void> executeVoiceCommand() async {
    final gen = ++_currentGeneration;
    _activeWork = ActiveWork.voiceCommand;
    await speechFeedbackCoordinator.stopAll();
    await speechFeedbackCoordinator.playReadinessCue();
    unawaited(earconService.play(Earcon.listening));
    _setState(OperationState.listening, announcement: 'Listening for a voice command');

    try {
      await speechService.listen(
        localeId: preferencesService.language == 'sw' ? 'sw-KE' : 'en-US',
        onResult: (words, isFinal) async {
          if (!(isFinal && words.trim().isNotEmpty && gen == _currentGeneration)) return;
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
                announcement: 'Say describe, read text, repeat, stop, or ask a question.',
              );
          }
        },
        onOutcome: (outcome) {
          if (gen != _currentGeneration) return;
          if (outcome.type == SpeechOutcomeType.noSpeech) {
            if (_activeWork == ActiveWork.voiceCommand) _activeWork = null;
            _setState(OperationState.idle, announcement: 'No voice command heard. Use a button, or try again.');
          } else if (outcome.type == SpeechOutcomeType.permissionDenied) {
            _handleError(const AppException(
              code: ErrorCode.microphonePermissionDenied,
              userMessage: 'Microphone permission was denied. Use a button instead.',
            ));
          } else if (outcome.type == SpeechOutcomeType.unavailable) {
            _handleError(const AppException(
              code: ErrorCode.speechRecognitionUnavailable,
              userMessage: 'Speech recognition is unavailable. Use a button instead.',
            ));
          }
        },
      );
    } catch (e) {
      if (gen == _currentGeneration) await _handleError(e);
    } finally {
      if (_activeWork == ActiveWork.voiceCommand && _state == OperationState.listening) {
        _activeWork = null;
      }
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

  Future<void> _speakPresentation(PresentationRecord presentation, int generation) async {
    final full = presentation.toSpokenText();
    final spoken = _leadSentence(full);
    await _speakText(spoken, generation);
  }

  String _leadSentence(String text) {
    final trimmed = text.trim();
    if (trimmed.length < 180) return trimmed;
    final match = RegExp(r'^.{1,180}?[.!]').firstMatch(trimmed);
    if (match == null) return trimmed;
    return '${match.group(0)} More detail is on screen.';
  }

  Future<void> speakMoreDetail() async {
    final text = _lastPresentation?.toSpokenText() ?? _lastResultText;
    if (text == null || text.trim().isEmpty) {
      speechFeedbackCoordinator.speakStatus('No previous description available.');
      return;
    }
    await _speakText(text, _currentGeneration);
  }

  Future<void> _speakText(String text, int generation) async {
    if (!preferencesService.autoRead) {
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
      await speechFeedbackCoordinator.speakError(appEx.userMessage, autoRead: true);
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
    _currentGeneration++;
    _activeCancelToken?.cancel('Disposed');
    _activeCancelToken = null;
    speechService.cancel();
    ttsService.stop();
    unawaited(ocrService.dispose());
    unawaited(cameraService.dispose());
    unawaited(earconService.stopLoop());
    ttsService.dispose();
    super.dispose();
  }
}
