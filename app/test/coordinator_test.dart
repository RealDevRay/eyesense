import 'dart:async';
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
import 'package:eyesense/services/earcon_service.dart';
import 'package:eyesense/services/haptic_service.dart';
import 'package:eyesense/services/ocr_service.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:eyesense/services/speech_service.dart';
import 'package:eyesense/services/tts_service.dart';
import 'package:eyesense/services/vision_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeCameraService extends CameraService {
  int captureCount = 0;

  @override
  bool get isInitialized => true;

  @override
  Future<void> initialize({
    ResolutionPreset preset = ResolutionPreset.medium,
  }) async {}

  @override
  Future<CapturedImageData> captureAndCompress({
    void Function(String phrase)? onGuidance,
  }) async {
    captureCount++;
    return CapturedImageData(
      file: File('test_dummy.jpg'),
      base64Jpeg: '/9j/fakeBase64Jpeg==',
      byteSize: 1024,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<CapturedOcrData> captureForOcr({
    void Function(String phrase)? onGuidance,
  }) async {
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

class _SilentFlutterTts extends FlutterTts {
  @override
  Future<dynamic> stop() async => 1;
}

class FakeTtsService extends TtsService {
  final List<String> spokenTexts = [];

  FakeTtsService(super.prefs) : super(tts: _SilentFlutterTts());

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

  @override
  Future<void> dispose() async {}
}

class FakeHapticService extends HapticService {
  FakeHapticService(super.prefs);

  @override
  Future<void> confirmAction() async {}

  @override
  Future<void> indicateConcern() async {}
}

class _Gate {
  final entered = Completer<void>();
  final _released = Completer<void>();

  _Gate() {
    addTearDown(release);
  }

  Future<void> wait() {
    if (!entered.isCompleted) entered.complete();
    return _released.future;
  }

  void release() {
    if (!_released.isCompleted) _released.complete();
  }
}

class _ControlledCamera extends FakeCameraService {
  _Gate? imageCaptureGate;
  int cancelCalls = 0;
  final deletedFiles = <File>[];

  @override
  Future<CapturedImageData> captureAndCompress({
    void Function(String phrase)? onGuidance,
  }) async {
    final capture = await super.captureAndCompress(onGuidance: onGuidance);
    await imageCaptureGate?.wait();
    return capture;
  }

  @override
  Future<void> cancelPendingCapture() async {
    cancelCalls++;
    // Leave the capture pending to model a native still completing after cancel.
  }

  @override
  Future<void> deleteTemporaryCapture(File? file) async {
    if (file != null) deletedFiles.add(file);
  }
}

class _ControlledVision extends FakeVisionApiService {
  _Gate? responseGate;
  Object? failure;
  final cancelTokens = <CancelToken>[];
  final questions = <String>[];

  Future<SceneResult> _respond(
    Future<SceneResult> response,
    CancelToken? cancelToken,
  ) async {
    if (cancelToken != null) cancelTokens.add(cancelToken);
    final result = await response;
    // Deliberately ignore cancellation so coordinator generation checks are tested.
    await responseGate?.wait();
    if (failure != null) throw failure!;
    return result;
  }

  @override
  Future<SceneResult> describeScene({
    required String requestId,
    required String base64Jpeg,
    required String language,
    CancelToken? cancelToken,
    Duration? timeout,
  }) => _respond(
    super.describeScene(
      requestId: requestId,
      base64Jpeg: base64Jpeg,
      language: language,
      cancelToken: cancelToken,
      timeout: timeout,
    ),
    cancelToken,
  );

  @override
  Future<SceneResult> askQuestion({
    required String requestId,
    required String base64Jpeg,
    required String question,
    required String language,
    CancelToken? cancelToken,
    Duration? timeout,
  }) {
    questions.add(question);
    return _respond(
      super.askQuestion(
        requestId: requestId,
        base64Jpeg: base64Jpeg,
        question: question,
        language: language,
        cancelToken: cancelToken,
        timeout: timeout,
      ),
      cancelToken,
    );
  }
}

class _SpeechCallbacks {
  final Function(String, bool) onResult;
  final Function(SpeechOutcome)? onOutcome;

  _SpeechCallbacks(this.onResult, this.onOutcome);

  Future<void> result(String words, {bool isFinal = true}) async {
    final delivery = onResult(words, isFinal);
    // Match SpeechService: final result first, then the recognized outcome,
    // without waiting for the coordinator's async intent resolution.
    if (isFinal) {
      outcome(
        words.trim().isEmpty
            ? SpeechOutcomeType.noSpeech
            : SpeechOutcomeType.recognized,
      );
    }
    if (delivery is Future) await delivery;
  }

  void outcome(SpeechOutcomeType type) {
    onOutcome?.call(SpeechOutcome(type: type));
  }
}

class _CallbackSpeech extends FakeSpeechService {
  final sessions = <_SpeechCallbacks>[];
  int cancelCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> listen({
    required Function(String words, bool isFinal) onResult,
    Function(SpeechOutcome outcome)? onOutcome,
    String? localeId,
    Duration listenFor = const Duration(seconds: 10),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    sessions.add(_SpeechCallbacks(onResult, onOutcome));
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    // Keep callbacks available for deliberate late native deliveries.
    if (sessions.isNotEmpty) {
      sessions.last.outcome(SpeechOutcomeType.cancelled);
    }
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

class _RecordingTts extends FakeTtsService {
  int stopCalls = 0;

  _RecordingTts(super.prefs);

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

class _ControlledOcr extends FakeOcrService {
  _Gate? recognitionGate;
  int recognizeCalls = 0;

  @override
  Future<String> recognizeText(File imageFile) async {
    recognizeCalls++;
    await recognitionGate?.wait();
    return super.recognizeText(imageFile);
  }
}

class _ControlledHaptic extends FakeHapticService {
  _Gate? confirmGate;
  int confirmCalls = 0;

  _ControlledHaptic(super.prefs);

  @override
  Future<void> confirmAction() async {
    confirmCalls++;
    await confirmGate?.wait();
  }
}

class _ControlledEarcons extends EarconService {
  _Gate? stopLoopGate;

  _ControlledEarcons(super.prefs, super.tts);

  @override
  Future<void> play(Earcon earcon) async {}

  @override
  Future<void> stopLoop() async {
    await stopLoopGate?.wait();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ControlledCamera camera;
  late _ControlledVision vision;
  late _RecordingTts tts;
  late _CallbackSpeech speech;
  late _ControlledOcr ocr;
  late _ControlledHaptic haptic;
  late _ControlledEarcons earcons;
  late PreferencesService prefs;
  late CredentialService creds;
  late DiagnosticLogService log;
  late AgentCoordinator coordinator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'cloud_consent_granted': false,
      'app_language': 'en',
      'auto_read': true,
      'earcons_enabled': false,
    });

    camera = _ControlledCamera();
    vision = _ControlledVision();
    speech = _CallbackSpeech();
    ocr = _ControlledOcr();
    prefs = await PreferencesService.create();
    creds = CredentialService();
    log = DiagnosticLogService(prefs);
    tts = _RecordingTts(prefs);
    haptic = _ControlledHaptic(prefs);
    earcons = _ControlledEarcons(prefs, tts);

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
      earcons: earcons,
    );
  });

  Future<void> runTask(TaskKind kind) => switch (kind) {
    TaskKind.describe => coordinator.executeDescribe(),
    TaskKind.readText => coordinator.executeReadText(),
    TaskKind.askQuestion => coordinator.executeAskQuestion('Where is the cup?'),
  };

  const detailedScene = SceneResult(
    summary:
        'A desk stands beside a window. A cup rests on the desk. '
        'There is a chair on the right. A notebook is open beside the cup.',
    answer:
        'The cup is beside the notebook. It has a blue handle. '
        'Its rim is partly hidden behind the open page.',
    possibleConcern: true,
    concernDescription: 'A loose cable is visible on the floor',
    uncertainty: 'The far corner is too dim to identify clearly',
    direction: SceneDirection.centre,
    objects: ['desk', 'cup', 'notebook'],
    imageQuality: ImageQuality.usable,
  );

  group('AgentCoordinator Consent Enforcement', () {
    test('executeDescribe with consent=false makes 0 cloud requests and sets cloudConsentRequired error', () async {
      expect(prefs.cloudConsentGranted, false);

      await coordinator.executeDescribe();

      expect(vision.describeCalls, 0);
      expect(coordinator.state, OperationState.error);
      expect(
        coordinator.errorMessage,
        contains('Cloud processing requires consent'),
      );
      expect(
        tts.spokenTexts.last,
        contains('Cloud processing requires consent'),
      );
    });

    test('an error is not spoken when automatic reading is off', () async {
      await prefs.setAutoRead(false);
      await coordinator.executeDescribe();
      expect(coordinator.state, OperationState.error);
      expect(
        coordinator.errorMessage,
        contains('Cloud processing requires consent'),
      );
      expect(tts.spokenTexts, isEmpty);
    });

    test('executeAskQuestion with consent=false makes 0 cloud requests and sets error', () async {
      expect(prefs.cloudConsentGranted, false);

      await coordinator.executeAskQuestion('Where is the door?');

      expect(vision.askCalls, 0);
      expect(coordinator.state, OperationState.error);
      expect(
        coordinator.errorMessage,
        contains('Cloud processing requires consent'),
      );
    });

    test('executeReadText with consent=false succeeds offline without cloud requests', () async {
      expect(prefs.cloudConsentGranted, false);

      await coordinator.executeReadText();

      expect(vision.describeCalls, 0);
      expect(vision.askCalls, 0);
      expect(coordinator.state, OperationState.idle);
      expect(
        coordinator.lastResultText,
        'Recognised printed document headline',
      );
      expect(coordinator.lastPresentation?.kind, TaskKind.readText);
      expect(
        coordinator.lastSceneResult,
        isNull,
        reason: 'Scene-only metadata must be cleared after OCR',
      );
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

  group('AgentCoordinator cancellation races', () {
    test(
      'cancelActiveWork cancels camera and recognition without speaking',
      () async {
        await coordinator.executeVoiceCommand();
        expect(coordinator.state, OperationState.listening);
        final spokenBeforeCancel = List<String>.of(tts.spokenTexts);
        final stopsBeforeCancel = tts.stopCalls;

        coordinator.cancelActiveWork();
        await pumpEventQueue();

        expect(camera.cancelCalls, 1);
        expect(speech.cancelCalls, 1);
        expect(
          speech.stopCalls,
          0,
          reason: 'Stop may still deliver a final result',
        );
        expect(tts.stopCalls, greaterThan(stopsBeforeCancel));
        expect(tts.spokenTexts, spokenBeforeCancel);
        expect(coordinator.state, OperationState.idle);
        expect(coordinator.activeWork, isNull);
        expect(coordinator.errorMessage, isNull);
      },
    );

    for (final kind in TaskKind.values) {
      test(
        'Stop before ${kind.name} haptic completes prevents capture',
        () async {
          await prefs.setCloudConsentGranted(true);
          final gate = _Gate();
          haptic.confirmGate = gate;
          final operation = runTask(kind);
          await gate.entered.future;
          expect(coordinator.state, OperationState.capturing);
          expect(camera.captureCount, 0);

          coordinator.stop();
          await pumpEventQueue();
          final spokenAfterStop = List<String>.of(tts.spokenTexts);
          gate.release();
          await operation;

          expect(camera.cancelCalls, 1);
          expect(speech.cancelCalls, 1);
          expect(camera.captureCount, 0);
          expect(ocr.recognizeCalls, 0);
          expect(vision.describeCalls + vision.askCalls, 0);
          expect(coordinator.lastPresentation, isNull);
          expect(coordinator.state, OperationState.idle);
          expect(coordinator.activeWork, isNull);
          expect(coordinator.errorMessage, isNull);
          expect(tts.spokenTexts, spokenAfterStop);
        },
      );
    }

    for (final kind in [TaskKind.describe, TaskKind.askQuestion]) {
      test(
        'Stop before ${kind.name} speech rejects the old generation',
        () async {
          await prefs.setCloudConsentGranted(true);
          vision.cannedResult = detailedScene;
          final gate = _Gate();
          earcons.stopLoopGate = gate;
          final operation = runTask(kind);
          await gate.entered.future;
          final presentation = coordinator.lastPresentation!;
          expect(tts.spokenTexts, isNot(contains(presentation.toSpokenText())));

          coordinator.stop();
          await pumpEventQueue();
          await coordinator.executeVoiceCommand();
          expect(coordinator.state, OperationState.listening);
          final spokenAfterRestart = List<String>.of(tts.spokenTexts);
          final laterStates = <OperationState>[];
          coordinator.addListener(() => laterStates.add(coordinator.state));

          gate.release();
          await operation;
          await pumpEventQueue();

          expect(tts.spokenTexts, spokenAfterRestart);
          expect(laterStates, isNot(contains(OperationState.speaking)));
          expect(coordinator.state, OperationState.listening);
          expect(coordinator.activeWork, ActiveWork.voiceCommand);
          expect(coordinator.errorMessage, isNull);
          expect(camera.deletedFiles, hasLength(1));
        },
      );
    }

    test('Stop discards late local OCR and deletes its capture', () async {
      final gate = _Gate();
      ocr.recognitionGate = gate;
      final operation = coordinator.executeReadText();
      await gate.entered.future;
      expect(coordinator.state, OperationState.processingLocal);

      coordinator.stop();
      await pumpEventQueue();
      final spokenAfterStop = List<String>.of(tts.spokenTexts);
      gate.release();
      await operation;

      expect(coordinator.lastResultText, isNull);
      expect(coordinator.lastPresentation, isNull);
      expect(coordinator.state, OperationState.idle);
      expect(coordinator.activeWork, isNull);
      expect(coordinator.errorMessage, isNull);
      expect(tts.spokenTexts, spokenAfterStop);
      expect(camera.deletedFiles, hasLength(1));
      expect(vision.describeCalls + vision.askCalls, 0);
    });

    for (final question in [false, true]) {
      test(
        'late ${question ? 'question' : 'command'} callbacks cannot affect a new listener',
        () async {
          await prefs.setCloudConsentGranted(true);
          if (question) {
            await coordinator.startVoiceAsk();
          } else {
            await coordinator.executeVoiceCommand();
          }
          final oldSession = speech.sessions.single;
          coordinator.cancelActiveWork();
          await coordinator.executeVoiceCommand();
          final spokenAfterRestart = List<String>.of(tts.spokenTexts);

          await oldSession.result(question ? 'Where is the door?' : 'describe');
          for (final type in [
            SpeechOutcomeType.timeout,
            SpeechOutcomeType.error,
            SpeechOutcomeType.cancelled,
          ]) {
            oldSession.outcome(type);
          }
          await pumpEventQueue();

          expect(coordinator.state, OperationState.listening);
          expect(coordinator.activeWork, ActiveWork.voiceCommand);
          expect(coordinator.errorMessage, isNull);
          expect(camera.captureCount, 0);
          expect(vision.describeCalls + vision.askCalls, 0);
          expect(tts.spokenTexts, spokenAfterRestart);
        },
      );
    }
  });

  group('AgentCoordinator consent withdrawal races', () {
    for (final kind in [TaskKind.describe, TaskKind.askQuestion]) {
      test(
        'withdrawing consent during ${kind.name} capture prevents upload',
        () async {
          await coordinator.executeReadText();
          final previous = coordinator.lastPresentation;
          camera.deletedFiles.clear();
          await prefs.setCloudConsentGranted(true);
          final gate = _Gate();
          camera.imageCaptureGate = gate;
          final operation = runTask(kind);
          await gate.entered.future;
          expect(coordinator.state, OperationState.capturing);
          tts.spokenTexts.clear();

          await prefs.setCloudConsentGranted(false);

          expect(coordinator.state, OperationState.idle);
          expect(coordinator.activeWork, isNull);
          expect(camera.cancelCalls, 1);
          expect(speech.cancelCalls, 1);
          gate.release();
          await operation;
          await pumpEventQueue();

          expect(vision.describeCalls + vision.askCalls, 0);
          expect(coordinator.lastPresentation, same(previous));
          expect(coordinator.state, OperationState.idle);
          expect(coordinator.errorMessage, isNull);
          expect(tts.spokenTexts, isEmpty);
          expect(camera.deletedFiles, hasLength(1));
        },
      );

      for (final fails in [false, true]) {
        test(
          'withdrawing consent during ${kind.name} cloud work ignores late ${fails ? 'error' : 'result'}',
          () async {
            await coordinator.executeReadText();
            final previous = coordinator.lastPresentation;
            camera.deletedFiles.clear();
            await prefs.setCloudConsentGranted(true);
            final gate = _Gate();
            vision.responseGate = gate;
            if (fails) {
              vision.failure = StateError('Late fake provider failure');
            }
            final operation = runTask(kind);
            await gate.entered.future;
            expect(coordinator.state, OperationState.processingCloud);
            final token = vision.cancelTokens.single;
            expect(token.isCancelled, isFalse);
            tts.spokenTexts.clear();

            await prefs.setCloudConsentGranted(false);

            expect(token.isCancelled, isTrue);
            expect(coordinator.state, OperationState.idle);
            expect(coordinator.activeWork, isNull);
            expect(camera.cancelCalls, 1);
            expect(speech.cancelCalls, 1);
            gate.release();
            await operation;
            await pumpEventQueue();

            expect(vision.describeCalls + vision.askCalls, 1);
            expect(coordinator.lastPresentation, same(previous));
            expect(coordinator.lastResultText, previous!.responseText);
            expect(coordinator.state, OperationState.idle);
            expect(coordinator.activeWork, isNull);
            expect(coordinator.errorMessage, isNull);
            expect(tts.spokenTexts, isEmpty);
            expect(camera.deletedFiles, hasLength(1));
          },
        );
      }
    }

    test('withdrawing cloud consent leaves offline OCR running', () async {
      await prefs.setCloudConsentGranted(true);
      final gate = _Gate();
      ocr.recognitionGate = gate;
      final operation = coordinator.executeReadText();
      await gate.entered.future;

      await prefs.setCloudConsentGranted(false);

      expect(coordinator.state, OperationState.processingLocal);
      expect(coordinator.activeWork, ActiveWork.readText);
      expect(camera.cancelCalls, 0);
      expect(speech.cancelCalls, 0);
      gate.release();
      await operation;

      expect(coordinator.lastResultText, ocr.textToReturn);
      expect(tts.spokenTexts.last, ocr.textToReturn);
      expect(coordinator.state, OperationState.idle);
      expect(vision.describeCalls + vision.askCalls, 0);
    });

    test('unrelated preference changes do not cancel cloud work', () async {
      await prefs.setCloudConsentGranted(true);
      final gate = _Gate();
      vision.responseGate = gate;
      final operation = coordinator.executeDescribe();
      await gate.entered.future;

      await prefs.setSpeechRate(1.2);
      await prefs.setCloudConsentGranted(true);

      expect(vision.cancelTokens.single.isCancelled, isFalse);
      expect(coordinator.state, OperationState.processingCloud);
      expect(coordinator.activeWork, ActiveWork.describe);
      expect(camera.cancelCalls, 0);
      expect(speech.cancelCalls, 0);
      gate.release();
      await operation;
      expect(coordinator.lastPresentation?.kind, TaskKind.describe);
      expect(coordinator.state, OperationState.idle);
    });
  });

  group('AgentCoordinator complete result speech', () {
    for (final kind in [TaskKind.describe, TaskKind.askQuestion]) {
      test(
        '${kind.name} speaks all content, concern and uncertainty',
        () async {
          await prefs.setCloudConsentGranted(true);
          vision.cannedResult = detailedScene;

          await runTask(kind);

          final content = kind == TaskKind.describe
              ? detailedScene.summary
              : detailedScene.answer!;
          final spoken = tts.spokenTexts.last;
          expect(spoken, contains(content));
          expect(spoken, contains(detailedScene.concernDescription!));
          expect(spoken, contains(detailedScene.uncertainty!));
          expect(spoken, coordinator.lastPresentation!.toSpokenText());
          expect(coordinator.lastResultText, content);
          expect(coordinator.state, OperationState.idle);
          expect(coordinator.activeWork, isNull);
        },
      );
    }

    test(
      'long multiline OCR is spoken in full and clears scene metadata',
      () async {
        await prefs.setCloudConsentGranted(true);
        vision.cannedResult = detailedScene;
        await coordinator.executeDescribe();
        expect(coordinator.lastSceneResult, isNotNull);
        ocr.textToReturn = List.generate(
          80,
          (index) =>
              'Paragraph $index. Keep this entire line of recognised text.',
        ).join('\n');
        tts.spokenTexts.clear();

        await coordinator.executeReadText();

        expect(coordinator.lastResultText, ocr.textToReturn);
        expect(coordinator.lastSceneResult, isNull);
        expect(coordinator.lastPresentation?.uncertainty, isNull);
        expect(coordinator.lastPresentation?.possibleConcern, isFalse);
        expect(tts.spokenTexts.where((text) => text.contains('Paragraph')), [
          ocr.textToReturn,
        ]);
        expect(coordinator.state, OperationState.idle);
        expect(coordinator.activeWork, isNull);
      },
    );

    for (final kind in TaskKind.values) {
      test(
        'manual repeat speaks ${kind.name} even with autoRead disabled',
        () async {
          await prefs.setCloudConsentGranted(true);
          await prefs.setAutoRead(false);
          vision.cannedResult = detailedScene;
          await runTask(kind);
          final presentation = coordinator.lastPresentation!;
          expect(tts.spokenTexts, isNot(contains(presentation.toSpokenText())));
          final captureCount = camera.captureCount;
          final cloudCalls = vision.describeCalls + vision.askCalls;
          tts.spokenTexts.clear();

          await coordinator.repeatLast();

          expect(tts.spokenTexts, [presentation.asPrevious().toSpokenText()]);
          expect(
            coordinator.lastPresentation?.status,
            PresentationStatus.previous,
          );
          expect(coordinator.state, OperationState.idle);
          expect(camera.captureCount, captureCount);
          expect(vision.describeCalls + vision.askCalls, cloudCalls);
        },
      );
    }
  });

  group('AgentCoordinator voice dispatch and outcomes', () {
    test('voice repeat leaves Listening and reads the previous result with autoRead off', () async {
      await prefs.setAutoRead(false);
      await coordinator.executeReadText();
      final presentation = coordinator.lastPresentation!;
      await coordinator.executeVoiceCommand();
      expect(coordinator.state, OperationState.listening);
      tts.spokenTexts.clear();

      await speech.sessions.single.result('repeat');
      await pumpEventQueue();

      expect(tts.spokenTexts, [presentation.asPrevious().toSpokenText()]);
      expect(coordinator.lastPresentation?.status, PresentationStatus.previous);
      expect(coordinator.state, OperationState.idle);
      expect(coordinator.activeWork, isNull);
      expect(camera.captureCount, 1);
      expect(vision.describeCalls + vision.askCalls, 0);
    });

    for (final command in {
      'describe': TaskKind.describe,
      'read text': TaskKind.readText,
      'Where is the cup?': TaskKind.askQuestion,
    }.entries) {
      test('final voice command dispatches ${command.value.name}', () async {
        await prefs.setCloudConsentGranted(true);
        await coordinator.executeVoiceCommand();
        final gate = _Gate();
        haptic.confirmGate = gate;

        await speech.sessions.single.result(command.key);
        await gate.entered.future;

        expect(coordinator.state, OperationState.capturing);
        expect(coordinator.activeWork, switch (command.value) {
          TaskKind.describe => ActiveWork.describe,
          TaskKind.readText => ActiveWork.readText,
          TaskKind.askQuestion => ActiveWork.ask,
        });
        gate.release();
        await pumpEventQueue();

        expect(coordinator.lastPresentation?.kind, command.value);
        expect(coordinator.state, OperationState.idle);
        expect(coordinator.activeWork, isNull);
        expect(camera.captureCount, 1);
        expect(
          vision.describeCalls,
          command.value == TaskKind.describe ? 1 : 0,
        );
        expect(vision.askCalls, command.value == TaskKind.askQuestion ? 1 : 0);
        if (command.value == TaskKind.askQuestion) {
          expect(vision.questions, [command.key]);
        }
      });
    }

    test('partial and empty voice results do not dispatch work', () async {
      await coordinator.executeVoiceCommand();
      final session = speech.sessions.single;

      await session.result('read text', isFinal: false);
      session.outcome(SpeechOutcomeType.recognized);
      expect(coordinator.state, OperationState.listening);
      expect(coordinator.activeWork, ActiveWork.voiceCommand);
      expect(camera.captureCount, 0);

      await session.result('  ');
      await pumpEventQueue();

      expect(coordinator.state, OperationState.idle);
      expect(coordinator.activeWork, isNull);
      expect(camera.captureCount, 0);
      expect(vision.describeCalls + vision.askCalls, 0);
    });

    for (final question in [false, true]) {
      for (final type in SpeechOutcomeType.values.where(
        (type) => type != SpeechOutcomeType.recognized,
      )) {
        test(
          '${question ? 'question' : 'command'} handles ${type.name} without getting stuck Listening',
          () async {
            await prefs.setCloudConsentGranted(true);
            if (question) {
              await coordinator.startVoiceAsk();
            } else {
              await coordinator.executeVoiceCommand();
            }
            expect(coordinator.state, OperationState.listening);
            tts.spokenTexts.clear();

            speech.sessions.single.outcome(type);
            await pumpEventQueue();

            final isError = {
              SpeechOutcomeType.permissionDenied,
              SpeechOutcomeType.unavailable,
              SpeechOutcomeType.error,
            }.contains(type);
            expect(
              coordinator.state,
              isError ? OperationState.error : OperationState.idle,
            );
            expect(coordinator.activeWork, isNull);
            if (isError) {
              expect(coordinator.errorMessage, isNotEmpty);
            } else {
              expect(coordinator.errorMessage, isNull);
            }
            if (type == SpeechOutcomeType.cancelled) {
              expect(tts.spokenTexts, isEmpty);
            } else {
              expect(tts.spokenTexts, isNotEmpty);
            }
            expect(camera.captureCount, 0);
            expect(vision.describeCalls + vision.askCalls, 0);
          },
        );
      }
    }

    test(
      'a final voice question starts one cloud task and preserves the question',
      () async {
        await prefs.setCloudConsentGranted(true);
        await coordinator.startVoiceAsk();
        final session = speech.sessions.single;
        await session.result('Where is the blue cup?', isFinal: false);
        expect(camera.captureCount, 0);

        await session.result('Where is the blue cup?');
        await pumpEventQueue();

        expect(vision.questions, ['Where is the blue cup?']);
        expect(vision.askCalls, 1);
        expect(vision.describeCalls, 0);
        expect(camera.captureCount, 1);
        expect(coordinator.lastPresentation?.kind, TaskKind.askQuestion);
        expect(coordinator.state, OperationState.idle);
        expect(coordinator.activeWork, isNull);
      },
    );
  });

  group('AgentCoordinator busy task rejection', () {
    for (final busyState in [
      OperationState.listening,
      OperationState.capturing,
      OperationState.processingLocal,
      OperationState.processingCloud,
      OperationState.speaking,
    ]) {
      test('task entry points do nothing while ${busyState.name}', () async {
        await prefs.setCloudConsentGranted(true);
        coordinator.debugSetOperationState(busyState);
        coordinator.debugSetActiveWork(ActiveWork.describe);
        final tasks = <String, Future<void> Function()>{
          'describe': coordinator.executeDescribe,
          'read text': coordinator.executeReadText,
          'typed question': () =>
              coordinator.executeAskQuestion('Where is the cup?'),
          'voice question': coordinator.startVoiceAsk,
          'voice command': coordinator.executeVoiceCommand,
          'current mode': coordinator.runCurrentMode,
        };

        for (final task in tasks.entries) {
          await task.value();
          expect(coordinator.state, busyState, reason: task.key);
          expect(coordinator.activeWork, ActiveWork.describe, reason: task.key);
        }

        expect(camera.captureCount, 0);
        expect(camera.cancelCalls, 0);
        expect(ocr.recognizeCalls, 0);
        expect(vision.describeCalls + vision.askCalls, 0);
        expect(speech.sessions, isEmpty);
        expect(speech.cancelCalls, 0);
        expect(tts.spokenTexts, isEmpty);
        expect(tts.stopCalls, 0);
        expect(haptic.confirmCalls, 0);
        expect(coordinator.lastPresentation, isNull);
        expect(coordinator.errorMessage, isNull);
      });
    }
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
