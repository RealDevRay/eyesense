import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

class SemanticAnnouncer {
  static DateTime? lastAnnouncedAt;

  /// Short non-content events only. Callers must not use this for results
  /// or for anything within 300 ms of starting app TTS.
  static void announce(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    lastAnnouncedAt = DateTime.now();
    SemanticsService.sendAnnouncement(views.first, trimmed, TextDirection.ltr);
  }
}
