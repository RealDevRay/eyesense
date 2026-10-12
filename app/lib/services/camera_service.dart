import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:image/image.dart' as img;

class CapturedImageData {
  final File file;
  final String base64Jpeg;
  final int byteSize;

  CapturedImageData({
    required this.file,
    required this.base64Jpeg,
    required this.byteSize,
  });
}

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCapturing = false;

  bool get isInitialized => _controller != null && _controller!.value.isInitialized;
  CameraController? get controller => _controller;

  Future<void> initialize() async {
    if (isInitialized) return;
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        throw const AppException(
          code: ErrorCode.cameraUnavailable,
          userMessage: 'No camera is available on this device.',
        );
      }

      // Select rear camera by default
      final rearCamera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        rearCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        code: ErrorCode.cameraPermissionDenied,
        userMessage: 'Camera permission denied or camera unavailable.',
        technicalDetail: e.toString(),
      );
    }
  }

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
        await initialize();
      }

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
      );
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
