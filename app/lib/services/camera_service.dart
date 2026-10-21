import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:eyesense/services/device_sensor_service.dart';
import 'package:eyesense/services/frame_guidance.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class CapturedImageData {
  final File file;
  final String base64Jpeg;
  final int byteSize;
  final DateTime timestamp;

  CapturedImageData({
    required this.file,
    required this.base64Jpeg,
    required this.byteSize,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class CapturedOcrData {
  final File file;
  final DateTime timestamp;

  CapturedOcrData({required this.file, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}

class CameraService {
  CameraService({DeviceSensorService? sensorService})
    : sensorService = sensorService ?? DeviceSensorService();

  /// Shared with the optional capability/check UI. Discovery never subscribes.
  final DeviceSensorService sensorService;

  /// The coordinator may set this from preferences. Sensors are only checked
  /// for an explicit capture with an onGuidance callback, never at startup.
  bool sensorGuidanceEnabled = true;

  CameraController? _controller;
  CameraController? _initializingController;
  Future<void>? _pendingInitialization;
  ResolutionPreset? _pendingPreset;
  int? _pendingLifecycle;
  Future<void> _pendingDisposal = Future<void>.value();
  int _lifecycleGeneration = 0;
  int _captureGeneration = 0;
  Completer<void>? _guidanceDone;
  Completer<void>? _sensorCuePause;
  Future<void>? _guidanceStopped;
  bool _isCapturing = false;
  ResolutionPreset _currentPreset = ResolutionPreset.medium;

  bool get isInitialized =>
      _controller != null && _controller!.value.isInitialized;
  CameraController? get controller => _controller;

  Future<void> _checkPermissions() async {
    final status = await Permission.camera.status;
    if (status.isPermanentlyDenied) {
      throw const AppException(
        code: ErrorCode.cameraPermissionPermanentlyDenied,
        userMessage: 'Camera permission is permanently denied. Please enable camera access in App Settings.',
      );
    }
    if (!status.isGranted) {
      final reqResult = await Permission.camera.request();
      if (reqResult.isPermanentlyDenied) {
        throw const AppException(
          code: ErrorCode.cameraPermissionPermanentlyDenied,
          userMessage: 'Camera permission is permanently denied. Please enable camera access in App Settings.',
        );
      }
      if (!reqResult.isGranted) {
        throw const AppException(
          code: ErrorCode.cameraPermissionDenied,
          userMessage:
              'Camera access is required to capture scenes and read text.',
        );
      }
    }
  }

  Future<void> initialize({ResolutionPreset preset = ResolutionPreset.medium}) {
    final lifecycle = _lifecycleGeneration;
    final pending = _pendingInitialization;
    if (pending != null &&
        _pendingPreset == preset &&
        _pendingLifecycle == lifecycle) {
      return pending;
    }
    if (pending == null && isInitialized && _currentPreset == preset) {
      return Future<void>.value();
    }

    // Keep a single queue even across dispose/reinitialize. Calls for the same
    // pending preset share its result; a different preset waits its turn.
    late final Future<void> initialization;
    initialization = Future<void>.microtask(() async {
      try {
        if (pending != null) {
          try {
            await pending;
          } catch (_) {
            // A failed or invalidated predecessor must not poison the queue.
          }
        }
        _checkLifecycle(lifecycle);
        await _initializeController(preset, lifecycle);
      } finally {
        if (identical(_pendingInitialization, initialization)) {
          _pendingInitialization = null;
          _pendingPreset = null;
          _pendingLifecycle = null;
        }
      }
    });
    _pendingInitialization = initialization;
    _pendingPreset = preset;
    _pendingLifecycle = lifecycle;
    return initialization;
  }

  Future<void> _initializeController(
    ResolutionPreset preset,
    int lifecycle,
  ) async {
    CameraController? candidate;
    try {
      await _pendingDisposal;
      _checkLifecycle(lifecycle);
      if (isInitialized && _currentPreset == preset) return;
      await _checkPermissions();
      _checkLifecycle(lifecycle);

      final cameras = await availableCameras();
      _checkLifecycle(lifecycle);
      if (cameras.isEmpty) {
        throw const AppException(
          code: ErrorCode.cameraUnavailable,
          userMessage: 'No camera is available on this device.',
        );
      }

      final previous = _controller;
      _controller = null;
      await _disposeController(previous);
      _checkLifecycle(lifecycle);

      final rearCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      candidate = CameraController(rearCamera, preset, enableAudio: false);
      _initializingController = candidate;
      await candidate.initialize();
      _checkLifecycle(lifecycle);
      _controller = candidate;
      _initializingController = null;
      _currentPreset = preset;
    } catch (e) {
      if (candidate != null && identical(_initializingController, candidate)) {
        _initializingController = null;
        await _disposeController(candidate);
      }
      _checkLifecycle(lifecycle);
      if (e is AppException) rethrow;
      throw AppException(
        code: ErrorCode.cameraUnavailable,
        userMessage: 'Could not initialize device camera.',
        technicalDetail: e.toString(),
      );
    }
  }

  void _checkLifecycle(int lifecycle) {
    if (lifecycle != _lifecycleGeneration) _throwCancelled();
  }

  void _checkCapture(int generation) {
    if (generation != _captureGeneration) _throwCancelled();
  }

  Never _throwCancelled() => throw const AppException(
    code: ErrorCode.operationCancelled,
    userMessage: 'Camera operation cancelled.',
  );

  Future<PermissionStatus> permissionStatus() => Permission.camera.status;

  Future<bool> hasPermission() async =>
      (await Permission.camera.status).isGranted;

  Future<bool> isPermissionPermanentlyDenied() async =>
      (await Permission.camera.status).isPermanentlyDenied;

  /// Asks for camera permission without starting a capture. Call this from a
  /// labelled step so the system dialog is not interleaved with an operation.
  Future<bool> requestPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;
    final result = await Permission.camera.request();
    return result.isGranted;
  }

  /// Deletes camera stills left behind by a crash. Only files named like the
  /// camera plugin's `CAP<digits>.jpg` and older than two minutes are removed.
  Future<void> sweepOrphanedCaptures() async {
    try {
      final dir = await getTemporaryDirectory();
      final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!RegExp(r'^CAP\d+\.jpe?g$', caseSensitive: false).hasMatch(name)) {
          continue;
        }
        final modified = await entity.lastModified();
        if (modified.isBefore(cutoff)) {
          await deleteTemporaryCapture(entity);
        }
      }
    } catch (_) {}
  }

  /// Lightweight capture for on-device OCR without expensive image decoding, resizing, or base64 encoding.
  ///
  /// When [onGuidance] is set, sampled luminance frames are assessed first and
  /// a still is taken after quality measurements settle, or a short timeout.
  /// [cancelPendingCapture] prevents the still if called during this wait.
  /// ML Kit itself still cannot be cancelled once recognition starts.
  Future<CapturedOcrData> captureForOcr({
    void Function(String phrase)? onGuidance,
  }) async {
    if (_isCapturing) {
      throw const AppException(
        code: ErrorCode.cameraUnavailable,
        userMessage: 'Camera is currently busy capturing another image.',
      );
    }
    _isCapturing = true;
    final generation = _captureGeneration;
    File? originalFile;

    try {
      await initialize(preset: ResolutionPreset.high);
      _checkCapture(generation);

      if (onGuidance != null) {
        var guided = false;
        void guideOnce(String phrase) {
          if (guided || generation != _captureGeneration) return;
          guided = true;
          onGuidance(phrase);
        }

        await _guideWithSensors(guideOnce, generation);
        _checkCapture(generation);
        await _guideBeforeCapture(guideOnce, generation);
      }

      final captureTime = DateTime.now();
      _checkCapture(generation);
      final xfile = await _controller!.takePicture();
      originalFile = File(xfile.path);
      _checkCapture(generation);

      return CapturedOcrData(file: originalFile, timestamp: captureTime);
    } catch (_) {
      await deleteTemporaryCapture(originalFile);
      _checkCapture(generation);
      rethrow;
    } finally {
      _isCapturing = false;
    }
  }

  /// Cloud capture with bounding, resizing, and base64 JPEG encoding.
  /// Sensor sampling is best effort (<1 second). A cue adds a cancellable
  /// 1.5-second adjustment pause. There is no sensor query or pause without
  /// [onGuidance], and no pause when sensors produce no cue.
  Future<CapturedImageData> captureAndCompress({
    void Function(String phrase)? onGuidance,
  }) async {
    if (_isCapturing) {
      throw const AppException(
        code: ErrorCode.cameraUnavailable,
        userMessage: 'Camera is currently busy capturing another image.',
      );
    }
    _isCapturing = true;
    final generation = _captureGeneration;
    File? originalFile;

    try {
      await initialize(preset: ResolutionPreset.medium);
      _checkCapture(generation);
      if (onGuidance != null) {
        await _guideWithSensors(onGuidance, generation);
      }

      final captureTime = DateTime.now();
      _checkCapture(generation);
      final xfile = await _controller!.takePicture();
      originalFile = File(xfile.path);
      _checkCapture(generation);
      final rawBytes = await originalFile.readAsBytes();
      _checkCapture(generation);

      // Decode and resize if needed
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        throw const AppException(
          code: ErrorCode.cameraUnavailable,
          userMessage: 'Failed to process captured image.',
        );
      }

      img.Image processed = decoded;
      final maxDim = AppConfig.maxImageLongEdge;
      if (decoded.width > maxDim || decoded.height > maxDim) {
        if (decoded.width >= decoded.height) {
          processed = img.copyResize(decoded, width: maxDim);
        } else {
          processed = img.copyResize(decoded, height: maxDim);
        }
      }

      final compressedBytes = img.encodeJpg(
        processed,
        quality: AppConfig.jpegQuality,
      );
      if (compressedBytes.length > AppConfig.maxImageDecodedBytes) {
        throw const AppException(
          code: ErrorCode.validationFailed,
          userMessage:
              'Captured image is too large for processing. Please try again.',
        );
      }

      final base64Str = base64Encode(compressedBytes);
      _checkCapture(generation);
      return CapturedImageData(
        file: originalFile,
        base64Jpeg: base64Str,
        byteSize: compressedBytes.length,
        timestamp: captureTime,
      );
    } catch (_) {
      await deleteTemporaryCapture(originalFile);
      _checkCapture(generation);
      rethrow;
    } finally {
      _isCapturing = false;
    }
  }

  /// Cancels the active capture and silences guidance immediately. Safe to call
  /// repeatedly or without an active capture. An already-issued native still
  /// cannot be aborted; its result is discarded and its temporary file deleted.
  Future<void> cancelPendingCapture() async {
    _captureGeneration++;
    final done = _guidanceDone;
    if (done != null && !done.isCompleted) done.complete();
    final pause = _sensorCuePause;
    if (pause != null && !pause.isCompleted) pause.complete();
    await Future.wait<void>([sensorService.stop(), ?_guidanceStopped]);
  }

  Future<void> _guideWithSensors(
    void Function(String phrase) onGuidance,
    int generation,
  ) async {
    if (!sensorGuidanceEnabled) return;
    try {
      final assessment = await sensorService.check();
      if (generation != _captureGeneration || !sensorGuidanceEnabled) return;
      final cue = assessment.guidance;
      if (cue != null) {
        onGuidance(cue);
        if (generation != _captureGeneration) return;
        // Give the user a short chance to react; sampling has already stopped.
        // Stop/backgrounding releases this wait immediately, not after a timer.
        final pause = Completer<void>();
        _sensorCuePause = pause;
        final timer = Timer(const Duration(milliseconds: 1500), () {
          if (!pause.isCompleted) pause.complete();
        });
        try {
          await pause.future;
        } finally {
          timer.cancel();
          if (identical(_sensorCuePause, pause)) _sensorCuePause = null;
        }
      }
    } catch (_) {
      // Optional sensors or a failed guidance callback must not block a still.
    } finally {
      await sensorService.stop();
    }
  }

  Future<void> _guideBeforeCapture(
    void Function(String phrase) onGuidance,
    int generation,
  ) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    FrameAssessment? previous;
    var stable = 0;
    final done = Completer<void>();
    final stopped = Completer<void>();
    _guidanceDone = done;
    _guidanceStopped = stopped.future;
    try {
      _checkCapture(generation);
      await controller.startImageStream((image) {
        if (done.isCompleted ||
            generation != _captureGeneration ||
            image.planes.isEmpty) {
          return;
        }
        if (image.format.group != ImageFormatGroup.yuv420 &&
            image.format.group != ImageFormatGroup.nv21) {
          return;
        }
        final plane = image.planes.first;
        final assessment = FrameGuidance.assess(
          plane.bytes,
          image.width,
          image.height,
          bytesPerRow: plane.bytesPerRow,
        );
        if (assessment.correction != null) {
          try {
            onGuidance(assessment.correction!);
          } catch (_) {
            // A callback can fail asynchronously after startImageStream has
            // returned. End optional guidance rather than leaking the stream.
            if (!done.isCompleted) done.complete();
            return;
          }
          stable = 0;
        } else if (previous != null && assessment.isStableWith(previous!)) {
          stable++;
        } else {
          stable = 0;
        }
        previous = assessment;
        if (assessment.readyToCapture && stable >= 2 && !done.isCompleted) {
          done.complete();
        }
      });
      await done.future.timeout(const Duration(seconds: 8), onTimeout: () {});
    } catch (_) {
      // Unsupported guidance may fall back to a still, but cancellation is
      // checked by the caller after the stream has been stopped.
    } finally {
      if (!done.isCompleted) done.complete();
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
      if (identical(_guidanceDone, done)) {
        _guidanceDone = null;
        _guidanceStopped = null;
      }
      stopped.complete();
    }
  }

  /// Deletes a temporary capture file safely without throwing
  Future<void> deleteTemporaryCapture(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Non-fatal cleanup
    }
  }

  Future<void> _disposeController(CameraController? controller) async {
    try {
      await controller?.dispose();
    } catch (_) {}
  }

  Future<void> dispose() {
    // Invalidate before awaiting anything: late permission/discovery/initialize
    // completions must never publish a controller after a background dispose.
    _lifecycleGeneration++;
    final cancelled = cancelPendingCapture();
    final current = _controller;
    final initializing = _initializingController;
    _controller = null;
    _initializingController = null;
    final previousDisposal = _pendingDisposal;
    final disposal = Future<void>.microtask(() async {
      await previousDisposal;
      await cancelled;
      await _disposeController(current);
      await _disposeController(initializing);
    });
    _pendingDisposal = disposal;
    return disposal;
  }
}
