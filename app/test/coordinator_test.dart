import 'dart:io';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/models/app_operation.dart';
import 'package:eyesense/models/presentation_record.dart';
import 'package:eyesense/models/scene_result.dart';
import 'package:eyesense/services/camera_service.dart';
import 'package:eyesense/services/credential_service.dart';
import 'package:eyesense/services/diagnostic_log_service.dart';
import 'package:eyesense/services/haptic_service.dart';
import 'package:eyesense/services/ocr_service.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:eyesense/services/speech_service.dart';
import 'package:eyesense/services/tts_service.dart';
import 'package:eyesense/services/vision_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeCameraService extends CameraService {
  int captureCount = 0;

  @override
  bool get isInitialized => true;

  @override
  Future<void> initialize({ResolutionPreset preset = ResolutionPreset.medium}) async {}

  @override
  Future<CapturedImageData> captureAndCompress() async {
    captureCount++;
    return CapturedImageData(
      file: File('test_dummy.jpg'),
      base64Jpeg: '/9j/fakeBase64Jpeg==',
      byteSize: 1024,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<CapturedOcrData> captureForOcr({void Function(String phrase)? onGuidance}) async {
    captureCount++;
    return CapturedOcrData(
      file: File('test_dummy.jpg'),
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<void> deleteTemporaryCapture(File? file) async {}

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> isPermissionPermanentlyDenied() async => false;

  @override
  Future<void> dispose() async {}
}

class FakeVisionApiService implements VisionApiService {
  int describeCalls = 0;
  int askCalls = 0;
  SceneResult? cannedResult;

  @override
  Future<SceneResult> describeScene({
    required String requestId,
    required String base64Jpeg,
    required String language,
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    describeCalls++;
    return cannedResult ??
        const SceneResult(
          summary: 'A clean testing room with a desk in the centre.',
          possibleConcern: false,
          direction: SceneDirection.centre,
          objects: ['desk', 'room'],
          imageQuality: ImageQuality.usable,
        );
  }

  @override
  Future<SceneResult> askQuestion({
    required String requestId,
    required String base64Jpeg,
    required String question,
    required String language,
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    askCalls++;
    return cannedResult ??
        const SceneResult(
          summary: 'A clean testing room.',
          answer: 'The cup is on the left side of the desk.',
          possibleConcern: false,
          direction: SceneDirection.left,
          objects: ['cup', 'desk'],
          imageQuality: ImageQuality.usable,
        );
  }
}

class FakeTtsService extends TtsService {
  final List<String> spokenTexts = [];

  FakeTtsService(super.prefs);

  @override
  Future<void> speak(String text) async {
    spokenTexts.add(text);
  }

  @override
  Future<void> stop() async {}
}

class FakeSpeechService extends SpeechService {
  @override
  Future<void> listen({
    required Function(String words, bool isFinal) onResult,
    Function(SpeechOutcome outcome)? onOutcome,
    String? localeId,
    Duration listenFor = const Duration(seconds: 10),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

class FakeOcrService extends OcrService {
  String textToReturn = 'Recognised printed document headline';

  @override
  Future<String> recognizeText(File imageFile) async {
    return textToReturn;
  }
}

class FakeHapticService extends HapticService {
  FakeHapticService(super.prefs);

  @override
  Future<void> confirmAction() async {}

  @override
  Future<void> indicateConcern() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCameraService camera;
  late FakeVisionApiService vision;
  late FakeTtsService tts;
  late FakeSpeechService speech;
  late FakeOcrService ocr;
  late FakeHapticService haptic;
  late PreferencesService prefs;
  late CredentialService creds;
  late DiagnosticLogService log;
  late AgentCoordinator coordinator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'cloud_consent_granted': false,
      'app_language': 'en',
      'auto_read': true,
    });

    camera = FakeCameraService();
    vision = FakeVisionApiService();
    speech = FakeSpeechService();
    ocr = FakeOcrService();
    prefs = await PreferencesService.create();
    creds = CredentialService();
    log = DiagnosticLogService(prefs);
    tts = FakeTtsService(prefs);
    haptic = FakeHapticService(prefs);

    coordinator = AgentCoordinator(
      cameraService: camera,
      ttsService: tts,
      speechService: speech,
      ocrService: ocr,
      hapticService: haptic,
      preferencesService: prefs,
      credentialService: creds,
      logService: log,
      visionApi: vision,
    );
  });

  group('AgentCoordinator Consent Enforcement', () {
    test('executeDescribe with consent=false makes 0 cloud requests and sets cloudConsentRequired error', () async {
      expect(prefs.cloudConsentGranted, false);

      await coordinator.executeDescribe();

      expect(vision.describeCalls, 0);
      expect(coordinator.state, OperationState.error);
      expect(coordinator.errorMessage, contains('Cloud processing requires consent'));
      expect(tts.spokenTexts.last, contains('Cloud processing requires consent'));
    });

    test('an error is not spoken when automatic reading is off', () async {
      await prefs.setAutoRead(false);
      await coordinator.executeDescribe();
      expect(coordinator.state, OperationState.error);
      expect(coordinator.errorMessage, contains('Cloud processing requires consent'));
      expect(tts.spokenTexts, isEmpty);
    });

    test('executeAskQuestion with consent=false makes 0 cloud requests and sets error', () async {
      expect(prefs.cloudConsentGranted, false);

      await coordinator.executeAskQuestion('Where is the door?');

      expect(vision.askCalls, 0);
      expect(coordinator.state, OperationState.error);
      expect(coordinator.errorMessage, contains('Cloud processing requires consent'));
    });

    test('executeReadText with consent=false succeeds offline without cloud requests', () async {
      expect(prefs.cloudConsentGranted, false);

      await coordinator.executeReadText();

      expect(vision.describeCalls, 0);
      expect(vision.askCalls, 0);
      expect(coordinator.state, OperationState.idle);
      expect(coordinator.lastResultText, 'Recognised printed document headline');
      expect(coordinator.lastPresentation?.kind, TaskKind.readText);
      expect(coordinator.lastSceneResult, isNull, reason: 'Scene-only metadata must be cleared after OCR');
      expect(tts.spokenTexts.last, 'Recognised printed document headline');
    });

    test('executeDescribe succeeds when consent is granted', () async {
      await prefs.setCloudConsentGranted(true);

      await coordinator.executeDescribe();

      expect(vision.describeCalls, 1);
      expect(coordinator.state, OperationState.idle);
      expect(coordinator.lastResultText, contains('clean testing room'));
      expect(coordinator.lastPresentation?.kind, TaskKind.describe);
      expect(coordinator.lastPresentation?.status, PresentationStatus.current);
    });
  });

  group('AgentCoordinator Presentation and Repeat', () {
    test('repeatLast formats output with Previous result prefix', () async {
      await prefs.setCloudConsentGranted(true);
      await coordinator.executeDescribe();

      expect(coordinator.lastPresentation?.status, PresentationStatus.current);

      await coordinator.repeatLast();

      expect(coordinator.lastPresentation?.status, PresentationStatus.previous);
      expect(tts.spokenTexts.last, startsWith('Previous result:'));
    });

    test('stop cancels active operation and returns to idle without speaking error', () {
      coordinator.stop();

      expect(coordinator.state, OperationState.idle);
      expect(coordinator.errorMessage, isNull);
    });

    test('refreshVisionProvider swaps visionApi instance live', () async {
      final oldApi = coordinator.sceneAgent.visionApi;
      final newFakeApi = FakeVisionApiService();

      coordinator.refreshVisionProvider(newFakeApi);

      expect(coordinator.sceneAgent.visionApi, isNot(same(oldApi)));
      expect(coordinator.sceneAgent.visionApi, same(newFakeApi));
    });

    test('PreferencesService tracks onboardingStep progress independently of completion', () async {
      expect(prefs.onboardingStep, 0);
      expect(prefs.hasCompletedOnboarding, false);

      await prefs.setOnboardingStep(3);
      expect(prefs.onboardingStep, 3);
      expect(prefs.hasCompletedOnboarding, false);

      await prefs.setCompletedOnboarding(true);
      expect(prefs.hasCompletedOnboarding, true);
      expect(prefs.onboardingStep, 3);

      await prefs.setOnboardingStep(0);
      expect(prefs.onboardingStep, 0);
      expect(prefs.hasCompletedOnboarding, true);
    });
  });
}
