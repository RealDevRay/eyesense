import 'dart:io';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _recognizer;

  OcrService({TextRecognizer? recognizer})
      : _recognizer = recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> recognizeText(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _recognizer.processImage(inputImage);

      final fullText = recognizedText.text.trim();
      if (fullText.isEmpty) {
        throw const AppException(
          code: ErrorCode.noReadableTextFound,
          userMessage: 'No readable text found. Try a clearer view or better lighting.',
        );
      }

      return fullText;
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        code: ErrorCode.noReadableTextFound,
        userMessage: 'Could not read text from the camera image.',
        technicalDetail: e.toString(),
      );
    }
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }
}
