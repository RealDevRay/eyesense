import 'dart:async';

import 'package:eyesense/services/device_sensor_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class SensorChannels {
  static const methods = MethodChannel('test/eyesense/sensors');
  static const events = EventChannel('test/eyesense/sensor_events');
  static const eventMethods = MethodChannel('test/eyesense/sensor_events');
  static const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final listening = Completer<void>();
  final queried = Completer<void>();
  Map<String, String> sensors = {
    for (final sensor in DeviceSensor.values) sensor.name: 'available',
  };
  Completer<void>? capabilityGate;
  Completer<void>? cancelGate;
  bool missingPlugin = false;
  bool failListen = false;
  int listens = 0;
  int cancels = 0;
  int? session;

  void install() {
    messenger.setMockMethodCallHandler(methods, (call) async {
      expect(call.method, 'capabilities');
      if (!queried.isCompleted) queried.complete();
      await capabilityGate?.future;
      if (missingPlugin) throw MissingPluginException();
      return {'sensors': sensors};
    });
    messenger.setMockMethodCallHandler(eventMethods, (call) async {
      if (call.method == 'listen') {
        listens++;
        session = (call.arguments as Map)['session'] as int;
        if (!listening.isCompleted) listening.complete();
        if (failListen) throw PlatformException(code: 'unavailable');
      } else if (call.method == 'cancel') {
        cancels++;
        await cancelGate?.future;
      } else {
        fail('Unexpected event method: ${call.method}');
      }
      return null;
    });
  }

  Future<void> send(Object? data, {bool envelope = true}) async {
    final done = Completer<void>();
    messenger.handlePlatformMessage(
      events.name,
      envelope ? codec.encodeSuccessEnvelope(data) : null,
      (_) => done.complete(),
    );
    await done.future;
  }

  Future<void> emit(
    String sensor, {
    List<num> values = const [],
    num ageMillis = 0,
    bool? covered,
    int? eventSession,
  }) => send({
    'session': eventSession ?? session,
    'sensor': sensor,
    'values': values,
    'ageMillis': ageMillis,
    'covered': ?covered,
  });

  Future<void> end() => send(null, envelope: false);

  void uninstall() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(eventMethods, null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SensorChannels channels;
  late DeviceSensorService service;
  late DateTime now;

  setUp(() {
    now = DateTime.utc(2026, 10, 21);
    channels = SensorChannels()..install();
    service = DeviceSensorService(
      methodChannel: SensorChannels.methods,
      eventChannel: SensorChannels.events,
      clock: () => now,
    );
  });

  tearDown(() async {
    await service.dispose();
    channels.uninstall();
  });

  Future<DeviceSensorAssessment> sample({
    List<num> gyro = const [0, 0, 0],
    num lux = 100,
    bool covered = false,
  }) async {
    final result = service.check();
    await channels.listening.future;
    await channels.emit('gyroscope', values: gyro);
    await channels.emit('light', values: [lux]);
    await channels.emit('proximity', covered: covered);
    await channels.end();
    return result;
  }

  test('capability discovery and construction never subscribe', () async {
    expect(service.isChecking, isFalse);
    final capabilities = await service.getCapabilities();
    expect(capabilities.hasSensors, isTrue);
    expect(channels.listens, 0);
  });

  test('missing sensors fall back without opening the event channel', () async {
    channels.sensors.updateAll((_, _) => 'missing');
    final result = await service.check();
    expect(result.status, DeviceSensorStatus.unavailable);
    expect(
      result.capabilities.sensors.values,
      everyElement(SensorAvailability.missing),
    );
    expect(result.guidance, isNull);
    expect(channels.listens, 0);
  });

  test('unimplemented platform is optional', () async {
    channels.missingPlugin = true;
    final result = await service.check();
    expect(result.status, DeviceSensorStatus.unsupported);
    expect(result.guidance, isNull);
    expect(channels.listens, 0);
  });

  test(
    'one prioritized cue: rotation before light before front proximity',
    () async {
      final result = await sample(gyro: [1, 0, 0], lux: 2, covered: true);
      expect(result.highAngularMotion, isTrue);
      expect(result.lowLight, isTrue);
      expect(result.frontSensorCovered, isTrue);
      expect(result.guidance, 'Hold the phone steady.');
      expect(result.measurements[DeviceSensor.proximity]!.values, isEmpty);
      expect(channels.cancels, 1);
      expect(service.isChecking, isFalse);
    },
  );

  test(
    'low lux cue is conservative and not a rear camera brightness claim',
    () async {
      final result = await sample(lux: 2, covered: true);
      expect(result.guidance, 'Ambient light is low. More light may help.');
    },
  );

  test(
    'proximity cue refers only to front/top, never object distance',
    () async {
      final result = await sample(covered: true);
      expect(
        result.guidance,
        'The front proximity sensor reports covered. Check the top/front of the phone.',
      );
      expect(result.highAngularMotion, isFalse);
    },
  );

  test('no cue is not a quality or safety assurance', () async {
    final result = await sample();
    expect(result.status, DeviceSensorStatus.completed);
    expect(result.guidance, isNull);
  });

  test('native stale samples cannot guide', () async {
    final pending = service.check();
    await channels.listening.future;
    await channels.emit('gyroscope', values: [3, 0, 0], ageMillis: 2000);
    await channels.end();
    final result = await pending;
    expect(result.status, DeviceSensorStatus.stale);
    expect(result.staleSensors, {DeviceSensor.gyroscope});
    expect(result.measurements, isEmpty);
    expect(result.guidance, isNull);
  });

  test(
    'freshness is checked again with the injected clock at completion',
    () async {
      final pending = service.check();
      await channels.listening.future;
      await channels.emit('light', values: [1]);
      now = now.add(const Duration(seconds: 2));
      await channels.end();
      final result = await pending;
      expect(result.status, DeviceSensorStatus.stale);
      expect(result.lowLight, isFalse);
    },
  );

  test(
    'pose uses fixed device gravity axes, not display or page rotation',
    () async {
      final pending = service.check();
      await channels.listening.future;
      await channels.emit('gravity', values: [0, 9.81, 0]);
      await channels.end();
      final result = await pending;
      expect(result.pose, DevicePose.topEdgeUp);
      expect(result.guidance, isNull);
      expect(result.measurements[DeviceSensor.gravity]!.values, [0, 9.81, 0]);
    },
  );

  test(
    'accelerometer fallback rejects non-gravity-like acceleration',
    () async {
      final pending = service.check();
      await channels.listening.future;
      await channels.emit('accelerometer', values: [0, 20, 0]);
      await channels.end();
      expect((await pending).pose, DevicePose.unknown);
    },
  );

  test('high angular motion makes pose unknown', () async {
    final pending = service.check();
    await channels.listening.future;
    await channels.emit('gravity', values: [0, 0, 9.81]);
    await channels.emit('gyroscope', values: [1, 1, 0]);
    await channels.end();
    expect((await pending).pose, DevicePose.unknown);
  });

  test('registration failures are exposed and stop the subscription', () async {
    final pending = service.check();
    await channels.listening.future;
    await channels.send({
      'session': channels.session,
      'sensors': {
        for (final sensor in DeviceSensor.values) sensor.name: 'unavailable',
      },
    });
    final result = await pending;
    expect(result.status, DeviceSensorStatus.unavailable);
    expect(
      result.capabilities.sensors.values,
      everyElement(SensorAvailability.unavailable),
    );
    expect(channels.cancels, 1);
  });

  test(
    'invalid, unknown-session, future, and nonfinite samples are ignored',
    () async {
      final pending = service.check();
      await channels.listening.future;
      await channels.emit('gyroscope', values: [3, 0, 0], eventSession: -1);
      await channels.emit('light', values: [-1]);
      await channels.emit('gravity', values: [double.nan, 0, 0]);
      await channels.emit('light', values: [1], ageMillis: -1);
      await channels.emit('unknown', values: [1]);
      await channels.end();
      final result = await pending;
      expect(result.measurements, isEmpty);
      expect(result.guidance, isNull);
    },
  );

  test('cancellation silences fresh samples and cleans up once', () async {
    final pending = service.check();
    await channels.listening.future;
    await channels.emit('light', values: [1]);
    await service.stop();
    final result = await pending;
    expect(result.status, DeviceSensorStatus.cancelled);
    expect(result.guidance, isNull);
    expect(channels.cancels, 1);
    await channels.emit('light', values: [1]);
    await service.stop();
    expect(channels.cancels, 1);
  });

  test(
    'cancellation during capability discovery never subscribes late',
    () async {
      channels.capabilityGate = Completer<void>();
      final pending = service.check();
      await channels.queried.future;
      await service.stop();
      expect((await pending).status, DeviceSensorStatus.cancelled);
      channels.capabilityGate!.complete();
      await pumpEventQueue();
      expect(channels.listens, 0);
    },
  );

  test('lifecycle stop is silent and never restarts automatically', () async {
    final pending = service.check();
    await channels.listening.future;
    service.didChangeAppLifecycleState(AppLifecycleState.inactive);
    expect((await pending).status, DeviceSensorStatus.cancelled);
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(channels.listens, 1);
    expect(channels.cancels, 1);
  });

  test(
    'stream errors release listeners and do not use preceding samples',
    () async {
      final pending = service.check();
      await channels.listening.future;
      await channels.emit('light', values: [1]);
      final sent = Completer<void>();
      channels.messenger.handlePlatformMessage(
        SensorChannels.events.name,
        SensorChannels.codec.encodeErrorEnvelope(code: 'unavailable'),
        (_) => sent.complete(),
      );
      await sent.future;
      final result = await pending;
      expect(result.status, DeviceSensorStatus.unavailable);
      expect(result.guidance, isNull);
      expect(channels.cancels, 1);
    },
  );

  test(
    'timeout and failed cancellation acknowledgement remain bounded',
    () async {
      channels.cancelGate = Completer<void>();
      final pending = service.check(timeout: const Duration(milliseconds: 20));
      await channels.listening.future;
      final result = await pending.timeout(const Duration(seconds: 1));
      expect(result.status, DeviceSensorStatus.unavailable);
      expect(channels.cancels, 1);
      channels.cancelGate!.complete();
    },
  );

  test(
    'a stalled capability channel respects the whole check budget',
    () async {
      channels.capabilityGate = Completer<void>();
      final result = await service
          .check(timeout: const Duration(milliseconds: 20))
          .timeout(const Duration(seconds: 1));
      expect(result.guidance, isNull);
      channels.capabilityGate!.complete();
      await pumpEventQueue();
      expect(channels.listens, 0);
    },
  );

  test(
    'checks never reuse prior samples or open overlapping subscriptions',
    () async {
      await sample(lux: 1);
      final next = service.check(timeout: const Duration(milliseconds: 20));
      final overlapping = await service.check();
      expect(overlapping.status, DeviceSensorStatus.unavailable);
      final result = await next;
      expect(result.measurements, isEmpty);
      expect(result.guidance, isNull);
      expect(channels.listens, 2);
      expect(channels.cancels, 2);
    },
  );

  test(
    'dispose stops active check and forbids further subscriptions',
    () async {
      final pending = service.check();
      await channels.listening.future;
      await service.dispose();
      expect((await pending).status, DeviceSensorStatus.cancelled);
      expect((await service.check()).status, DeviceSensorStatus.cancelled);
      expect(channels.listens, 1);
      expect(channels.cancels, 1);
    },
  );
}
