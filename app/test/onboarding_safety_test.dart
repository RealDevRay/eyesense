import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/features/onboarding/onboarding_screen.dart';
import 'package:eyesense/features/onboarding/safety_briefing.dart';
import 'package:eyesense/services/credential_service.dart';
import 'package:eyesense/services/diagnostic_log_service.dart';
import 'package:eyesense/services/preferences_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coordinator_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AgentCoordinator coordinator;
  late PreferencesService prefs;
  late FakeTtsService tts;
  late bool finished;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'app_language': 'en',
      'auto_read': true,
      'assistance_profile_chosen': true,
    });
    prefs = await PreferencesService.create();
    tts = FakeTtsService(prefs);
    finished = false;
    coordinator = AgentCoordinator(
      cameraService: FakeCameraService(),
      ttsService: tts,
      speechService: FakeSpeechService(),
      ocrService: FakeOcrService(),
      hapticService: FakeHapticService(prefs),
      preferencesService: prefs,
      credentialService: CredentialService(),
      logService: DiagnosticLogService(prefs),
      visionApi: FakeVisionApiService(),
    );
  });

  Future<void> pumpOnboarding(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          coordinator: coordinator,
          onFinish: () => finished = true,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.tap(find.text('Continue'));
    await tester.pump();
  }

  testWidgets('the briefing is reached on the second step and spoken aloud', (tester) async {
    await pumpOnboarding(tester);
    expect(find.text('Safety and limits'), findsNothing);

    await tapContinue(tester);

    expect(find.text('Safety and limits'), findsOneWidget);
    expect(find.text('This is not a mobility aid'), findsOneWidget);
    expect(tts.spokenTexts.last, spokenSafetyBriefing());
  });

  testWidgets('each limit is one navigable node carrying its whole text', (tester) async {
    await pumpOnboarding(tester);
    await tapContinue(tester);

    for (final limit in safetyLimits) {
      final node = tester.getSemantics(find.text(limit.title));
      expect(node.label, '${limit.title}. ${limit.detail}');
    }
  });

  testWidgets('continue is held until the limits are acknowledged, and says why', (tester) async {
    await pumpOnboarding(tester);
    await tapContinue(tester);

    await tapContinue(tester);
    expect(find.text('Safety and limits'), findsOneWidget, reason: 'should not have advanced');
    expect(tts.spokenTexts.last, contains('I understand these limits'));
    expect(prefs.hasAcknowledgedSafety, isFalse);

    await tester.tap(find.text('I understand these limits'));
    await tester.pump();
    expect(prefs.hasAcknowledgedSafety, isTrue);

    await tapContinue(tester);
    expect(find.text('Safety and limits'), findsNothing);
  });

  testWidgets('skip lands on the briefing rather than leaving it unread', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(find.text('Safety and limits'), findsOneWidget);
    expect(finished, isFalse);
    // No skip button to escape it with.
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('an acknowledged briefing is not forced on again', (tester) async {
    await prefs.recordSafetyAcknowledgement();
    await pumpOnboarding(tester);

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(finished, isTrue);
  });
}
