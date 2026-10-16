// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum SpeechOutcomeType {
  recognized,
  noSpeech,
  timeout,
  permissionDenied,
  unavailable,
  cancelled,
  error,
}

class SpeechOutcome {
  final SpeechOutcomeType type;
  final String? recognizedText;
  final String? errorMessage;

  const SpeechOutcome({
    required this.type,
    this.recognizedText,
    this.errorMessage,
  });
}

class SpeechService extends ChangeNotifier {
  final SpeechToText _speech;
  bool _isInitialized = false;
  String? _lastError;
  bool _isListening = false;

  SpeechService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  bool get isListening => _isListening || _speech.isListening;
  String? get lastError => _lastError;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (SpeechRecognitionError error) {
          _lastError = error.errorMsg;
          _isListening = false;
          notifyListeners();
        },
        onStatus: (String status) {
          if (status == 'listening') {
            _isListening = true;
          } else if (status == 'notListening' || status == 'done') {
            _isListening = false;
          }
          notifyListeners();
        },
      );
      return _isInitialized;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  /// Listens for a spoken command or question with bounded duration and silence timeout.
  Future<void> listen({
    required Function(String recognizedWords, bool isFinal) onResult,
    Function(SpeechOutcome outcome)? onOutcome,
    String? localeId,
    Duration listenFor = const Duration(seconds: 10),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    final available = await initialize();
    if (!available) {
      final outcome = const SpeechOutcome(
        type: SpeechOutcomeType.unavailable,
        errorMessage: 'Speech recognition service is unavailable on this device.',
      );
      onOutcome?.call(outcome);
      throw const AppException(
        code: ErrorCode.speechRecognitionUnavailable,
        userMessage: 'Speech recognition is unavailable. You can type your question instead.',
      );
    }

    if (_speech.hasError && _speech.lastError?.permanent == true) {
      final outcome = const SpeechOutcome(
        type: SpeechOutcomeType.permissionDenied,
        errorMessage: 'Microphone permission denied.',
      );
      onOutcome?.call(outcome);
      throw const AppException(
        code: ErrorCode.microphonePermissionDenied,
        userMessage: 'Microphone permission was denied. You can type your question instead.',
      );
    }

    _isListening = true;
    notifyListeners();

    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
          if (result.finalResult) {
            _isListening = false;
            notifyListeners();
            onOutcome?.call(SpeechOutcome(
              type: result.recognizedWords.trim().isNotEmpty
                  ? SpeechOutcomeType.recognized
                  : SpeechOutcomeType.noSpeech,
              recognizedText: result.recognizedWords.trim(),
            ));
          }
        },
        localeId: localeId,
        listenFor: listenFor,
        pauseFor: pauseFor,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );
    } catch (e) {
      _isListening = false;
      notifyListeners();
      onOutcome?.call(SpeechOutcome(
        type: SpeechOutcomeType.error,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  Future<void> stop() async {
    _isListening = false;
    notifyListeners();
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancel() async {
    _isListening = false;
    notifyListeners();
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}
