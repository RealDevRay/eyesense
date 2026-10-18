import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/models/app_operation.dart';
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

class DelayedChunkTtsService extends TtsService {
  final List<String> spokenChunks = [];
  bool wasStopped = false;

  DelayedChunkTtsService(super.prefs);

  @override
  Future<void> speak(String text) async {
    final chunks = TtsService.splitIntoChunks(text);
    for (final chunk in chunks) {
      if (wasStopped) break;
      spokenChunks.add(chunk);
      // Simulate asynchronous playback
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  @override
  Future<void> stop() async {
    wasStopped = true;
    await super.stop();
  }
}

class FakeOutcomeSpeechService extends SpeechService {
  SpeechOutcome? outcomeToEmit;

  @override
  Future<void> listen({
    required Function(String recognizedWords, bool isFinal) onResult,
    Function(SpeechOutcome outcome)? onOutcome,
    String? localeId,
    Duration listenFor = const Duration(seconds: 10),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (outcomeToEmit != null) {
      onOutcome?.call(outcomeToEmit!);
    }
  }
}

class StubVisionApiService implements VisionApiService {
  @override
  Future<SceneResult> describeScene({
    required String requestId,
    required String base64Jpeg,
    required String language,
    dynamic cancelToken,
    Duration? timeout,
  }) async {
    return const SceneResult(
      summary: 'Stub scene description',
      possibleConcern: false,
      direction: SceneDirection.centre,
      objects: [],
      imageQuality: ImageQuality.usable,
    );
  }

  @override
  Future<SceneResult> askQuestion({
    required String requestId,
    required String base64Jpeg,
    required String question,
    required String language,
    dynamic cancelToken,
    Duration? timeout,
  }) async {
    return const SceneResult(
      summary: 'Stub question answer',
      answer: 'The answer is here.',
      possibleConcern: false,
      direction: SceneDirection.centre,
      objects: [],
      imageQuality: ImageQuality.usable,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TtsService Chunking', () {
    test('short text returns single chunk unchanged', () {
      final text = 'Short scene summary.';
      final chunks = TtsService.splitIntoChunks(text, 100);
      expect(chunks.length, 1);
      expect(chunks.first, text);
    });

    test('long text exceeding limit is split into bounded chunks respecting sentences', () {
      // 5,000 characters of sentences
      final sentence = 'This is a clear sentence describing the surroundings. ';
      final longText = sentence * 100; // ~5,500 characters
      expect(longText.length, greaterThan(4000));

      final chunks = TtsService.splitIntoChunks(longText, 1000);
      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(1000));
        expect(chunk.trim().isNotEmpty, true);
      }
    });

    test('empty or whitespace text produces empty list', () {
      expect(TtsService.splitIntoChunks(''), isEmpty);
      expect(TtsService.splitIntoChunks('   \n  '), isEmpty);
    });
  });

  group('SpeechService Outcomes & Question Bounds', () {
    late PreferencesService prefs;
    late AgentCoordinator coordinator;
    late FakeOutcomeSpeechService speech;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'cloud_consent_granted': true,
        'app_language': 'en',
      });
      prefs = await PreferencesService.create();
      speech = FakeOutcomeSpeechService();

      coordinator = AgentCoordinator(
        cameraService: CameraService(),
        ttsService: DelayedChunkTtsService(prefs),
        speechService: speech,
        ocrService: OcrService(),
        hapticService: HapticService(prefs),
        preferencesService: prefs,
        credentialService: CredentialService(),
        logService: DiagnosticLogService(prefs),
        visionApi: StubVisionApiService(),
      );
    });

    test('rejects questions exceeding 300 character limit', () async {
      final longQuestion = 'A' * 301;
      await coordinator.executeAskQuestion(longQuestion);

      expect(coordinator.state, OperationState.error);
      expect(coordinator.errorMessage, contains('longer than 300 characters'));
    });

    test('voice ask handles noSpeech outcome by returning to idle with explanation', () async {
      speech.outcomeToEmit = const SpeechOutcome(
        type: SpeechOutcomeType.noSpeech,
      );

      await coordinator.startVoiceAsk();

      expect(coordinator.state, OperationState.idle);
    });

    test('voice ask handles permissionDenied outcome by setting error message', () async {
      speech.outcomeToEmit = const SpeechOutcome(
        type: SpeechOutcomeType.permissionDenied,
        errorMessage: 'Microphone denied',
      );

      await coordinator.startVoiceAsk();

      expect(coordinator.state, OperationState.error);
      expect(coordinator.errorMessage, contains('Microphone permission was denied'));
    });
  });
}
