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

class _SpeechSession {
  final Function(String recognizedWords, bool isFinal) onResult;
  final Function(SpeechOutcome outcome)? onOutcome;
  Timer? deadline;
  Timer? finalResultTimer;
  bool heardListening = false;
  bool stopping = false;
  bool finished = false;

  _SpeechSession({required this.onResult, this.onOutcome});
}

class SpeechService extends ChangeNotifier {
  final SpeechToText _speech;
  bool _isInitialized = false;
  Future<bool>? _initializing;
  SpeechRecognitionError? _initializationError;
  String? _lastError;
  bool _isListening = false;
  bool _disposed = false;
  _SpeechSession? _session;
  _SpeechSession? _platformSession;
  Future<void>? _platformWork;

  // Let the plugin's own final-result fallback run before declaring no speech.
  static final _finalResultGrace =
      SpeechToText.defaultFinalTimeout + const Duration(milliseconds: 250);

  SpeechService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  bool get isListening => _isListening;
  String? get lastError => _lastError;

  Future<bool> initialize() {
    if (_disposed) return Future<bool>.value(false);
    if (_isInitialized) return Future<bool>.value(true);
    return _initializing ??= _initialize();
  }

  Future<bool> _initialize() async {
    _initializationError = null;
    var initializing = true;
    try {
      final available = await _speech.initialize(
        onError: (error) {
          if (_disposed || !initializing) return;
          _initializationError = error;
          _lastError = error.errorMsg;
        },
        onStatus: (_) {},
      );
      if (!_disposed) _isInitialized = available;
      return available && !_disposed;
    } catch (e) {
      if (!_disposed) _lastError = e.toString();
      return false;
    } finally {
      initializing = false;
      _initializing = null;
    }
  }

  bool _isCurrent(_SpeechSession session) =>
      !_disposed && identical(_session, session) && !session.finished;

  // Serialize native starts/cancellation so an old cancellation cannot stop a
  // newer recognizer. The returned future still acknowledges startup only.
  Future<void> _queuePlatform(Future<void> Function() action) {
    final next = (_platformWork ?? Future<void>.value()).then((_) => action());
    _platformWork = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  void _finish(
    _SpeechSession session,
    SpeechOutcome outcome, {
    void Function()? deliverFinalResult,
  }) {
    if (session.finished) return;
    session.finished = true;
    session.deadline?.cancel();
    session.finalResultTimer?.cancel();
    if (identical(_session, session)) {
      _session = null;
      _isListening = false;
      if (!_disposed) notifyListeners();
    }
    // Retire the session before calling client code, which may start another
    // session or cancel synchronously from its final-result callback.
    try {
      deliverFinalResult?.call();
    } finally {
      session.onOutcome?.call(outcome);
    }
  }

  Future<void> _cancelPlatform(_SpeechSession session) =>
      _queuePlatform(() => _cancelPlatformBeforeStart(session));

  void _finishAndCancel(_SpeechSession session, SpeechOutcome outcome) {
    try {
      _finish(session, outcome);
    } finally {
      unawaited(_cancelPlatform(session).catchError((Object _) {}));
    }
  }

  SpeechOutcome _errorOutcome(SpeechRecognitionError error) {
    final type = switch (error.errorMsg) {
      'error_permission' => SpeechOutcomeType.permissionDenied,
      'error_no_match' => SpeechOutcomeType.noSpeech,
      'error_speech_timeout' ||
      'error_network_timeout' => SpeechOutcomeType.timeout,
      'error_speech_recognizer_disabled' => SpeechOutcomeType.unavailable,
      _ => SpeechOutcomeType.error,
    };
    return SpeechOutcome(type: type, errorMessage: error.errorMsg);
  }

  void _waitForFinalResult(_SpeechSession session) {
    session.finalResultTimer ??= Timer(_finalResultGrace, () {
      if (!_isCurrent(session)) return;
      _finishAndCancel(
        session,
        const SpeechOutcome(type: SpeechOutcomeType.noSpeech),
      );
    });
  }

  void _onStatus(_SpeechSession session, String status) {
    if (!_isCurrent(session)) return;
    if (status == SpeechToText.listeningStatus) {
      if (session.stopping) return;
      session.heardListening = true;
      session.finalResultTimer?.cancel();
      session.finalResultTimer = null;
      _isListening = true;
    } else if (status == SpeechToText.notListeningStatus ||
        status == SpeechToText.doneStatus) {
      _isListening = false;
      // Some recognizers send notListening during startup. It is not evidence
      // of completion until listening has begun; done is an explicit end.
      if (session.heardListening || status == SpeechToText.doneStatus) {
        _waitForFinalResult(session);
      }
    }
    notifyListeners();
  }

  /// Starts recognition; this future acknowledges startup, not session completion.
  /// Each call reports one terminal outcome, including cancellation/supersession.
  Future<void> listen({
    required Function(String recognizedWords, bool isFinal) onResult,
    Function(SpeechOutcome outcome)? onOutcome,
    String? localeId,
    Duration listenFor = const Duration(seconds: 10),
    Duration pauseFor = const Duration(seconds: 3),
  }) {
    if (_disposed) throw StateError('SpeechService has been disposed.');
    final session = _SpeechSession(onResult: onResult, onOutcome: onOutcome);
    final previous = _session;
    _session = session;
    _lastError = null;
    if (previous != null) {
      _finish(previous, const SpeechOutcome(type: SpeechOutcomeType.cancelled));
    }

    return _queuePlatform(() async {
      if (!_isCurrent(session)) return;
      final available = await initialize();
      if (!_isCurrent(session)) return;
      if (!available) {
        final denied = _initializationError?.errorMsg == 'error_permission';
        _finish(
          session,
          SpeechOutcome(
            type: denied
                ? SpeechOutcomeType.permissionDenied
                : SpeechOutcomeType.unavailable,
            errorMessage: denied
                ? 'Microphone permission denied.'
                : 'Speech recognition service is unavailable on this device.',
          ),
        );
        throw AppException(
          code: denied
              ? ErrorCode.microphonePermissionDenied
              : ErrorCode.speechRecognitionUnavailable,
          userMessage: denied
              ? 'Microphone permission was denied. You can type your question instead.'
              : 'Speech recognition is unavailable. You can type your question instead.',
        );
      }

      try {
        final previousPlatformSession = _platformSession;
        if (previousPlatformSession != null) {
          await _cancelPlatformBeforeStart(previousPlatformSession);
        }
        if (!_isCurrent(session)) return;

        // initialize() only installs callbacks once. Bind its public listeners
        // to this session so retained callbacks cannot mutate a later session.
        _speech.errorListener = (error) {
          if (!_isCurrent(session)) return;
          _lastError = error.errorMsg;
          _finishAndCancel(session, _errorOutcome(error));
        };
        _speech.statusListener = (status) => _onStatus(session, status);
        _platformSession = session;
        _isListening = true;
        session.deadline = Timer(listenFor + _finalResultGrace, () {
          if (!_isCurrent(session)) return;
          _finishAndCancel(
            session,
            const SpeechOutcome(type: SpeechOutcomeType.timeout),
          );
        });
        notifyListeners();
        if (!_isCurrent(session)) return;

        await _speech.listen(
          onResult: (result) {
            if (!_isCurrent(session)) return;
            if (!result.finalResult) {
              session.onResult(result.recognizedWords, false);
              return;
            }
            final words = result.recognizedWords.trim();
            _finish(
              session,
              SpeechOutcome(
                type: words.isNotEmpty
                    ? SpeechOutcomeType.recognized
                    : SpeechOutcomeType.noSpeech,
                recognizedText: words,
              ),
              deliverFinalResult: () =>
                  session.onResult(result.recognizedWords, true),
            );
          },
          localeId: localeId,
          listenFor: listenFor,
          pauseFor: pauseFor,
          // Cancellation belongs to the serialized service queue, not the
          // plugin's unawaited error handler (which could cancel a successor).
          cancelOnError: false,
          listenMode: ListenMode.confirmation,
        );
      } catch (e) {
        if (!_isCurrent(session)) return;
        _lastError = e.toString();
        _finishAndCancel(
          session,
          SpeechOutcome(
            type: SpeechOutcomeType.error,
            errorMessage: e.toString(),
          ),
        );
        rethrow;
      }
    });
  }

  Future<void> _cancelPlatformBeforeStart(_SpeechSession session) async {
    if (!identical(_platformSession, session)) return;
    _platformSession = null;
    await _speech.cancel();
  }

  /// Stops microphone input but allows a pending final result to arrive.
  Future<void> stop() {
    final session = _session;
    if (session == null || session.stopping) return Future<void>.value();
    if (!identical(_platformSession, session)) return cancel();
    session.stopping = true;
    session.deadline?.cancel();
    _isListening = false;
    _waitForFinalResult(session);
    notifyListeners();
    return _queuePlatform(() async {
      if (!_isCurrent(session) || !identical(_platformSession, session)) return;
      try {
        await _speech.stop();
      } catch (e) {
        if (_isCurrent(session)) {
          _lastError = e.toString();
          _finishAndCancel(
            session,
            SpeechOutcome(
              type: SpeechOutcomeType.error,
              errorMessage: e.toString(),
            ),
          );
        }
        rethrow;
      }
    });
  }

  Future<void> cancel() {
    final session = _session;
    if (session != null) {
      _finish(session, const SpeechOutcome(type: SpeechOutcomeType.cancelled));
    }
    final platformSession = _platformSession;
    return platformSession == null
        ? Future<void>.value()
        : _cancelPlatform(platformSession);
  }

  @override
  void dispose() {
    _disposed = true;
    final session = _session;
    if (session != null) {
      _finish(session, const SpeechOutcome(type: SpeechOutcomeType.cancelled));
    }
    final platformSession = _platformSession;
    if (platformSession != null) {
      unawaited(_cancelPlatform(platformSession).catchError((Object _) {}));
    }
    super.dispose();
  }
}
