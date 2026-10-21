import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/agents/output_policy.dart';
import 'package:eyesense/models/scene_result.dart';
import 'package:eyesense/services/diagnostic_log_service.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coordinator_test.dart';
import 'provider_contract_test.dart' show MemoryCredentials;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const unsafeOutputs = [
    'You may safely cross.',
    'Take three steps forward.',
    'The chair is 2 m away.',
    'Safe to\ncross.',
    'Safe\u00a0to\u00a0cross.',
    'sa\u200bfe to cross',
    'SAFE-TO-CROSS',
    'Move two steps left.',
    'Turn right.',
    'Walk straight.',
    'The door is two metres ahead.',
    'It is 3 ft from you.',
    'Geuka kushoto.',
    'Piga hatua tatu.',
    'Ni mita mbili kutoka hapa.',
  ];
  for (final text in unsafeOutputs) {
    test('blocks known safety bypass: $text', () {
      expect(OutputPolicy.containsProhibitedSafetyGuidance(text), isTrue);
      final result = OutputPolicy.applyFieldReplacements(
        SceneResult(
          summary: text,
          answer: text,
          possibleConcern: true,
          concernDescription: text,
          direction: SceneDirection.unknown,
          objects: [text],
          imageQuality: ImageQuality.usable,
          uncertainty: text,
        ),
        'en',
      );
      expect(result.summary, contains('cannot confirm navigation safety'));
      expect(result.answer, contains('cannot determine path safety'));
      expect(result.concernDescription, contains('Safety limitation'));
      expect(result.uncertainty, contains('Safety limitation'));
      expect(result.objects, ['unspecified']);
    });
  }
  for (final text in [
    'A cup on the left of a desk.',
    'The sign reads OPEN.',
    'I cannot determine path safety from this image.',
  ]) {
    test('retains descriptive information: $text', () {
      expect(OutputPolicy.containsProhibitedSafetyGuidance(text), isFalse);
    });
  }
  for (final text in [
    'Can I cross the road?',
    'How far is the door?',
    'How many steps to the chair?',
    'Is the path safe to walk?',
    'Which way should I turn?',
    'Naweza kuvuka?',
    'Umbali ni gani?',
  ]) {
    test(
      'refuses navigation before capture, consent and inference: $text',
      () async {
        SharedPreferences.setMockInitialValues({
          'cloud_consent_granted': false,
          'earcons_enabled': false,
        });
        final prefs = await PreferencesService.create();
        final camera = FakeCameraService();
        final vision = FakeVisionApiService();
        final tts = FakeTtsService(prefs);
        final coordinator = AgentCoordinator(
          cameraService: camera,
          ttsService: tts,
          speechService: FakeSpeechService(),
          ocrService: FakeOcrService(),
          hapticService: FakeHapticService(prefs),
          preferencesService: prefs,
          credentialService: MemoryCredentials(),
          logService: DiagnosticLogService(prefs),
          visionApi: vision,
        );
        await coordinator.executeAskQuestion(text);
        expect(camera.captureCount, 0);
        expect(vision.askCalls, 0);
        expect(
          coordinator.lastResultText,
          contains('cannot decide whether a route is safe'),
        );
        expect(
          tts.spokenTexts,
          contains(contains('cannot decide whether a route is safe')),
        );
        coordinator.dispose();
      },
    );
  }
}
