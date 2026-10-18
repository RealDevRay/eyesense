import 'dart:async';

import 'package:eyesense/core/accessibility/semantic_announcer.dart';
import 'package:eyesense/services/haptic_service.dart';
import 'package:eyesense/services/tts_service.dart';

enum SpeechPriority { status, content, interrupt }

class _QueuedUtterance {
  final String text;
  final SpeechPriority priority;
  final int generation;
  final void Function()? onBegin;
  final Completer<void> done;

  _QueuedUtterance({
    required this.text,
    required this.priority,
    required this.generation,
    required this.done,
    this.onBegin,
  });
}

/// App TTS is the only channel for content and status.
/// An error or Stop clears anything still waiting and pre-empts playback.
/// [SemanticsService] announcements are reserved for short non-content
/// events and are skipped within 300 ms of TTS starting.
class SpeechFeedbackCoordinator {
  final TtsService ttsService;
  final HapticService hapticService;
  final DateTime Function() _now;

  final List<_QueuedUtterance> _pending = [];
  bool _draining = false;
  int _generation = 0;
  DateTime? _lastTtsStartedAt;
  String? _currentText;

  SpeechFeedbackCoordinator({
    required this.ttsService,
    required this.hapticService,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  bool get isSpeaking => ttsService.isSpeaking;

  void speakStatus(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (_currentText == trimmed) return;
    if (_pending.any((item) => item.priority == SpeechPriority.status && item.text == trimmed)) {
      return;
    }
    _pending.removeWhere((item) {
      final drop = item.priority == SpeechPriority.status;
      if (drop && !item.done.isCompleted) item.done.complete();
      return drop;
    });
    unawaited(_enqueue(trimmed, SpeechPriority.status));
  }

  Future<void> speakResult(
    String text, {
    bool autoRead = true,
    void Function()? onBegin,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (!autoRead) {
      _announceIfSafe('Result ready. Open the result area to explore.');
      return;
    }
    await _enqueue(trimmed, SpeechPriority.content, onBegin: onBegin);
  }

  Future<void> speakError(String text, {required bool autoRead}) async {
    final trimmed = text.trim();
    if (!autoRead || trimmed.isEmpty) return;
    await interruptWith(trimmed);
  }

  Future<void> interruptWith(String? text) async {
    _generation++;
    final dropped = List<_QueuedUtterance>.from(_pending);
    _pending.clear();
    for (final item in dropped) {
      if (!item.done.isCompleted) item.done.complete();
    }
    _currentText = null;
    await ttsService.stop();
    final trimmed = text?.trim() ?? '';
    if (trimmed.isEmpty) return;
    _lastTtsStartedAt = _now();
    _currentText = trimmed;
    await ttsService.speak(trimmed);
    _currentText = null;
  }

  Future<void> playReadinessCue() async {
    await hapticService.confirmAction();
  }

  Future<void> stopAll() async {
    await interruptWith(null);
  }

  Future<void> repeatLast() async {
    await ttsService.repeatLast();
  }

  void _announceIfSafe(String message) {
    final started = _lastTtsStartedAt;
    if (started != null && _now().difference(started) < const Duration(milliseconds: 300)) {
      return;
    }
    SemanticAnnouncer.announce(message);
  }

  Future<void> _enqueue(
    String text,
    SpeechPriority priority, {
    void Function()? onBegin,
  }) {
    final completer = Completer<void>();
    _pending.add(_QueuedUtterance(
      text: text,
      priority: priority,
      generation: _generation,
      done: completer,
      onBegin: onBegin,
    ));
    unawaited(_drain());
    return completer.future;
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_pending.isNotEmpty) {
        final item = _pending.removeAt(0);
        if (item.generation != _generation) {
          if (!item.done.isCompleted) item.done.complete();
          continue;
        }
        _lastTtsStartedAt = _now();
        _currentText = item.text;
        item.onBegin?.call();
        try {
          await ttsService.speak(item.text);
        } catch (_) {}
        _currentText = null;
        if (!item.done.isCompleted) item.done.complete();
      }
    } finally {
      _draining = false;
      if (_pending.isNotEmpty) {
        unawaited(_drain());
      }
    }
  }
}
