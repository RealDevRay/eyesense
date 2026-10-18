import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/features/home/home_screen.dart';
import 'package:eyesense/models/app_operation.dart';
import 'package:eyesense/services/credential_service.dart';
import 'package:eyesense/services/diagnostic_log_service.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coordinator_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AgentCoordinator coordinator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'cloud_consent_granted': true,
      'app_language': 'en',
      'auto_read': true,
      'assistance_profile_chosen': true,
      'launch_orientation_count': 3,
      'earcons_enabled': false,
    });
    final prefs = await PreferencesService.create();
    final tts = FakeTtsService(prefs);
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

  Future<void> pumpHome(WidgetTester tester, {double width = 800, double height = 1200, double scale = 1}) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: HomeScreen(coordinator: coordinator),
      ),
    );
    await tester.pump();
  }

  testWidgets('home controls keep their offsets across operation states', (tester) async {
    await pumpHome(tester);
    final keys = ['action-voice', 'action-describe', 'action-read', 'action-ask', 'action-repeat', 'action-stop'];
    final idle = {for (final key in keys) key: tester.getTopLeft(find.byKey(Key(key))).dy};

    for (final state in [
      OperationState.capturing,
      OperationState.processingCloud,
      OperationState.speaking,
    ]) {
      coordinator.debugSetOperationState(state);
      await tester.pump();
      for (final key in keys) {
        expect(tester.getTopLeft(find.byKey(Key(key))).dy, idle[key], reason: key);
      }
    }
  });

  testWidgets('action buttons expose one label and hint', (tester) async {
    await pumpHome(tester);
    final describe = tester.getSemantics(find.byKey(const Key('action-describe')));
    expect(describe.label, 'Describe scene');
    expect(describe.hint, 'Take a picture and describe visible information');
    expect(describe.flagsCollection.isButton, isTrue);
    expect(describe.flagsCollection.isEnabled, Tristate.isTrue);

    coordinator.debugSetOperationState(OperationState.capturing);
    coordinator.debugSetActiveWork(ActiveWork.describe);
    await tester.pump();
    final busy = tester.getSemantics(find.byKey(const Key('action-describe')));
    expect(busy.label, 'Describe scene');
    expect(busy.flagsCollection.isEnabled, Tristate.isFalse);
  });

  testWidgets('home does not overflow at 320 px and 200 percent text', (tester) async {
    await pumpHome(tester, width: 320, height: 640, scale: 2);
    expect(tester.takeException(), isNull);
  });
}
