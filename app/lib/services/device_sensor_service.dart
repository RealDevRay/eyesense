import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Android device sensors, not camera/object-distance or navigation sensors.
enum DeviceSensor { accelerometer, gravity, gyroscope, light, proximity }

enum SensorAvailability { available, missing, unavailable }

enum DeviceSensorStatus {
  unsupported,
  unavailable,
  completed,
  stale,
  cancelled,
}

/// Pose in Android's fixed device axes, NOT the current display rotation.
/// No heading, subject alignment, or page orientation can be inferred.
enum DevicePose {
  unknown,
  faceUp,
  faceDown,
  topEdgeUp,
  topEdgeDown,
  sideEdgeUp,
}

class SensorCapabilities {
  SensorCapabilities({
    required this.supported,
    required Map<DeviceSensor, SensorAvailability> sensors,
  }) : sensors = Map.unmodifiable(sensors);

  factory SensorCapabilities.unsupported() => SensorCapabilities(
    supported: false,
    sensors: {
      for (final sensor in DeviceSensor.values)
        sensor: SensorAvailability.unavailable,
    },
  );

  final bool supported;
  final Map<DeviceSensor, SensorAvailability> sensors;
  bool get hasSensors => sensors.values.contains(SensorAvailability.available);

  static SensorCapabilities _decode(Object? value) {
    if (value is! Map || value['sensors'] is! Map) {
      return SensorCapabilities.unsupported();
    }
    final states = value['sensors'] as Map;
    return SensorCapabilities(
      supported: true,
      sensors: {
        for (final sensor in DeviceSensor.values)
          sensor: switch (states[sensor.name]) {
            'available' => SensorAvailability.available,
            'missing' => SensorAvailability.missing,
            _ => SensorAvailability.unavailable,
          },
      },
    );
  }
}

class SensorMeasurement {
  SensorMeasurement({
    required this.sensor,
    required this.sampledAt,
    List<double> values = const [],
    this.frontSensorCovered,
  }) : values = List.unmodifiable(values);

  final DeviceSensor sensor;
  final DateTime sampledAt;

  /// Acceleration/gravity: m/s² in Android device axes; gyro: rad/s;
  /// light: lux. Proximity deliberately exposes NO numeric distance.
  final List<double> values;
  final bool? frontSensorCovered;

  double get magnitude =>
      math.sqrt(values.fold<double>(0, (sum, value) => sum + value * value));
}

class DeviceSensorAssessment {
  DeviceSensorAssessment({
    required this.status,
    required this.capabilities,
    Map<DeviceSensor, SensorMeasurement> measurements = const {},
    Set<DeviceSensor> staleSensors = const {},
    this.pose = DevicePose.unknown,
    this.highAngularMotion = false,
    this.lowLight = false,
    this.frontSensorCovered = false,
  }) : measurements = Map.unmodifiable(measurements),
       staleSensors = Set.unmodifiable(staleSensors);

  final DeviceSensorStatus status;
  final SensorCapabilities capabilities;

  /// Fresh samples only, at the time this assessment was returned.
  final Map<DeviceSensor, SensorMeasurement> measurements;
  final Set<DeviceSensor> staleSensors;

  /// Coarse gravity-relative estimate, not display rotation or subject tilt.
  /// Accelerometer-only fallback is approximate (it includes linear motion).
  /// The measurement map identifies whether gravity or acceleration was used.
  final DevicePose pose;
  final bool highAngularMotion;
  final bool lowLight;
  final bool frontSensorCovered;

  /// At most one prioritized cue. Absence of a cue is NOT a safety/quality claim.
  String? get guidance {
    if (status != DeviceSensorStatus.completed) return null;
    if (highAngularMotion) return 'Hold the phone steady.';
    if (lowLight) return 'Ambient light is low. More light may help.';
    if (frontSensorCovered) {
      return 'The front proximity sensor reports covered. Check the top/front of the phone.';
    }
    return null;
  }
}

class _SensorCheck {
  _SensorCheck(this.id);
  final int id;
  final done = Completer<void>();
  final samples = <DeviceSensor, SensorMeasurement>{};
  SensorCapabilities capabilities = SensorCapabilities.unsupported();
  DeviceSensorStatus? status;
  StreamSubscription<dynamic>? subscription;
  Timer? timer;

  void finish([DeviceSensorStatus? reason]) {
    // Cancellation also silences a result already awaiting channel cleanup.
    if (reason == DeviceSensorStatus.cancelled) status = reason;
    if (done.isCompleted) return;
    status = reason;
    done.complete();
  }
}

/// Optional, local-only bounded foreground checks. Construction and capability
/// discovery do not subscribe. No permissions, location, speech, or network use.
///
/// [check] owns the event subscription and always releases it. [stop] cancels an
/// active check; [dispose] also permanently disables future checks. Channels and
/// clock are injectable for tests. CameraService keeps this reusable after its
/// own dispose (which can mean backgrounding), by calling [stop], not [dispose].
class DeviceSensorService with WidgetsBindingObserver {
  DeviceSensorService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    DateTime Function()? clock,
  }) : _methods = methodChannel ?? const MethodChannel('eyesense/sensors'),
       _events = eventChannel ?? const EventChannel('eyesense/sensors/events'),
       _clock = clock ?? DateTime.now;

  final MethodChannel _methods;
  final EventChannel _events;
  final DateTime Function() _clock;
  static const maxSampleAge = Duration(seconds: 1);
  static const _cleanupBudget = Duration(milliseconds: 100);
  _SensorCheck? _active;
  Future<void>? _pendingCheck;
  int _nextId = 0;
  bool _disposed = false;
  bool get isChecking => _active != null;

  /// Hardware presence only; registration failures are reflected in the
  /// assessment's capabilities. This never starts sampling.
  Future<SensorCapabilities> getCapabilities() async {
    if (_disposed) return SensorCapabilities.unsupported();
    try {
      return SensorCapabilities._decode(
        await _methods
            .invokeMethod<Object?>('capabilities')
            .timeout(const Duration(milliseconds: 200)),
      );
    } catch (_) {
      return SensorCapabilities.unsupported();
    }
  }

  /// An explicit user-initiated check. Maximum sampling budget is 800 ms plus
  /// at most 100 ms awaiting channel cleanup. Concurrent checks are not started.
  /// Cancellation/lifecycle changes return a silent cancelled assessment.
  Future<DeviceSensorAssessment> check({
    Duration timeout = const Duration(milliseconds: 700),
  }) async {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (_disposed ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      return DeviceSensorAssessment(
        status: DeviceSensorStatus.cancelled,
        capabilities: SensorCapabilities.unsupported(),
      );
    }
    if (_active != null) {
      return DeviceSensorAssessment(
        status: DeviceSensorStatus.unavailable,
        capabilities: SensorCapabilities.unsupported(),
      );
    }
    final check = _SensorCheck(++_nextId);
    _active = check;
    WidgetsBinding.instance.addObserver(this);
    final budget = Duration(
      microseconds: timeout.inMicroseconds.clamp(0, 800000),
    );
    check.timer = Timer(budget, check.finish);
    final result = _collect(check);
    _pendingCheck = result.then<void>((_) {});
    unawaited(_start(check));
    return result;
  }

  Future<void> _start(_SensorCheck check) async {
    try {
      final capabilities = await getCapabilities();
      if (check.done.isCompleted) return;
      check.capabilities = capabilities;
      if (!capabilities.supported || !capabilities.hasSensors) {
        check.finish(
          capabilities.supported
              ? DeviceSensorStatus.unavailable
              : DeviceSensorStatus.unsupported,
        );
        return;
      }
      check.subscription = _events
          .receiveBroadcastStream({'session': check.id})
          .listen(
            (Object? event) => _onEvent(check, event),
            onError: (Object error) {
              check.finish(
                error is PlatformException && error.code == 'paused'
                    ? DeviceSensorStatus.cancelled
                    : DeviceSensorStatus.unavailable,
              );
            },
            onDone: check.finish,
          );
    } catch (_) {
      check.finish(DeviceSensorStatus.unavailable);
    }
  }

  void _onEvent(_SensorCheck check, Object? event) {
    if (check.done.isCompleted ||
        event is! Map ||
        event['session'] != check.id) {
      return;
    }
    if (event['sensors'] is Map) {
      check.capabilities = SensorCapabilities._decode(event);
      if (!check.capabilities.hasSensors) {
        check.finish(DeviceSensorStatus.unavailable);
      }
      return;
    }
    final sensor = DeviceSensor.values
        .where((sensor) => sensor.name == event['sensor'])
        .firstOrNull;
    final age = event['ageMillis'];
    if (sensor == null ||
        age is! num ||
        !age.isFinite ||
        age < 0 ||
        age > 60000 ||
        check.capabilities.sensors[sensor] != SensorAvailability.available) {
      return;
    }
    final values = event['values'];
    if (sensor != DeviceSensor.proximity &&
        (values is! List || values.any((value) => value is! num))) {
      return;
    }
    final numbers = values is List
        ? values.whereType<num>().map((value) => value.toDouble()).toList()
        : <double>[];
    final expected = sensor == DeviceSensor.proximity
        ? 0
        : sensor == DeviceSensor.light
        ? 1
        : 3;
    if (numbers.length != expected ||
        numbers.any((value) => !value.isFinite) ||
        (sensor == DeviceSensor.light && numbers.first < 0) ||
        (sensor == DeviceSensor.proximity && event['covered'] is! bool)) {
      return;
    }
    final sampledAt = _clock().subtract(
      Duration(microseconds: (age * 1000).round()),
    );
    final previous = check.samples[sensor];
    if (previous != null && sampledAt.isBefore(previous.sampledAt)) return;
    check.samples[sensor] = SensorMeasurement(
      sensor: sensor,
      sampledAt: sampledAt,
      values: numbers,
      frontSensorCovered: sensor == DeviceSensor.proximity
          ? event['covered'] as bool
          : null,
    );
  }

  Future<DeviceSensorAssessment> _collect(_SensorCheck check) async {
    await check.done.future;
    check.timer?.cancel();
    // Remove the listener even when the platform never acknowledges cancellation.
    // Native code independently unregisters on pause/detach and a 900 ms watchdog.
    try {
      await check.subscription?.cancel().timeout(_cleanupBudget);
    } catch (_) {}
    if (identical(_active, check)) {
      _active = null;
      _pendingCheck = null;
      WidgetsBinding.instance.removeObserver(this);
    }
    final now = _clock();
    final fresh = <DeviceSensor, SensorMeasurement>{};
    final stale = <DeviceSensor>{};
    for (final entry in check.samples.entries) {
      final age = now.difference(entry.value.sampledAt);
      if (age.isNegative || age > maxSampleAge) {
        stale.add(entry.key);
      } else {
        fresh[entry.key] = entry.value;
      }
    }
    final status =
        check.status ??
        (fresh.isNotEmpty
            ? DeviceSensorStatus.completed
            : stale.isNotEmpty
            ? DeviceSensorStatus.stale
            : DeviceSensorStatus.unavailable);
    final usable = status == DeviceSensorStatus.completed;
    final moving =
        usable && (fresh[DeviceSensor.gyroscope]?.magnitude ?? 0) >= 0.8;
    final gravity =
        fresh[DeviceSensor.gravity] ?? fresh[DeviceSensor.accelerometer];
    return DeviceSensorAssessment(
      status: status,
      capabilities: check.capabilities,
      measurements: fresh,
      staleSensors: stale,
      highAngularMotion: moving,
      lowLight:
          usable &&
          fresh[DeviceSensor.light] != null &&
          fresh[DeviceSensor.light]!.values.first < 15,
      frontSensorCovered:
          usable && fresh[DeviceSensor.proximity]?.frontSensorCovered == true,
      pose: usable && !moving ? _pose(gravity) : DevicePose.unknown,
    );
  }

  DevicePose _pose(SensorMeasurement? sample) {
    // Accelerometer fallback includes linear acceleration: only approximate pose
    // when total acceleration is gravity-like; never emit a positioning cue.
    if (sample == null || sample.magnitude < 8.5 || sample.magnitude > 11) {
      return DevicePose.unknown;
    }
    final axes = sample.values
        .map((value) => value / sample.magnitude)
        .toList();
    if (axes[2] > 0.9) return DevicePose.faceUp;
    if (axes[2] < -0.9) return DevicePose.faceDown;
    if (axes[1] > 0.9) return DevicePose.topEdgeUp;
    if (axes[1] < -0.9) return DevicePose.topEdgeDown;
    if (axes[0].abs() > 0.9) return DevicePose.sideEdgeUp;
    return DevicePose.unknown;
  }

  Future<void> stop() {
    _active?.finish(DeviceSensorStatus.cancelled);
    return _pendingCheck ?? Future<void>.value();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(stop());
  }

  Future<void> dispose() {
    _disposed = true;
    return stop();
  }
}
