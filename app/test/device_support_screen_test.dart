import 'dart:async';

import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/features/settings/device_support_screen.dart';
import 'package:eyesense/services/device_sensor_service.dart';
import 'package:eyesense/services/diagnostic_log_service.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:eyesense/widgets/accessible_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coordinator_test.dart';
import 'provider_contract_test.dart' show MemoryCredentials;

class _Sensors extends DeviceSensorService {
  int checks = 0;
  int stops = 0;
  Completer<DeviceSensorAssessment>? gate;
  final capabilities = SensorCapabilities(
    supported: true,
    sensors: {
      for (final sensor in DeviceSensor.values)
        sensor: SensorAvailability.missing,
    },
  );
  @override
  Future<SensorCapabilities> getCapabilities() async => capabilities;
  @override
  Future<DeviceSensorAssessment> check({
    Duration timeout = const Duration(milliseconds: 700),
  }) async {
    checks++;
    return gate == null
        ? DeviceSensorAssessment(
            status: DeviceSensorStatus.unavailable,
            capabilities: capabilities,
          )
        : await gate!.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (gate != null && !gate!.isCompleted) {
      gate!.complete(
        DeviceSensorAssessment(
          status: DeviceSensorStatus.cancelled,
          capabilities: capabilities,
        ),
      );
    }
  }
}

class _Camera extends FakeCameraService {
  _Camera(this.sensors);
  final DeviceSensorService sensors;
  @override
  DeviceSensorService get sensorService => sensors;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Sensors sensors;
  late PreferencesService prefs;
  late AgentCoordinator coordinator;
  late FakeTtsService tts;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'auto_read': true,
      'earcons_enabled': false,
    });
    prefs = await PreferencesService.create();
    sensors = _Sensors();
    tts = FakeTtsService(prefs);
    coordinator = AgentCoordinator(
      cameraService: _Camera(sensors),
      ttsService: tts,
      speechService: FakeSpeechService(),
      ocrService: FakeOcrService(),
      hapticService: FakeHapticService(prefs),
      preferencesService: prefs,
      credentialService: MemoryCredentials(),
      logService: DiagnosticLogService(prefs),
      visionApi: FakeVisionApiService(),
    );
  });
  tearDown(() => coordinator.dispose());
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: DeviceSupportScreen(coordinator: coordinator)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'capability discovery never samples; guidance preference persists',
    (tester) async {
      await pump(tester);
      expect(sensors.checks, 0);
      expect(find.textContaining('not present'), findsWidgets);
      expect(sensors.capabilities.sensors.length, 5);
      await tester.tap(find.byKey(const Key('capture-guidance-toggle')));
      await tester.pumpAndSettle();
      expect(prefs.aimingGuidance, isTrue);
      expect(sensors.checks, 0);
    },
  );
  testWidgets('sensor check is an actionable labelled semantics button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await pump(tester);
      await tester.ensureVisible(find.byKey(const Key('sensor-check')));
      await tester.pumpAndSettle();
      final button = tester.getSemantics(find.byKey(const Key('sensor-check')));
      expect(button.label, contains('Check sensors now'));
      expect(button.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester
          .renderObject(find.byKey(const Key('sensor-check')))
          .owner!
          .semanticsOwner!
          .performAction(button.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(sensors.checks, 1);
      expect(
        tts.spokenTexts.last,
        contains('No sensor readings were available'),
      );
    } finally {
      handle.dispose();
    }
  });
  testWidgets('Stop cancels pending check and suppresses late speech', (
    tester,
  ) async {
    sensors.gate = Completer<DeviceSensorAssessment>();
    await pump(tester);
    await tester.ensureVisible(find.byKey(const Key('sensor-check')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sensor-check')));
    await tester.pump();
    final stop = tester.widget<AccessibleActionButton>(
      find.byKey(const Key('sensor-stop')),
    );
    expect(stop.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('sensor-stop')));
    await tester.pumpAndSettle();
    expect(sensors.stops, greaterThan(0));
    expect(tts.spokenTexts, isEmpty);
    expect(find.text('Sensor check stopped.'), findsOneWidget);
  });
  testWidgets('back/dispose cancels without late speech', (tester) async {
    sensors.gate = Completer<DeviceSensorAssessment>();
    await pump(tester);
    await tester.ensureVisible(find.byKey(const Key('sensor-check')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sensor-check')));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(sensors.stops, greaterThan(0));
    expect(tts.spokenTexts, isEmpty);
  });
}
