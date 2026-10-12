import 'package:eyesense/core/accessibility/semantic_announcer.dart';
import 'package:eyesense/services/haptic_service.dart';
import 'package:eyesense/services/tts_service.dart';

class SpeechFeedbackCoordinator {
  final TtsService ttsService;
  final HapticService hapticService;

  SpeechFeedbackCoordinator({
    required this.ttsService,
    required this.hapticService,
  });

  bool get isSpeaking => ttsService.isSpeaking;

  Future<void> speakResult(String text, {bool autoRead = true}) async {
    if (text.trim().isEmpty) return;
    if (autoRead) {
      await ttsService.speak(text);
    } else {
      // Expose to screen reader without duplicate speech
      SemanticAnnouncer.announce('Result ready. Open result area to explore.');
    }
  }

  Future<void> playReadinessCue() async {
    await hapticService.confirmAction();
    SemanticAnnouncer.announce('Listening for short command');
  }

  Future<void> stopAll() async {
    await ttsService.stop();
  }

  Future<void> repeatLast() async {
    await ttsService.repeatLast();
  }
}
