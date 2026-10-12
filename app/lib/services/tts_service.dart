import 'package:eyesense/services/preferences_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts;
  final PreferencesService _prefs;
  bool _isSpeaking = false;
  String _lastSpokenText = '';

  TtsService(this._prefs, {FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _initTts();
  }

  bool get isSpeaking => _isSpeaking;
  String get lastSpokenText => _lastSpokenText;

  void _initTts() {
    _tts.setStartHandler(() {
      _isSpeaking = true;
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
    });
  }

  Future<void> updateSettings() async {
    await _tts.setSpeechRate(_prefs.speechRate);
    final lang = _prefs.language;
    if (lang == 'sw') {
      final isAvailable = await _tts.isLanguageAvailable('sw');
      if (isAvailable == 1 || isAvailable == true) {
        await _tts.setLanguage('sw');
      } else {
        await _tts.setLanguage('en-US');
      }
    } else {
      await _tts.setLanguage('en-US');
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await stop();
    await updateSettings();
    _lastSpokenText = text;
    _isSpeaking = true;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    _isSpeaking = false;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> repeatLast() async {
    if (_lastSpokenText.isNotEmpty) {
      await speak(_lastSpokenText);
    }
  }
}
