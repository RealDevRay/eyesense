import 'dart:async';
import 'package:eyesense/agents/agent_task.dart';
import 'package:eyesense/agents/conversation_agent.dart';
import 'package:eyesense/agents/reading_agent.dart';
import 'package:eyesense/agents/scene_agent.dart';
import 'package:eyesense/core/accessibility/semantic_announcer.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:eyesense/models/app_operation.dart';
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
  late final SpeechFeedbackCoordinator speechFeedbackCoordinator;

  late final SceneAgent sceneAgent;
  late final ReadingAgent readingAgent;
  late final ConversationAgent conversationAgent;

  OperationState _state = OperationState.idle;
  AppMode _currentMode = AppMode.describe;
  int _currentGeneration = 0;
  String? _lastResultText;
  SceneResult? _lastSceneResult;
  String? _errorMessage;

  OperationState get state => _state;
  AppMode get currentMode => _currentMode;
  String? get lastResultText => _lastResultText;
  SceneResult? get lastSceneResult => _lastSceneResult;
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
  }) {
    speechFeedbackCoordinator = SpeechFeedbackCoordinator(
      ttsService: ttsService,
      hapticService: hapticService,
    );
    final visionApi = _createVisionApi();
    sceneAgent = SceneAgent(visionApi: visionApi, logService: logService);
    readingAgent = ReadingAgent(prefs: preferencesService, logService: logService);
    conversationAgent = ConversationAgent(logService: logService);
  }

  VisionApiService _createVisionApi() {
    if (preferencesService.providerMode == ProviderMode.byok) {
      return GroqDirectVisionProvider(credentialService: credentialService);
    }
    return HostedVisionProvider(credentialService: credentialService);
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
    ttsService.stop();
    speechService.cancel();
    _setState(OperationState.idle, announcement: 'Stopped');
  }

  /// Repeats the last completed response
  Future<void> repeatLast() async {
    if (_lastResultText != null && _lastResultText!.isNotEmpty) {
      _setState(OperationState.speaking);
      await ttsService.speak('Previous result: $_lastResultText');
      _setState(OperationState.idle);
    } else {
      SemanticAnnouncer.announce('No previous description available.');
    }
  }

  /// 1. Describe Workflow
  Future<void> executeDescribe() async {
    final gen = ++_currentGeneration;
    final requestId = const Uuid().v4();
    _errorMessage = null;

    try {
      await hapticService.confirmAction();
      _setState(OperationState.capturing, announcement: 'Taking a picture');

      final captured = await cameraService.captureAndCompress();
      if (gen != _currentGeneration) return;

      _setState(OperationState.processingCloud, announcement: 'Describing scene');

      final task = AgentTask(
        requestId: requestId,
        generation: gen,
        role: AgentRole.scene,
        providerMode: preferencesService.providerMode,
      );

      final result = await sceneAgent.execute(
        task: task,
        base64Jpeg: captured.base64Jpeg,
        language: preferencesService.language,
        currentGeneration: _currentGeneration,
      );
      if (gen != _currentGeneration) return;

      _lastSceneResult = result;
      _lastResultText = result.summary;

      if (result.possibleConcern) {
        await hapticService.indicateConcern();
      }

      _setState(OperationState.speaking);
      if (preferencesService.autoRead) {
        await ttsService.speak(result.summary);
      }
      if (gen != _currentGeneration) return;
      _setState(OperationState.idle);
    } catch (e) {
      if (gen != _currentGeneration) return;
      _handleError(e);
    }
  }

  /// 2. Read Text Workflow (Local on-device OCR)
  Future<void> executeReadText() async {
    final gen = ++_currentGeneration;
    _errorMessage = null;

    try {
      await hapticService.confirmAction();
      _setState(OperationState.capturing, announcement: 'Taking a picture');

      final captured = await cameraService.captureAndCompress();
      if (gen != _currentGeneration) return;

      _setState(OperationState.processingLocal, announcement: 'Reading text');

      final text = await ocrService.recognizeText(captured.file);
      if (gen != _currentGeneration) return;

      _lastResultText = text;
      _setState(OperationState.speaking);

      if (preferencesService.autoRead) {
        await ttsService.speak(text);
      }
      if (gen != _currentGeneration) return;
      _setState(OperationState.idle);
    } catch (e) {
      if (gen != _currentGeneration) return;
      _handleError(e);
    }
  }

  /// 3. Ask Question Workflow
  Future<void> executeAskQuestion(String question) async {
    final gen = ++_currentGeneration;
    final requestId = const Uuid().v4();
    _errorMessage = null;

    try {
      await hapticService.confirmAction();
      _setState(OperationState.capturing, announcement: 'Taking a picture');

      final captured = await cameraService.captureAndCompress();
      if (gen != _currentGeneration) return;

      _setState(OperationState.processingCloud, announcement: 'Answering question');

      final task = AgentTask(
        requestId: requestId,
        generation: gen,
        role: AgentRole.scene,
        providerMode: preferencesService.providerMode,
      );

      final result = await sceneAgent.execute(
        task: task,
        base64Jpeg: captured.base64Jpeg,
        question: question,
        language: preferencesService.language,
        currentGeneration: _currentGeneration,
      );
      if (gen != _currentGeneration) return;

      final answerText = result.answer ?? result.summary;
      _lastSceneResult = result;
      _lastResultText = answerText;

      if (result.possibleConcern) {
        await hapticService.indicateConcern();
      }

      _setState(OperationState.speaking);
      if (preferencesService.autoRead) {
        await ttsService.speak(answerText);
      }
      if (gen != _currentGeneration) return;
      _setState(OperationState.idle);
    } catch (e) {
      if (gen != _currentGeneration) return;
      _handleError(e);
    }
  }

  /// Voice Ask helper
  Future<void> startVoiceAsk() async {
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
      );
    } catch (e) {
      _handleError(e);
    }
  }

  /// Top-level voice command: routes simple commands locally ("describe", "read", "repeat", "stop"),
  /// or visual questions through the Scene Agent.
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
            if (clean.contains('stop') || clean.contains('acha')) {
              stop();
            } else if (clean.contains('repeat') || clean.contains('rudia')) {
              repeatLast();
            } else if (clean.contains('describe') || clean.contains('tazama') || clean.contains('eleza')) {
              executeDescribe();
            } else if (clean.contains('read') || clean.contains('soma') || clean.contains('text')) {
              executeReadText();
            } else {
              executeAskQuestion(words);
            }
          }
        },
      );
    } catch (e) {
      _handleError(e);
    }
  }

  void _handleError(Object e) {
    final appEx = AppException.fromError(e);
    _errorMessage = appEx.userMessage;
    _setState(OperationState.error, announcement: appEx.userMessage);
    ttsService.speak(appEx.userMessage);
  }
}
