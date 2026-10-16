import 'dart:async';
import 'package:dio/dio.dart';
import 'package:eyesense/agents/agent_task.dart';
import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/agents/conversation_agent.dart';
import 'package:eyesense/agents/reading_agent.dart';
import 'package:eyesense/agents/scene_agent.dart';
import 'package:eyesense/core/accessibility/semantic_announcer.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:eyesense/models/app_operation.dart';
import 'package:eyesense/models/presentation_record.dart';
import 'package:eyesense/models/scene_result.dart';
import 'package:eyesense/services/camera_service.dart';
import 'package:eyesense/services/credential_service.dart';
import 'package:eyesense/services/diagnostic_log_service.dart';
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

  OperationState get state => _state;
  AppMode get currentMode => _currentMode;
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
  }) : _nowProvider = nowProvider ?? DateTime.now {
    speechFeedbackCoordinator = SpeechFeedbackCoordinator(
      ttsService: ttsService,
      hapticService: hapticService,
    );
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
    final message = announcement ?? newState.localizedAnnouncement;
    SemanticAnnouncer.announce(message);
  }

  void setMode(AppMode mode) {
    if (_currentMode != mode) {
      stop();
      _currentMode = mode;
      notifyListeners();
    }
  }

  /// Cancels all active operations, stops speech, invalidates generations
  void stop() {
    _currentGeneration++;
    _activeCancelToken?.cancel('Stopped by user');
    _activeCancelToken = null;
    ttsService.stop();
    speechService.cancel();
    _setState(OperationState.idle, announcement: 'Stopped');
  }

  /// Repeats the last completed response
  Future<void> repeatLast() async {
    // If actively capturing or processing, do not silently reset
    if (_state == OperationState.capturing ||
        _state == OperationState.processingCloud ||
        _state == OperationState.processingLocal ||
        _state == OperationState.listening) {
      SemanticAnnouncer.announce('Cannot repeat while operation is in progress. Tap Stop first.');
      return;
    }

    if (_lastPresentation != null) {
      _lastPresentation = _lastPresentation!.asPrevious();
      _setState(OperationState.speaking);
      await ttsService.speak(_lastPresentation!.toSpokenText());
      _setState(OperationState.idle);
    } else if (_lastResultText != null && _lastResultText!.isNotEmpty) {
      _setState(OperationState.speaking);
      await ttsService.speak('Previous result: $_lastResultText');
      _setState(OperationState.idle);
    } else {
      SemanticAnnouncer.announce('No previous description available.');
    }
  }

  /// 1. Describe Workflow
  Future<void> executeDescribe() async {
    // Phase 1 Consent Check: Must have explicit cloud consent
    if (!preferencesService.cloudConsentGranted) {
      _handleError(const AppException(
        code: ErrorCode.cloudConsentRequired,
        userMessage: 'Cloud processing requires consent. Please enable it in Settings or use Read Text offline.',
      ));
      return;
    }

    final gen = ++_currentGeneration;
    _activeCancelToken?.cancel('Superseded by new operation');
    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;

    final requestId = const Uuid().v4();
    _errorMessage = null;
    CapturedImageData? captured;

    try {
      await hapticService.confirmAction();
      _setState(OperationState.capturing, announcement: 'Taking a picture');

      captured = await cameraService.captureAndCompress();
      if (gen != _currentGeneration) return;

      // Recheck consent immediately before network dispatch
      if (!preferencesService.cloudConsentGranted) {
        throw const AppException(
          code: ErrorCode.cloudConsentRequired,
          userMessage: 'Cloud consent was revoked.',
        );
      }

      _setState(OperationState.processingCloud, announcement: 'Describing scene');

      final task = AgentTask(
        requestId: requestId,
        generation: gen,
        role: AgentRole.scene,
        providerMode: preferencesService.providerMode,
        captureTimestamp: captured.timestamp,
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

      // Presentation record is the single source of truth for display & speech
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

      if (result.possibleConcern) {
        await hapticService.indicateConcern();
      }

      _setState(OperationState.speaking);
      if (preferencesService.autoRead) {
        await ttsService.speak(presentation.toSpokenText());
      }
      if (gen != _currentGeneration) return;
      _setState(OperationState.idle);
    } catch (e) {
      if (gen != _currentGeneration) return;
      _handleError(e);
    } finally {
      if (_activeCancelToken == cancelToken) {
        _activeCancelToken = null;
      }
      await cameraService.deleteTemporaryCapture(captured?.file);
    }
  }

  /// 2. Read Text Workflow (Local on-device OCR - works 100% offline without cloud consent)
  Future<void> executeReadText() async {
    final gen = ++_currentGeneration;
    _activeCancelToken?.cancel('Superseded by new operation');
    _activeCancelToken = null;
    _errorMessage = null;
    CapturedOcrData? captured;

    try {
      await hapticService.confirmAction();
      _setState(OperationState.capturing, announcement: 'Taking a picture');

      // Use dedicated lightweight capture without image decoding/resizing overhead
      captured = await cameraService.captureForOcr();
      if (gen != _currentGeneration) return;

      _setState(OperationState.processingLocal, announcement: 'Reading text');

      final text = await ocrService.recognizeText(captured.file);
      if (gen != _currentGeneration) return;

      // Clear scene-only metadata when OCR completes
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
      _setState(OperationState.speaking);

      if (preferencesService.autoRead) {
        await ttsService.speak(presentation.toSpokenText());
      }
      if (gen != _currentGeneration) return;
      _setState(OperationState.idle);
    } catch (e) {
      if (gen != _currentGeneration) return;
      _handleError(e);
    } finally {
      await cameraService.deleteTemporaryCapture(captured?.file);
    }
  }

  /// 3. Ask Question Workflow
  Future<void> executeAskQuestion(String question) async {
    // Phase 1 Consent Check: Must have explicit cloud consent
    if (!preferencesService.cloudConsentGranted) {
      _handleError(const AppException(
        code: ErrorCode.cloudConsentRequired,
        userMessage: 'Cloud processing requires consent. Please enable it in Settings or use Read Text offline.',
      ));
      return;
    }

    final trimmedQuestion = question.trim();
    if (trimmedQuestion.isEmpty) {
      _handleError(const AppException(
        code: ErrorCode.validationFailed,
        userMessage: 'Please ask a specific question about the scene.',
      ));
      return;
    }

    if (trimmedQuestion.length > AppConfig.maxQuestionCharacters) {
      _handleError(const AppException(
        code: ErrorCode.validationFailed,
        userMessage: 'Question exceeds 300 characters limit. Please ask a more concise question.',
      ));
      return;
    }

    final gen = ++_currentGeneration;
    _activeCancelToken?.cancel('Superseded by new operation');
    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;

    final requestId = const Uuid().v4();
    _errorMessage = null;
    CapturedImageData? captured;

    try {
      await hapticService.confirmAction();
      _setState(OperationState.capturing, announcement: 'Taking a picture');

      captured = await cameraService.captureAndCompress();
      if (gen != _currentGeneration) return;

      // Recheck consent immediately before network dispatch
      if (!preferencesService.cloudConsentGranted) {
        throw const AppException(
          code: ErrorCode.cloudConsentRequired,
          userMessage: 'Cloud consent was revoked.',
        );
      }

      _setState(OperationState.processingCloud, announcement: 'Answering question');

      final task = AgentTask(
        requestId: requestId,
        generation: gen,
        role: AgentRole.scene,
        providerMode: preferencesService.providerMode,
        captureTimestamp: captured.timestamp,
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

      if (result.possibleConcern) {
        await hapticService.indicateConcern();
      }

      _setState(OperationState.speaking);
      if (preferencesService.autoRead) {
        await ttsService.speak(presentation.toSpokenText());
      }
      if (gen != _currentGeneration) return;
      _setState(OperationState.idle);
    } catch (e) {
      if (gen != _currentGeneration) return;
      _handleError(e);
    } finally {
      if (_activeCancelToken == cancelToken) {
        _activeCancelToken = null;
      }
      await cameraService.deleteTemporaryCapture(captured?.file);
    }
  }

  /// Voice Ask helper
  Future<void> startVoiceAsk() async {
    if (!preferencesService.cloudConsentGranted) {
      _handleError(const AppException(
        code: ErrorCode.cloudConsentRequired,
        userMessage: 'Cloud processing requires consent. Please enable it in Settings or use Read Text offline.',
      ));
      return;
    }

    final gen = ++_currentGeneration;
    await ttsService.stop();
    _setState(OperationState.listening, announcement: 'Listening for question');

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
            _setState(OperationState.idle, announcement: 'No speech heard. You can try again or type your question.');
          } else if (outcome.type == SpeechOutcomeType.permissionDenied) {
            _handleError(const AppException(
              code: ErrorCode.microphonePermissionDenied,
              userMessage: 'Microphone permission was denied. You can type your question instead.',
            ));
          } else if (outcome.type == SpeechOutcomeType.unavailable) {
            _handleError(const AppException(
              code: ErrorCode.speechRecognitionUnavailable,
              userMessage: 'Speech recognition is unavailable. You can type your question instead.',
            ));
          }
        },
      );
    } catch (e) {
      if (gen == _currentGeneration) {
        _handleError(e);
      }
    }
  }

  /// Top-level voice command: routes simple commands using token-aware matching,
  /// avoiding false substring matches (e.g. "stop sign", "bread", "textile").
  Future<void> executeVoiceCommand() async {
    final gen = ++_currentGeneration;
    await speechFeedbackCoordinator.stopAll();
    await speechFeedbackCoordinator.playReadinessCue();
    _setState(OperationState.listening, announcement: 'Listening for voice command');

    try {
      await speechService.listen(
        localeId: preferencesService.language == 'sw' ? 'sw-KE' : 'en-US',
        onResult: (words, isFinal) async {
          if (isFinal && words.trim().isNotEmpty && gen == _currentGeneration) {
            final clean = words.toLowerCase().trim();

            // Token-aware matching for standalone command words
            final isStop = RegExp(r'^(stop|acha|nyamaza)$').hasMatch(clean);
            final isRepeat = RegExp(r'^(repeat|rudia)$').hasMatch(clean);
            final isDescribe = RegExp(r'^(describe|describe scene|tazama|eleza|eleza mandhari)$').hasMatch(clean);
            final isRead = RegExp(r'^(read|read text|soma|soma maandishi)$').hasMatch(clean);

            if (isStop) {
              stop();
            } else if (isRepeat) {
              repeatLast();
            } else if (isDescribe) {
              executeDescribe();
            } else if (isRead) {
              executeReadText();
            } else {
              // Any detailed question routes to visual QA (requires consent)
              executeAskQuestion(words);
            }
          }
        },
        onOutcome: (outcome) {
          if (gen != _currentGeneration) return;
          if (outcome.type == SpeechOutcomeType.noSpeech) {
            _setState(OperationState.idle, announcement: 'No voice command heard. Try tapping an action button.');
          } else if (outcome.type == SpeechOutcomeType.permissionDenied) {
            _handleError(const AppException(
              code: ErrorCode.microphonePermissionDenied,
              userMessage: 'Microphone permission was denied. Tap an action button directly.',
            ));
          } else if (outcome.type == SpeechOutcomeType.unavailable) {
            _handleError(const AppException(
              code: ErrorCode.speechRecognitionUnavailable,
              userMessage: 'Speech recognition is unavailable. Tap an action button directly.',
            ));
          }
        },
      );
    } catch (e) {
      if (gen == _currentGeneration) {
        _handleError(e);
      }
    }
  }

  void _handleError(Object e) {
    final appEx = AppException.fromError(e);
    if (appEx.code == ErrorCode.operationCancelled) {
      // Normal cancellation: do not speak an error to user
      _setState(OperationState.idle);
      return;
    }

    if (_lastPresentation != null) {
      _lastPresentation = _lastPresentation!.asPrevious();
    }

    _errorMessage = appEx.userMessage;
    _setState(OperationState.error, announcement: appEx.userMessage);
    ttsService.speak(appEx.userMessage);
  }
}
