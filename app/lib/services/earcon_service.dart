import 'package:audioplayers/audioplayers.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:eyesense/services/tts_service.dart';

enum Earcon {
  shutter,
  processing,
  success,
  error,
  concern,
  listening,
  ready,
}

/// Short distinct cues. Failures are swallowed so a missing audio plugin
/// never blocks assistance. Cues duck while speech is playing.
class EarconService {
  final PreferencesService _prefs;
  final TtsService _tts;
  final AudioPlayer? _injected;
  AudioPlayer? _player;
  bool _looping = false;

  EarconService(
    this._prefs,
    this._tts, {
    AudioPlayer? player,
  }) : _injected = player;

  Future<void> play(Earcon earcon) async {
    if (!_prefs.earconsEnabled) return;
    try {
      final player = _player ??= _injected ?? AudioPlayer();
      if (earcon == Earcon.processing) {
        await player.setReleaseMode(ReleaseMode.loop);
        _looping = true;
      } else {
        await stopLoop();
        await player.setReleaseMode(ReleaseMode.release);
      }
      await player.setVolume(_tts.isSpeaking ? 0.12 : 0.4);
      await player.play(AssetSource('earcons/${earcon.name}.wav'));
    } catch (_) {}
  }

  Future<void> stopLoop() async {
    if (!_looping) return;
    _looping = false;
    try {
      await _player?.stop();
    } catch (_) {}
  }
}
