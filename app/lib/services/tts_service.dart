import 'dart:async';
import 'package:eyesense/core/speech/speech_rate.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService extends ChangeNotifier {
  final FlutterTts _tts;
  final PreferencesService _prefs;
  bool _isSpeaking = false;
  String _lastSpokenText = '';
  bool _stopRequested = false;
  Completer<void>? _activeChunkCompleter;

  static const int maxTtsChunkLength = 3500; // Android TTS limit is 4000 UTF-16 units

  TtsService(this._prefs, {FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _initTts();
  }

  bool get isSpeaking => _isSpeaking;
  String get lastSpokenText => _lastSpokenText;

  void _initTts() {
    _tts.setStartHandler(() {
      _isSpeaking = true;
      notifyListeners();
    });

    _tts.setCompletionHandler(() {
      _completeActiveChunk();
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
      _completeActiveChunk();
      notifyListeners();
    });

    _tts.setErrorHandler((_) {
      _isSpeaking = false;
      _completeActiveChunk();
      notifyListeners();
    });
  }

  void _completeActiveChunk() {
    if (_activeChunkCompleter != null && !_activeChunkCompleter!.isCompleted) {
      _activeChunkCompleter!.complete();
    }
  }

  Future<void> updateSettings() async {
    final rate = SpeechRateScale.toPlatformRate(_prefs.speechRate);
    await _tts.setSpeechRate(rate);

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

  /// Splits long text into bounded chunks respecting sentence and paragraph boundaries
  static List<String> splitIntoChunks(String text, [int maxChunkLength = maxTtsChunkLength]) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return [];
    if (trimmed.length <= maxChunkLength) return [trimmed];

    final List<String> chunks = [];
    final paragraphs = trimmed.split('\n');
    String currentChunk = '';

    for (final paragraph in paragraphs) {
      final trimmedPara = paragraph.trim();
      if (trimmedPara.isEmpty) continue;

      if ((currentChunk.length + trimmedPara.length + 1) <= maxChunkLength) {
        currentChunk = currentChunk.isEmpty ? trimmedPara : '$currentChunk\n$trimmedPara';
      } else {
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk);
          currentChunk = '';
        }

        if (trimmedPara.length <= maxChunkLength) {
          currentChunk = trimmedPara;
        } else {
          // Paragraph exceeds limit: split by sentence
          final sentences = trimmedPara.split(RegExp(r'(?<=[.?!;])\s+'));
          for (final sentence in sentences) {
            final trimmedSentence = sentence.trim();
            if (trimmedSentence.isEmpty) continue;

            if ((currentChunk.length + trimmedSentence.length + 1) <= maxChunkLength) {
              currentChunk = currentChunk.isEmpty ? trimmedSentence : '$currentChunk $trimmedSentence';
            } else {
              if (currentChunk.isNotEmpty) {
                chunks.add(currentChunk);
                currentChunk = '';
              }
              if (trimmedSentence.length <= maxChunkLength) {
                currentChunk = trimmedSentence;
              } else {
                // Sentence is huge: split by words
                final words = trimmedSentence.split(' ');
                for (final word in words) {
                  if ((currentChunk.length + word.length + 1) <= maxChunkLength) {
                    currentChunk = currentChunk.isEmpty ? word : '$currentChunk $word';
                  } else {
                    if (currentChunk.isNotEmpty) {
                      chunks.add(currentChunk);
                      currentChunk = '';
                    }
                    currentChunk = word;
                  }
                }
              }
            }
          }
        }
      }
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk);
    }

    return chunks;
  }

  /// Speaks text, observing completion of all chunks before completing.
  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await stop();
    await updateSettings();

    _lastSpokenText = trimmed;
    _stopRequested = false;
    _isSpeaking = true;
    notifyListeners();

    final chunks = splitIntoChunks(trimmed);

    for (int i = 0; i < chunks.length; i++) {
      if (_stopRequested) break;

      final chunk = chunks[i];
      _activeChunkCompleter = Completer<void>();

      try {
        await _tts.speak(chunk);
        // Wait for completion with bounded safeguard timeout per chunk
        await _activeChunkCompleter!.future.timeout(
          const Duration(seconds: 45),
          onTimeout: () {
            // Guard against dropped platform completion events
          },
        );
      } catch (_) {
        break;
      }
    }

    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> stop() async {
    _stopRequested = true;
    _isSpeaking = false;
    _completeActiveChunk();
    try {
      await _tts.stop();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> repeatLast() async {
    if (_lastSpokenText.isNotEmpty) {
      await speak(_lastSpokenText);
    }
  }

  @override
  void dispose() {
    _stopRequested = true;
    _completeActiveChunk();
    _tts.stop();
    super.dispose();
  }
}
