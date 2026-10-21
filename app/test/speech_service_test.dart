// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:eyesense/services/speech_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class RecognizerCallbacks {
  final SpeechResultListener onResult;
  final SpeechErrorListener onError;
  final SpeechStatusListener onStatus;

  RecognizerCallbacks(this.onResult, this.onError, this.onStatus);

  void result(String words, {bool isFinal = true}) {
    onResult(
      SpeechRecognitionResult.init([
        SpeechRecognitionWords(words, null, 1),
      ], isFinal ? ResultType.finalResult : ResultType.partial),
    );
  }

  void error(String message, {bool permanent = false}) {
    onError(SpeechRecognitionError(message, permanent));
  }
}

class CallbackSpeechToText extends SpeechToText {
  CallbackSpeechToText() : super.withMethodChannel();

  final sessions = <RecognizerCallbacks>[];
  bool available = true;
  bool nativeListening = false;
  int initializeCalls = 0;
  int cancelCalls = 0;
  int stopCalls = 0;
  Completer<bool>? initializeGate;
  Completer<void>? listenGate;
  Completer<void>? cancelGate;
  Object? listenError;
  SpeechRecognitionError? initializationError;
  void Function()? duringStop;

  @override
  bool get isListening => nativeListening;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    initializeCalls++;
    errorListener = onError;
    statusListener = onStatus;
    final error = initializationError;
    if (error != null) onError?.call(error);
    return initializeGate == null ? available : await initializeGate!.future;
  }

  @override
  Future<void> listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    sessions.add(
      RecognizerCallbacks(onResult!, errorListener!, statusListener!),
    );
    nativeListening = true;
    if (listenGate != null) await listenGate!.future;
    final error = listenError;
    if (error != null) throw error;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    if (cancelGate != null) await cancelGate!.future;
    nativeListening = false;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    nativeListening = false;
    duringStop?.call();
  }
}

void main() {
  final grace =
      SpeechToText.defaultFinalTimeout + const Duration(milliseconds: 250);
  late CallbackSpeechToText plugin;
  late SpeechService service;
  late List<SpeechOutcome> outcomes;
  late List<(String, bool)> results;

  Future<void> listen({Duration listenFor = const Duration(seconds: 10)}) {
    return service.listen(
      onResult: (words, isFinal) => results.add((words, isFinal)),
      onOutcome: outcomes.add,
      listenFor: listenFor,
    );
  }

  void speechTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      plugin = CallbackSpeechToText();
      service = SpeechService(speech: plugin);
      outcomes = [];
      results = [];
      try {
        await body(tester);
      } finally {
        service.dispose();
        await tester.pump();
      }
    });
  }

  speechTest('partial results stay live; final is terminal before done', (
    tester,
  ) async {
    await listen();
    final callbacks = plugin.sessions.single;
    callbacks.onStatus('listening');
    callbacks.result('read', isFinal: false);
    expect(service.isListening, isTrue);
    expect(outcomes, isEmpty);

    callbacks.result('  read text  ');
    callbacks.result('duplicate final');
    callbacks.onStatus('notListening');
    callbacks.onStatus('done');
    callbacks.error('error_network');
    await tester.pump(const Duration(seconds: 20));

    expect(results, [('read', false), ('  read text  ', true)]);
    expect(outcomes.single.type, SpeechOutcomeType.recognized);
    expect(outcomes.single.recognizedText, 'read text');
    expect(service.isListening, isFalse);
    expect(service.lastError, isNull);
    // A terminal service session does not inherit a stale native listening bit.
    expect(plugin.nativeListening, isTrue);
  });

  speechTest('empty final emits exactly one noSpeech outcome', (tester) async {
    await listen();
    plugin.sessions.single.result('   ');
    plugin.sessions.single.onStatus('done');
    await tester.pump(grace);
    expect(outcomes.single.type, SpeechOutcomeType.noSpeech);
    expect(outcomes.single.recognizedText, '');
    expect(results, [('   ', true)]);
  });

  speechTest('initial notListening does not mean the session is done', (
    tester,
  ) async {
    await listen();
    final callbacks = plugin.sessions.single;
    callbacks.onStatus('notListening');
    await tester.pump(grace + const Duration(milliseconds: 1));
    expect(outcomes, isEmpty);
    callbacks.onStatus('listening');
    callbacks.result('hello');
    expect(outcomes.single.type, SpeechOutcomeType.recognized);
  });

  speechTest('done waits for a delayed final result', (tester) async {
    await listen();
    final callbacks = plugin.sessions.single;
    callbacks.onStatus('listening');
    callbacks.onStatus('notListening');
    callbacks.onStatus('done');
    expect(service.isListening, isFalse);
    expect(outcomes, isEmpty);
    await tester.pump(SpeechToText.defaultFinalTimeout);
    callbacks.result('delayed final');
    await tester.pump(grace);
    expect(outcomes.single.type, SpeechOutcomeType.recognized);
    expect(outcomes.single.recognizedText, 'delayed final');
  });

  for (final statuses in [
    ['done'],
    ['listening', 'done'],
    ['listening', 'notListening'],
  ]) {
    speechTest('$statuses without a final eventually emits noSpeech', (
      tester,
    ) async {
      await listen();
      final callbacks = plugin.sessions.single;
      callbacks.result('partial only', isFinal: false);
      for (final status in statuses) {
        callbacks.onStatus(status);
      }
      await tester.pump(grace - const Duration(milliseconds: 1));
      expect(outcomes, isEmpty);
      // Duplicate status updates must not extend the grace indefinitely.
      callbacks.onStatus(statuses.last);
      await tester.pump(const Duration(milliseconds: 1));
      expect(outcomes.single.type, SpeechOutcomeType.noSpeech);
      expect(service.isListening, isFalse);
      callbacks.result('too late');
      callbacks.onStatus('done');
      await tester.pump(const Duration(seconds: 20));
      expect(outcomes, hasLength(1));
      expect(results, [('partial only', false)]);
      expect(plugin.cancelCalls, 1);
    });
  }

  speechTest('a silent recognizer is bounded by the session watchdog', (
    tester,
  ) async {
    await listen(listenFor: const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1) + grace);
    expect(outcomes.single.type, SpeechOutcomeType.timeout);
    expect(service.isListening, isFalse);
    plugin.sessions.single.onStatus('listening');
    plugin.sessions.single.result('too late');
    plugin.sessions.single.error('error_network');
    await tester.pump();
    expect(results, isEmpty);
    expect(outcomes, hasLength(1));
    expect(service.lastError, isNull);
    expect(plugin.cancelCalls, 1);
  });

  const errors = {
    'error_permission': SpeechOutcomeType.permissionDenied,
    'error_no_match': SpeechOutcomeType.noSpeech,
    'error_speech_timeout': SpeechOutcomeType.timeout,
    'error_network_timeout': SpeechOutcomeType.timeout,
    'error_speech_recognizer_disabled': SpeechOutcomeType.unavailable,
    'error_network': SpeechOutcomeType.error,
    'error_busy': SpeechOutcomeType.error,
    'error_server': SpeechOutcomeType.error,
  };
  for (final entry in errors.entries) {
    speechTest('${entry.key} is terminal and is classified by code', (
      tester,
    ) async {
      await listen();
      final callbacks = plugin.sessions.single;
      callbacks.error(entry.key, permanent: true);
      callbacks.onStatus('done');
      callbacks.result('late result');
      callbacks.error('error_permission');
      await tester.pump(const Duration(seconds: 20));
      expect(outcomes.single.type, entry.value);
      expect(outcomes.single.errorMessage, entry.key);
      expect(service.lastError, entry.key);
      expect(service.isListening, isFalse);
      expect(results, isEmpty);
      expect(plugin.cancelCalls, 1);
    });
  }

  speechTest(
    'a permanent non-permission error does not poison the next listen',
    (tester) async {
      await listen();
      plugin.sessions.single.error('error_network', permanent: true);
      await listen();
      expect(service.lastError, isNull);
      expect(plugin.initializeCalls, 1);
      plugin.sessions.last.result('retry succeeded');
      expect(outcomes.map((outcome) => outcome.type), [
        SpeechOutcomeType.error,
        SpeechOutcomeType.recognized,
      ]);
    },
  );

  speechTest(
    'cancel is immediately terminal, idempotent, and rejects late events',
    (tester) async {
      await listen();
      final callbacks = plugin.sessions.single;
      await service.cancel();
      await service.cancel();
      callbacks.onStatus('listening');
      callbacks.result('late partial', isFinal: false);
      callbacks.result('late final');
      callbacks.error('error_permission');
      callbacks.onStatus('done');
      await tester.pump(const Duration(seconds: 20));
      expect(outcomes.single.type, SpeechOutcomeType.cancelled);
      expect(results, isEmpty);
      expect(service.isListening, isFalse);
      expect(service.lastError, isNull);
      expect(plugin.cancelCalls, 1);
    },
  );

  speechTest('stop accepts a final result delivered by native stop', (
    tester,
  ) async {
    await listen();
    final callbacks = plugin.sessions.single;
    plugin.duringStop = () {
      callbacks.onStatus('notListening');
      callbacks.result('final after stop');
      callbacks.onStatus('done');
    };
    await service.stop();
    await tester.pump(grace);
    expect(plugin.stopCalls, 1);
    expect(outcomes.single.type, SpeechOutcomeType.recognized);
  });

  speechTest('stop without a final result is bounded and idempotent', (
    tester,
  ) async {
    await listen();
    await service.stop();
    await service.stop();
    plugin.sessions.single.onStatus('listening');
    expect(service.isListening, isFalse);
    await tester.pump(grace);
    expect(outcomes.single.type, SpeechOutcomeType.noSpeech);
    expect(service.isListening, isFalse);
    expect(plugin.stopCalls, 1);
    expect(plugin.cancelCalls, 1);
  });

  speechTest(
    'supersession cancels the old session and ignores retained callbacks',
    (tester) async {
      await listen();
      final old = plugin.sessions.single;
      await listen();
      final current = plugin.sessions.last;
      expect(outcomes.single.type, SpeechOutcomeType.cancelled);
      expect(plugin.cancelCalls, 1);
      old.onStatus('done');
      old.onStatus('notListening');
      old.error('error_permission');
      old.result('stale final');
      expect(service.isListening, isTrue);
      expect(service.lastError, isNull);
      await tester.pump(grace);
      expect(outcomes, hasLength(1));
      current.result('current final');
      expect(outcomes.last.type, SpeechOutcomeType.recognized);
      expect(results, [('current final', true)]);
    },
  );

  speechTest('native cancellation finishes before the next native listen', (
    tester,
  ) async {
    await listen();
    plugin.cancelGate = Completer<void>();
    final cancelled = service.cancel();
    final next = listen();
    await tester.pump();
    expect(plugin.cancelCalls, 1);
    expect(plugin.sessions, hasLength(1));
    plugin.cancelGate!.complete();
    await cancelled;
    await next;
    expect(plugin.sessions, hasLength(2));
    plugin.sessions.last.result('new session');
    expect(outcomes.map((outcome) => outcome.type), [
      SpeechOutcomeType.cancelled,
      SpeechOutcomeType.recognized,
    ]);
  });

  speechTest('cancel during initialization cannot start recording afterwards', (
    tester,
  ) async {
    plugin.initializeGate = Completer<bool>();
    final pending = listen();
    await tester.pump();
    await service.cancel();
    expect(outcomes.single.type, SpeechOutcomeType.cancelled);
    plugin.initializeGate!.complete(true);
    await pending;
    expect(plugin.sessions, isEmpty);
    expect(service.isListening, isFalse);
  });

  speechTest(
    'stop during initialization cancels without starting a recognizer',
    (tester) async {
      plugin.initializeGate = Completer<bool>();
      final pending = listen();
      await tester.pump();
      await service.stop();
      expect(outcomes.single.type, SpeechOutcomeType.cancelled);
      plugin.initializeGate!.complete(true);
      await pending;
      expect(plugin.sessions, isEmpty);
      expect(plugin.stopCalls, 0);
      expect(service.isListening, isFalse);
    },
  );

  speechTest('public initialize and listen share one initialization', (
    tester,
  ) async {
    plugin.initializeGate = Completer<bool>();
    final initialization = service.initialize();
    final pending = listen();
    await tester.pump();
    expect(plugin.initializeCalls, 1);
    plugin.initializeGate!.complete(true);
    expect(await initialization, isTrue);
    await pending;
    plugin.sessions.single.result('ready');
    expect(outcomes.single.type, SpeechOutcomeType.recognized);
  });

  speechTest('transient platform errors also terminate and clean up once', (
    tester,
  ) async {
    await listen();
    plugin.sessions.single.error('error_network');
    await tester.pump();
    expect(outcomes.single.type, SpeechOutcomeType.error);
    expect(plugin.cancelCalls, 1);
    expect(service.isListening, isFalse);
  });

  speechTest(
    'concurrent starts share initialization and only start the newest session',
    (tester) async {
      plugin.initializeGate = Completer<bool>();
      final first = listen();
      await tester.pump();
      final second = listen();
      expect(outcomes.single.type, SpeechOutcomeType.cancelled);
      plugin.initializeGate!.complete(true);
      await first;
      await second;
      expect(plugin.initializeCalls, 1);
      expect(plugin.sessions, hasLength(1));
      plugin.sessions.single.result('newest');
      expect(outcomes.last.type, SpeechOutcomeType.recognized);
    },
  );

  speechTest('cancel during native startup suppresses a late startup failure', (
    tester,
  ) async {
    plugin.listenGate = Completer<void>();
    plugin.listenError = StateError('late startup failure');
    final pending = listen();
    await tester.pump();
    final cancellation = service.cancel();
    expect(outcomes.single.type, SpeechOutcomeType.cancelled);
    plugin.listenGate!.complete();
    await pending;
    await cancellation;
    expect(outcomes, hasLength(1));
    expect(service.lastError, isNull);
    expect(service.isListening, isFalse);
  });

  speechTest(
    'startup failure reports one error and preserves the thrown exception',
    (tester) async {
      final failure = StateError('startup failure');
      plugin.listenError = failure;
      await expectLater(listen(), throwsA(same(failure)));
      await tester.pump();
      expect(outcomes.single.type, SpeechOutcomeType.error);
      expect(outcomes.single.errorMessage, contains('startup failure'));
      expect(service.isListening, isFalse);
      expect(plugin.cancelCalls, 1);
    },
  );

  for (final denied in [false, true]) {
    speechTest(
      'failed initialization reports ${denied ? 'permissionDenied' : 'unavailable'} once',
      (tester) async {
        plugin.available = false;
        if (denied) {
          plugin.initializationError = SpeechRecognitionError(
            'error_permission',
            true,
          );
        }
        await expectLater(
          listen(),
          throwsA(
            isA<AppException>().having(
              (error) => error.code,
              'code',
              denied
                  ? ErrorCode.microphonePermissionDenied
                  : ErrorCode.speechRecognitionUnavailable,
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 20));
        expect(
          outcomes.single.type,
          denied
              ? SpeechOutcomeType.permissionDenied
              : SpeechOutcomeType.unavailable,
        );
        expect(plugin.sessions, isEmpty);
        expect(service.isListening, isFalse);
      },
    );
  }

  speechTest(
    'final callback can cancel or start another session without changing its outcome',
    (tester) async {
      Future<void>? next;
      await service.listen(
        onResult: (words, isFinal) {
          results.add((words, isFinal));
          if (isFinal) {
            unawaited(service.cancel());
            next = listen();
          }
        },
        onOutcome: outcomes.add,
      );
      final old = plugin.sessions.single;
      old.result('first');
      expect(outcomes.single.type, SpeechOutcomeType.recognized);
      await next;
      old.onStatus('done');
      old.error('error_permission');
      plugin.sessions.last.result('second');
      expect(outcomes.map((outcome) => outcome.type), [
        SpeechOutcomeType.recognized,
        SpeechOutcomeType.recognized,
      ]);
      expect(results, [('first', true), ('second', true)]);
    },
  );

  speechTest(
    'dispose terminates an active session and ignores callbacks afterwards',
    (tester) async {
      // Use a separate instance so the fixture teardown remains single-dispose.
      final disposablePlugin = CallbackSpeechToText();
      final disposable = SpeechService(speech: disposablePlugin);
      final disposedOutcomes = <SpeechOutcome>[];
      await disposable.listen(
        onResult: (_, _) => fail('disposed result'),
        onOutcome: disposedOutcomes.add,
      );
      final disposedCallbacks = disposablePlugin.sessions.single;
      disposable.dispose();
      disposedCallbacks.onStatus('listening');
      disposedCallbacks.error('error_network');
      disposedCallbacks.result('late');
      await tester.pump(const Duration(seconds: 20));
      expect(disposedOutcomes.single.type, SpeechOutcomeType.cancelled);
      expect(disposable.isListening, isFalse);
      expect(disposablePlugin.cancelCalls, 1);
      expect(outcomes, isEmpty);
    },
  );
}
