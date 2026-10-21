import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
// Exercise the camera plugin through its existing transitive platform interface.
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart'
    as platform;
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:eyesense/services/camera_service.dart';
import 'package:eyesense/services/device_sensor_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

class FakeCameraPlatform extends platform.CameraPlatform {
  FakeCameraPlatform(this.stillFile) {
    frames = StreamController<platform.CameraImageData>(
      sync: true,
      onListen: () => streamStarted.complete(),
      onCancel: () async {
        events.add('stream:stop');
        streamStopCalls++;
        streamStopping.complete();
        await streamStopGate?.future;
      },
    );
  }

  final File stillFile;
  final presets = <ResolutionPreset>[];
  final disposed = <int>[];
  final events = <String>[];
  final _initialized = <int, Completer<platform.CameraInitializedEvent>>{};
  final initializationStarted = Completer<void>();
  final discoveryStarted = Completer<void>();
  final streamStarted = Completer<void>();
  final streamStopping = Completer<void>();
  final pictureStarted = Completer<void>();
  late final StreamController<platform.CameraImageData> frames;
  Completer<void>? initializationGate;
  Completer<void>? discoveryGate;
  Completer<void>? streamStopGate;
  Completer<void>? pictureGate;
  bool failInitialization = false;
  bool failGuidance = false;
  int pictureCalls = 0;
  int streamStopCalls = 0;

  @override
  Future<List<CameraDescription>> availableCameras() async {
    if (!discoveryStarted.isCompleted) discoveryStarted.complete();
    await discoveryGate?.future;
    return const [
      CameraDescription(
        name: 'rear',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
    ];
  }

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    platform.MediaSettings mediaSettings,
  ) async {
    final id = presets.length;
    presets.add(mediaSettings.resolutionPreset!);
    events.add('create:$id');
    _initialized[id] = Completer<platform.CameraInitializedEvent>();
    return id;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    if (!initializationStarted.isCompleted) initializationStarted.complete();
    await initializationGate?.future;
    _initialized[cameraId]!.complete(
      platform.CameraInitializedEvent(
        cameraId,
        640,
        480,
        ExposureMode.auto,
        true,
        FocusMode.auto,
        true,
      ),
    );
    if (failInitialization) {
      throw PlatformException(code: 'test-initialization-failure');
    }
  }

  @override
  Stream<platform.CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.fromFuture(_initialized[cameraId]!.future);

  @override
  Stream<platform.CameraErrorEvent> onCameraError(int cameraId) =>
      Stream<platform.CameraErrorEvent>.multi((_) {});

  @override
  Stream<platform.DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();

  @override
  bool supportsImageStreaming() => true;

  @override
  Stream<platform.CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    platform.CameraImageStreamOptions? options,
  }) {
    if (failGuidance) {
      throw CameraException('test-stream-failure', 'Unavailable');
    }
    return frames.stream;
  }

  @override
  Future<XFile> takePicture(int cameraId) async {
    pictureCalls++;
    if (!pictureStarted.isCompleted) pictureStarted.complete();
    await pictureGate?.future;
    return XFile(stillFile.path);
  }

  @override
  Future<void> dispose(int cameraId) async {
    events.add('dispose:$cameraId');
    disposed.add(cameraId);
  }

  void emitFrame({bool detailed = false}) {
    final bytes = Uint8List(64 * 64);
    if (detailed) {
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          bytes[y * 64 + x] = (x ~/ 4).isEven ? 64 : 192;
        }
      }
    }
    frames.add(
      platform.CameraImageData(
        format: const platform.CameraImageFormat(
          ImageFormatGroup.yuv420,
          raw: 35,
        ),
        planes: [platform.CameraImagePlane(bytes: bytes, bytesPerRow: 64)],
        width: 64,
        height: 64,
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  late platform.CameraPlatform originalPlatform;
  late FakeCameraPlatform fake;
  late CameraService service;
  late Directory directory;
  late Completer<void> permissionStarted;
  Completer<void>? permissionGate;
  const sensors = MethodChannel('eyesense/sensors');
  const sensorEvents = MethodChannel('eyesense/sensors/events');
  late Completer<void> sensorsStarted;
  late Completer<void> sensorsQueried;
  Completer<void>? sensorCapabilityGate;
  var sensorQueries = 0;
  var sensorListens = 0;
  var sensorCancels = 0;
  int? sensorSession;
  var sensorsAvailable = false;

  Future<void> emitSensor(Object? event, {bool end = false}) async {
    final done = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          sensorEvents.name,
          end ? null : const StandardMethodCodec().encodeSuccessEnvelope(event),
          (_) => done.complete(),
        );
    await done.future;
  }

  final cancelled = throwsA(
    isA<AppException>().having(
      (error) => error.code,
      'code',
      ErrorCode.operationCancelled,
    ),
  );

  setUp(() async {
    permissionGate = null;
    sensorCapabilityGate = null;
    sensorsAvailable = false;
    sensorQueries = 0;
    sensorListens = 0;
    sensorCancels = 0;
    sensorSession = null;
    sensorsStarted = Completer<void>();
    sensorsQueried = Completer<void>();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(sensors, (call) async {
      sensorQueries++;
      if (!sensorsQueried.isCompleted) sensorsQueried.complete();
      await sensorCapabilityGate?.future;
      return {
        'sensors': {
          for (final sensor in DeviceSensor.values)
            sensor.name: sensorsAvailable ? 'available' : 'missing',
        },
      };
    });
    messenger.setMockMethodCallHandler(sensorEvents, (call) async {
      if (call.method == 'listen') {
        sensorListens++;
        sensorSession = (call.arguments as Map)['session'] as int;
        if (!sensorsStarted.isCompleted) sensorsStarted.complete();
      } else if (call.method == 'cancel') {
        sensorCancels++;
      }
      return null;
    });
    permissionStarted = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, (call) async {
          if (call.method != 'checkPermissionStatus') {
            throw StateError('Unexpected permission call: ${call.method}');
          }
          if (!permissionStarted.isCompleted) permissionStarted.complete();
          await permissionGate?.future;
          return 1; // Granted.
        });
    directory = await Directory.systemTemp.createTemp('eyesense_camera_test_');
    final file = File('${directory.path}/CAP123.jpg');
    await file.writeAsBytes(img.encodeJpg(img.Image(width: 8, height: 8)));
    originalPlatform = platform.CameraPlatform.instance;
    fake = FakeCameraPlatform(file);
    platform.CameraPlatform.instance = fake;
    service = CameraService();
  });

  tearDown(() async {
    await service.dispose();
    platform.CameraPlatform.instance = originalPlatform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sensors, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sensorEvents, null);
    await directory.delete(recursive: true);
  });

  test(
    'same-preset initialization shares a future and waits until ready',
    () async {
      fake.initializationGate = Completer<void>();
      final first = service.initialize();
      final second = service.initialize();
      expect(identical(first, second), isTrue);
      var completed = false;
      unawaited(second.then((_) => completed = true));
      await fake.initializationStarted.future;
      expect(completed, isFalse);
      expect(service.controller, isNull);
      expect(fake.presets, [ResolutionPreset.medium]);

      fake.initializationGate!.complete();
      await Future.wait([first, second]);
      expect(service.isInitialized, isTrue);
      expect(fake.presets, hasLength(1));
    },
  );

  test('different-preset initialization is serialized', () async {
    fake.initializationGate = Completer<void>();
    final high = service.initialize(preset: ResolutionPreset.high);
    await fake.initializationStarted.future;
    final medium = service.initialize();
    await pumpEventQueue();
    expect(fake.presets, [ResolutionPreset.high]);

    fake.initializationGate!.complete();
    await Future.wait([high, medium]);
    expect(fake.presets, [ResolutionPreset.high, ResolutionPreset.medium]);
    expect(fake.events, ['create:0', 'dispose:0', 'create:1']);
    expect(service.controller!.resolutionPreset, ResolutionPreset.medium);
  });

  test(
    'OCR and cloud enforce their presets even when already initialized',
    () async {
      await service.initialize();
      await service.captureForOcr();
      expect(service.controller!.resolutionPreset, ResolutionPreset.high);
      final compressed = await service.captureAndCompress();
      expect(service.controller!.resolutionPreset, ResolutionPreset.medium);
      expect(compressed.byteSize, greaterThan(0));
      expect(fake.presets, [
        ResolutionPreset.medium,
        ResolutionPreset.high,
        ResolutionPreset.medium,
      ]);
      expect(fake.pictureCalls, 2);
    },
  );

  test(
    'dispose during permission checking invalidates pending initialization',
    () async {
      permissionGate = Completer<void>();
      final initialization = service.initialize();
      final result = expectLater(initialization, cancelled);
      await permissionStarted.future;
      await service.dispose();
      permissionGate!.complete();
      await result;
      expect(service.controller, isNull);
      expect(fake.presets, isEmpty);
    },
  );

  test(
    'dispose during discovery prevents a late controller from being created',
    () async {
      fake.discoveryGate = Completer<void>();
      final initialization = service.initialize();
      final result = expectLater(initialization, cancelled);
      await fake.discoveryStarted.future;
      await service.dispose();
      fake.discoveryGate!.complete();
      await result;
      expect(service.isInitialized, isFalse);
      expect(fake.presets, isEmpty);
    },
  );

  test('dispose releases a pending controller without publishing it', () async {
    fake.initializationGate = Completer<void>();
    final initialization = service.initialize();
    final result = expectLater(initialization, cancelled);
    await fake.initializationStarted.future;
    final disposal = service.dispose();
    expect(service.controller, isNull);
    fake.initializationGate!.complete();
    await Future.wait([disposal, result]);
    expect(service.controller, isNull);
    expect(fake.disposed, [0]);
  });

  test(
    'a fresh initialization after dispose waits for stale work and disposal',
    () async {
      fake.initializationGate = Completer<void>();
      final initialization = service.initialize();
      final stale = expectLater(initialization, cancelled);
      await fake.initializationStarted.future;
      final disposal = service.dispose();
      final fresh = service.initialize();
      fake.initializationGate!.complete();
      await Future.wait([stale, disposal, fresh]);
      expect(service.isInitialized, isTrue);
      expect(fake.events, ['create:0', 'dispose:0', 'create:1']);
    },
  );

  test(
    'a failed initialization disposes its candidate and can be retried',
    () async {
      fake.failInitialization = true;
      await expectLater(service.initialize(), throwsA(isA<AppException>()));
      expect(service.controller, isNull);
      expect(fake.disposed, [0]);
      fake.failInitialization = false;
      await service.initialize();
      expect(service.isInitialized, isTrue);
      expect(fake.presets, hasLength(2));
    },
  );

  for (final ocr in [true, false]) {
    test(
      'cancel during ${ocr ? 'OCR' : 'cloud'} initialization prevents a still',
      () async {
        fake.initializationGate = Completer<void>();
        final capture = ocr
            ? service.captureForOcr()
            : service.captureAndCompress();
        final result = expectLater(capture, cancelled);
        await fake.initializationStarted.future;
        await service.cancelPendingCapture();
        fake.initializationGate!.complete();
        await result;
        expect(fake.pictureCalls, 0);
      },
    );

    test(
      'cancel discards and deletes an already-issued ${ocr ? 'OCR' : 'cloud'} still',
      () async {
        fake.pictureGate = Completer<void>();
        final capture = ocr
            ? service.captureForOcr()
            : service.captureAndCompress();
        final result = expectLater(capture, cancelled);
        await fake.pictureStarted.future;
        await service.cancelPendingCapture();
        fake.pictureGate!.complete();
        await result;
        expect(fake.pictureCalls, 1);
        expect(await fake.stillFile.exists(), isFalse);
      },
    );
  }

  test(
    'cancel stops guidance, suppresses callbacks, and never takes a still',
    () async {
      final phrases = <String>[];
      final capture = service.captureForOcr(onGuidance: phrases.add);
      final result = expectLater(capture, cancelled);
      await fake.streamStarted.future;
      fake.emitFrame();
      expect(phrases, hasLength(1));

      final stopping = service.cancelPendingCapture();
      fake.emitFrame();
      await stopping;
      await result;
      expect(phrases, hasLength(1));
      expect(fake.streamStopCalls, 1);
      expect(fake.pictureCalls, 0);
      expect(service.controller!.value.isStreamingImages, isFalse);

      await service.cancelPendingCapture();
      await service.cancelPendingCapture();
      await service.captureForOcr();
      expect(fake.pictureCalls, 1);
    },
  );

  test(
    'cancel after stable guidance but before stream shutdown prevents a still',
    () async {
      fake.streamStopGate = Completer<void>();
      final capture = service.captureForOcr(onGuidance: (_) {});
      final result = expectLater(capture, cancelled);
      await fake.streamStarted.future;
      for (var i = 0; i < 3; i++) {
        fake.emitFrame(detailed: true);
      }
      await fake.streamStopping.future;
      expect(fake.pictureCalls, 0);
      final stopping = service.cancelPendingCapture();
      fake.streamStopGate!.complete();
      await stopping;
      await result;
      expect(fake.pictureCalls, 0);
    },
  );

  test('cancellation from a guidance callback is safe', () async {
    final capture = service.captureForOcr(
      onGuidance: (_) {
        unawaited(service.cancelPendingCapture());
      },
    );
    final result = expectLater(capture, cancelled);
    await fake.streamStarted.future;
    fake.emitFrame();
    await result;
    expect(fake.streamStopCalls, 1);
    expect(fake.pictureCalls, 0);
  });

  test('dispose cancels guidance before releasing the controller', () async {
    final capture = service.captureForOcr(onGuidance: (_) {});
    final result = expectLater(capture, cancelled);
    await fake.streamStarted.future;
    await service.dispose();
    await result;
    expect(fake.events, ['create:0', 'stream:stop', 'dispose:0']);
    expect(service.controller, isNull);
    expect(fake.pictureCalls, 0);
  });

  test(
    'optional guidance failure still permits an uncancelled capture',
    () async {
      fake.failGuidance = true;
      final capture = await service.captureForOcr(onGuidance: (_) {});
      expect(capture.file.path, fake.stillFile.path);
      expect(fake.pictureCalls, 1);
    },
  );

  test('captures without a callback never query or wait for sensors', () async {
    sensorsAvailable = true;
    sensorCapabilityGate = Completer<void>();
    await service.captureForOcr();
    await service.captureAndCompress();
    expect(sensorQueries, 0);
    expect(sensorListens, 0);
    expect(fake.pictureCalls, 2);
  });

  test(
    'disabled sensor guidance skips sensors but cloud capture still works',
    () async {
      sensorsAvailable = true;
      service.sensorGuidanceEnabled = false;
      final phrases = <String>[];
      await service.captureAndCompress(onGuidance: phrases.add);
      expect(sensorQueries, 0);
      expect(phrases, isEmpty);
      expect(fake.pictureCalls, 1);
    },
  );

  test('frame guidance only emits once even without sensor guidance', () async {
    final phrases = <String>[];
    final capture = service.captureForOcr(onGuidance: phrases.add);
    await fake.streamStarted.future;
    for (var i = 0; i < 5; i++) {
      fake.emitFrame();
    }
    expect(phrases, hasLength(1));
    for (var i = 0; i < 3; i++) {
      fake.emitFrame(detailed: true);
    }
    await capture;
    expect(phrases, hasLength(1));
    expect(fake.streamStopCalls, 1);
  });

  test(
    'frame callback failure stops optional guidance and permits capture',
    () async {
      final capture = service.captureForOcr(
        onGuidance: (_) => throw StateError('Speech unavailable'),
      );
      await fake.streamStarted.future;
      fake.emitFrame();
      await capture;
      expect(fake.streamStopCalls, 1);
      expect(fake.pictureCalls, 1);
    },
  );

  test('stale sensor samples cannot cue or prevent cloud capture', () async {
    sensorsAvailable = true;
    final phrases = <String>[];
    final capture = service.captureAndCompress(onGuidance: phrases.add);
    await sensorsStarted.future;
    await emitSensor({
      'session': sensorSession,
      'sensor': 'gyroscope',
      'values': [3.0, 0.0, 0.0],
      'ageMillis': 2000,
    });
    await emitSensor(null, end: true);
    await capture;
    expect(phrases, isEmpty);
    expect(sensorCancels, 1);
    expect(fake.pictureCalls, 1);
  });

  test('missing sensors permit cloud capture without a cue', () async {
    final phrases = <String>[];
    await service.captureAndCompress(onGuidance: phrases.add);
    expect(sensorQueries, 1);
    expect(sensorListens, 0);
    expect(phrases, isEmpty);
    expect(fake.pictureCalls, 1);
  });

  test(
    'cloud sensor guidance is prioritized, once, and released before capture',
    () async {
      sensorsAvailable = true;
      final phrases = <String>[];
      final capture = service.captureAndCompress(onGuidance: phrases.add);
      await sensorsStarted.future;
      expect(fake.pictureCalls, 0);
      for (var i = 0; i < 3; i++) {
        await emitSensor({
          'session': sensorSession,
          'sensor': 'gyroscope',
          'values': [2.0, 0.0, 0.0],
          'ageMillis': 0,
        });
        await emitSensor({
          'session': sensorSession,
          'sensor': 'light',
          'values': [1.0],
          'ageMillis': 0,
        });
      }
      await emitSensor(null, end: true);
      await capture;
      expect(phrases, ['Hold the phone steady.']);
      expect(sensorCancels, 1);
      expect(service.sensorService.isChecking, isFalse);
      expect(fake.pictureCalls, 1);
    },
  );

  test(
    'Stop releases the sensor-cue adjustment pause before the still',
    () async {
      sensorsAvailable = true;
      final cueDelivered = Completer<void>();
      final capture = service.captureAndCompress(
        onGuidance: (_) => cueDelivered.complete(),
      );
      final cancelledCapture = expectLater(capture, cancelled);
      await sensorsStarted.future;
      await emitSensor({
        'session': sensorSession,
        'sensor': 'gyroscope',
        'values': [2.0, 0.0, 0.0],
        'ageMillis': 0,
      });
      await emitSensor(null, end: true);
      await cueDelivered.future;
      expect(fake.pictureCalls, 0);
      await service.cancelPendingCapture();
      await cancelledCapture;
      expect(fake.pictureCalls, 0);
      expect(sensorCancels, 1);
    },
  );

  test('sensor and frame guidance share one OCR cue budget', () async {
    sensorsAvailable = true;
    final phrases = <String>[];
    final capture = service.captureForOcr(onGuidance: phrases.add);
    await sensorsStarted.future;
    await emitSensor({
      'session': sensorSession,
      'sensor': 'light',
      'values': [1.0],
      'ageMillis': 0,
    });
    await emitSensor(null, end: true);
    await fake.streamStarted.future;
    fake.emitFrame();
    fake.emitFrame();
    expect(phrases, ['Ambient light is low. More light may help.']);
    for (var i = 0; i < 3; i++) {
      fake.emitFrame(detailed: true);
    }
    await capture;
    expect(phrases, hasLength(1));
    expect(sensorCancels, 1);
  });

  for (final ocr in [true, false]) {
    test(
      'cancel during ${ocr ? 'OCR' : 'cloud'} sensor guidance suppresses still and cue',
      () async {
        sensorsAvailable = true;
        final phrases = <String>[];
        final capture = ocr
            ? service.captureForOcr(onGuidance: phrases.add)
            : service.captureAndCompress(onGuidance: phrases.add);
        final result = expectLater(capture, cancelled);
        await sensorsStarted.future;
        await emitSensor({
          'session': sensorSession,
          'sensor': 'light',
          'values': [1.0],
          'ageMillis': 0,
        });
        await service.cancelPendingCapture();
        await result;
        expect(fake.pictureCalls, 0);
        expect(phrases, isEmpty);
        expect(sensorCancels, 1);
        await service.captureAndCompress();
        expect(fake.pictureCalls, 1);
      },
    );
  }

  test('cancellation from a sensor callback prevents the still', () async {
    sensorsAvailable = true;
    final capture = service.captureAndCompress(
      onGuidance: (_) => unawaited(service.cancelPendingCapture()),
    );
    final result = expectLater(capture, cancelled);
    await sensorsStarted.future;
    await emitSensor({
      'session': sensorSession,
      'sensor': 'light',
      'values': [1.0],
      'ageMillis': 0,
    });
    await emitSensor(null, end: true);
    await result;
    expect(fake.pictureCalls, 0);
    expect(sensorCancels, 1);
  });

  test(
    'dispose during sensor guidance releases sensors before the camera',
    () async {
      sensorsAvailable = true;
      final capture = service.captureAndCompress(onGuidance: (_) {});
      final result = expectLater(capture, cancelled);
      await sensorsStarted.future;
      await service.dispose();
      await result;
      expect(sensorCancels, 1);
      expect(fake.pictureCalls, 0);
      expect(fake.disposed, [0]);
      expect(service.sensorService.isChecking, isFalse);
    },
  );

  test(
    'stalled sensor discovery is optional and cannot prevent cloud capture',
    () async {
      sensorCapabilityGate = Completer<void>();
      final capture = service.captureAndCompress(onGuidance: (_) {});
      await sensorsQueried.future;
      await capture.timeout(const Duration(seconds: 1));
      expect(sensorListens, 0);
      expect(fake.pictureCalls, 1);
      sensorCapabilityGate!.complete();
      await pumpEventQueue();
      expect(sensorListens, 0);
    },
  );

  test(
    'no samples times out below one second and cleans up before cloud capture',
    () async {
      sensorsAvailable = true;
      final capture = service.captureAndCompress(onGuidance: (_) {});
      await sensorsStarted.future;
      await capture.timeout(const Duration(seconds: 1));
      expect(sensorCancels, 1);
      expect(fake.pictureCalls, 1);
    },
  );

  test(
    'optional sensor callback failure does not prevent cloud capture',
    () async {
      sensorsAvailable = true;
      final capture = service.captureAndCompress(
        onGuidance: (_) => throw StateError('Speech unavailable'),
      );
      await sensorsStarted.future;
      await emitSensor({
        'session': sensorSession,
        'sensor': 'light',
        'values': [1.0],
        'ageMillis': 0,
      });
      await emitSensor(null, end: true);
      await capture;
      expect(fake.pictureCalls, 1);
      expect(sensorCancels, 1);
    },
  );

  test('cancellation without active work is safe and does not poison future captures', () async {
    await service.cancelPendingCapture();
    await service.cancelPendingCapture();
    await service.captureForOcr();
    expect(fake.pictureCalls, 1);
  });
}
