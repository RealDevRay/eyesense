import 'package:flutter/semantics.dart';

class SemanticAnnouncer {
  static void announce(String message) {
    if (message.trim().isEmpty) return;
    // ignore: deprecated_member_use
    SemanticsService.announce(message, TextDirection.ltr);
  }
}
