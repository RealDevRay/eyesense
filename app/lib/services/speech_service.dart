// ignore_for_file: deprecated_member_use
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speech;
  bool _isInitialized = false;

  SpeechService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  bool get isListening => _speech.isListening;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
      return _isInitialized;
    } catch (_) {
      return false;
    }
  }

  Future<void> listen({
    required Function(String recognizedWords, bool isFinal) onResult,
    String? localeId,
  }) async {
    final available = await initialize();
    if (!available) {
      throw const AppException(
        code: ErrorCode.speechRecognitionUnavailable,
        userMessage: 'Speech recognition is unavailable. You can type your question instead.',
      );
    }

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      localeId: localeId,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );
  }

  Future<void> stop() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancel() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}
