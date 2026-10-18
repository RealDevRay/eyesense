import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
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

  CapturedOcrData({
    required this.file,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCapturing = false;
  bool _isInitializing = false;
  ResolutionPreset _currentPreset = ResolutionPreset.medium;

  bool get isInitialized => _controller != null && _controller!.value.isInitialized;
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
          userMessage: 'Camera access is required to capture scenes and read text.',
        );
      }
    }
  }

  Future<void> initialize({ResolutionPreset preset = ResolutionPreset.medium}) async {
    if (isInitialized && _currentPreset == preset) return;
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      await _checkPermissions();

      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        throw const AppException(
          code: ErrorCode.cameraUnavailable,
          userMessage: 'No camera is available on this device.',
        );
      }

      // Dispose any existing controller before re-initializing
      await dispose();

      // Select rear camera by default
      final rearCamera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      final controller = CameraController(
        rearCamera,
        preset,
        enableAudio: false,
      );

      await controller.initialize();
      _controller = controller;
      _currentPreset = preset;
    } catch (e) {
      await dispose();
      if (e is AppException) rethrow;
      throw AppException(
        code: ErrorCode.cameraUnavailable,
        userMessage: 'Could not initialize device camera.',
        technicalDetail: e.toString(),
      );
    } finally {
      _isInitializing = false;
    }
  }

  Future<PermissionStatus> permissionStatus() => Permission.camera.status;

  Future<bool> hasPermission() async => (await Permission.camera.status).isGranted;

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
        if (!RegExp(r'^CAP\d+\.jpe?g$', caseSensitive: false).hasMatch(name)) continue;
        final modified = await entity.lastModified();
        if (modified.isBefore(cutoff)) {
          await deleteTemporaryCapture(entity);
        }
      }
    } catch (_) {}
  }

  /// Lightweight capture for on-device OCR without expensive image decoding, resizing, or base64 encoding.
  ///
  /// When [onGuidance] is set, low-resolution frames are assessed first and a
  /// still is taken after the frame looks stable, or after a short timeout.
  /// ML Kit itself still cannot be cancelled once recognition starts.
  Future<CapturedOcrData> captureForOcr({void Function(String phrase)? onGuidance}) async {
    if (_isCapturing) {
      throw const AppException(
        code: ErrorCode.cameraUnavailable,
        userMessage: 'Camera is currently busy capturing another image.',
      );
    }
    _isCapturing = true;

    try {
      if (!isInitialized) {
        await initialize(preset: ResolutionPreset.high);
      }

      if (onGuidance != null) {
        await _guideBeforeCapture(onGuidance);
      }

      final captureTime = DateTime.now();
      final xfile = await _controller!.takePicture();
      final originalFile = File(xfile.path);

      return CapturedOcrData(
        file: originalFile,
        timestamp: captureTime,
      );
    } finally {
      _isCapturing = false;
    }
  }

  /// Cloud capture with bounding, resizing, and base64 JPEG encoding
  Future<CapturedImageData> captureAndCompress() async {
    if (_isCapturing) {
      throw const AppException(
        code: ErrorCode.cameraUnavailable,
        userMessage: 'Camera is currently busy capturing another image.',
      );
    }
    _isCapturing = true;

    try {
      if (!isInitialized) {
        await initialize(preset: ResolutionPreset.medium);
      }

      final captureTime = DateTime.now();
      final xfile = await _controller!.takePicture();
      final originalFile = File(xfile.path);
      final rawBytes = await originalFile.readAsBytes();

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

      final compressedBytes = img.encodeJpg(processed, quality: AppConfig.jpegQuality);
      if (compressedBytes.length > AppConfig.maxImageDecodedBytes) {
        throw const AppException(
          code: ErrorCode.validationFailed,
          userMessage: 'Captured image is too large for processing. Please try again.',
        );
      }

      final base64Str = base64Encode(compressedBytes);
      return CapturedImageData(
        file: originalFile,
        base64Jpeg: base64Str,
        byteSize: compressedBytes.length,
        timestamp: captureTime,
      );
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _guideBeforeCapture(void Function(String phrase) onGuidance) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    FrameAssessment? previous;
    var stable = 0;
    final done = Completer<void>();
    try {
      await controller.startImageStream((image) {
        if (done.isCompleted || image.planes.isEmpty) return;
        final plane = image.planes.first;
        final assessment = FrameGuidance.assess(
          plane.bytes,
          image.width,
          image.height,
          bytesPerRow: plane.bytesPerRow,
        );
        if (assessment.correction != null) {
          onGuidance(assessment.correction!);
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
      // Guidance is optional. A still capture still happens.
    } finally {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
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

  Future<void> dispose() async {
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
  }
}
