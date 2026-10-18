import 'dart:io';

import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/features/ask/ask_screen.dart';
import 'package:eyesense/features/diagnostics/diagnostics_screen.dart';
import 'package:eyesense/features/home/home_screen.dart';
import 'package:eyesense/features/legal/legal_document_screen.dart';
import 'package:eyesense/features/onboarding/onboarding_screen.dart';
import 'package:eyesense/features/profile/profile_choice_screen.dart';
import 'package:eyesense/features/settings/ai_connection_screen.dart';
import 'package:eyesense/features/settings/settings_screen.dart';
import 'package:eyesense/services/diagnostic_log_service.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coordinator_test.dart';
import 'provider_contract_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PreferencesService prefs;
  late DiagnosticLogService logs;
  late Directory logDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'cloud_consent_granted': true,
      'app_language': 'en',
      'auto_read': false,
      'assistance_profile': 'sightedAssistant',
      'assistance_profile_chosen': true,
      'completed_onboarding': true,
      'launch_orientation_count': 3,
      'earcons_enabled': false,
      'onboarding_step': 0,
    });
    prefs = await PreferencesService.create();
    logDir = await Directory.systemTemp.createTemp('eyesense-layout-logs');
    logs = DiagnosticLogService(prefs, directory: logDir);
  });

  tearDown(() async {
    if (await logDir.exists()) await logDir.delete(recursive: true);
  });

  Future<void> pumpScaled(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: home,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets('every primary screen fits at 320 px and 200 percent text', (tester) async {
    final coordinator = AgentCoordinator(
      cameraService: FakeCameraService(),
      ttsService: FakeTtsService(prefs),
      speechService: FakeSpeechService(),
      ocrService: FakeOcrService(),
      hapticService: FakeHapticService(prefs),
      preferencesService: prefs,
      credentialService: MemoryCredentials(),
      logService: logs,
      visionApi: FakeVisionApiService(),
    );

    await pumpScaled(tester, HomeScreen(coordinator: coordinator));
    await pumpScaled(tester, SettingsScreen(
      preferencesService: prefs,
      credentialService: MemoryCredentials(),
      logService: logs,
      coordinator: coordinator,
    ));
    await pumpScaled(tester, OnboardingScreen(coordinator: coordinator, onFinish: () {}));
    await pumpScaled(tester, AskScreen(coordinator: coordinator));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await pumpScaled(tester, AiConnectionScreen(
      preferencesService: prefs,
      credentialService: MemoryCredentials(),
      coordinator: coordinator,
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await pumpScaled(tester, DiagnosticsScreen(preferencesService: prefs, logService: logs));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await pumpScaled(tester, const LegalDocumentScreen(
      title: 'Privacy Policy',
      documentBase: 'assets/legal/privacy-policy',
      language: 'en',
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await pumpScaled(tester, ProfileChoiceScreen(preferences: prefs, onChosen: () {}));
  });

  testWidgets('settings can change the assistance profile', (tester) async {
    final coordinator = AgentCoordinator(
      cameraService: FakeCameraService(),
      ttsService: FakeTtsService(prefs),
      speechService: FakeSpeechService(),
      ocrService: FakeOcrService(),
      hapticService: FakeHapticService(prefs),
      preferencesService: prefs,
      credentialService: MemoryCredentials(),
      logService: logs,
      visionApi: FakeVisionApiService(),
    );
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        preferencesService: prefs,
        credentialService: MemoryCredentials(),
        logService: logs,
        coordinator: coordinator,
      ),
    ));
    await tester.pump();
    await tester.ensureVisible(find.text('I use a screen reader'));
    await tester.tap(find.text('I use a screen reader'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(prefs.assistanceProfile, AssistanceProfile.screenReader);
    expect(prefs.autoRead, isTrue);
    expect(prefs.earconsEnabled, isTrue);
  });

  testWidgets('onboarding reads the current step aloud', (tester) async {
    final tts = FakeTtsService(prefs);
    final coordinator = AgentCoordinator(
      cameraService: FakeCameraService(),
      ttsService: tts,
      speechService: FakeSpeechService(),
      ocrService: FakeOcrService(),
      hapticService: FakeHapticService(prefs),
      preferencesService: prefs,
      credentialService: MemoryCredentials(),
      logService: logs,
      visionApi: FakeVisionApiService(),
    );
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(coordinator: coordinator, onFinish: () {}),
    ));
    await tester.pump();
    await tester.ensureVisible(find.text('Read this aloud'));
    await tester.tap(find.text('Read this aloud'));
    await tester.pump();
    expect(tts.spokenTexts.last, contains('Welcome to EyeSense'));
  });
}
