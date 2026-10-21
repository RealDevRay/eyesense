import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:dio/dio.dart';
import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/features/ask/ask_screen.dart';
import 'package:eyesense/models/app_operation.dart';
import 'package:eyesense/models/scene_result.dart';
import 'package:eyesense/services/credential_service.dart';
import 'package:eyesense/services/diagnostic_log_service.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:eyesense/services/speech_service.dart';
import 'package:eyesense/widgets/accessible_action_button.dart';
import 'package:eyesense/widgets/operation_status.dart';
import 'package:eyesense/widgets/response_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coordinator_test.dart';

class _AskCamera extends FakeCameraService {
  int permissionChecks = 0;
  int permissionRequests = 0;
  int disposals = 0;
  bool permissionGranted = true;
  bool permanentlyDenied = false;
  bool permanentlyDenyOnRequest = false;
  Completer<bool>? permissionCheck;
  Completer<bool>? permissionRequest;

  @override
  Future<bool> hasPermission() async {
    permissionChecks++;
    return permissionCheck == null
        ? permissionGranted
        : await permissionCheck!.future;
  }

  @override
  Future<bool> isPermissionPermanentlyDenied() async => permanentlyDenied;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (permanentlyDenyOnRequest) permanentlyDenied = true;
    return permissionRequest == null
        ? permissionGranted
        : await permissionRequest!.future;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

class _AskSpeech extends FakeSpeechService {
  int listenCalls = 0;
  int cancelCalls = 0;
  bool _listening = false;
  Function(String, bool)? _onResult;
  Function(SpeechOutcome)? _onOutcome;

  @override
  bool get isListening => _listening;

  @override
  Future<void> listen({
    required Function(String words, bool isFinal) onResult,
    Function(SpeechOutcome outcome)? onOutcome,
    String? localeId,
    Duration listenFor = const Duration(seconds: 10),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    listenCalls++;
    _onResult = onResult;
    _onOutcome = onOutcome;
    _listening = true;
    notifyListeners();
  }

  void finish(String words) {
    _listening = false;
    notifyListeners();
    _onResult?.call(words, true);
    _onOutcome?.call(
      SpeechOutcome(type: SpeechOutcomeType.recognized, recognizedText: words),
    );
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    _listening = false;
    notifyListeners();
    // Keep the callback so tests can simulate a late native result.
  }
}

class _AskTts extends FakeTtsService {
  int stopCalls = 0;
  bool _speaking = false;

  _AskTts(super.prefs);

  @override
  bool get isSpeaking => _speaking;

  void setSpeaking(bool value) {
    _speaking = value;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    setSpeaking(false);
  }
}

class _AskVision extends FakeVisionApiService {
  final questions = <String>[];
  // Create the gate in the widget test's fake-async zone, not in setUp.
  Completer<void>? _responseReady;
  Completer<void> get responseReady => _responseReady ??= Completer<void>();

  @override
  Future<SceneResult> askQuestion({
    required String requestId,
    required String base64Jpeg,
    required String question,
    required String language,
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    questions.add(question);
    await responseReady.future;
    return super.askQuestion(
      requestId: requestId,
      base64Jpeg: base64Jpeg,
      question: question,
      language: language,
      cancelToken: cancelToken,
      timeout: timeout,
    );
  }
}

class _AskHaptic extends FakeHapticService {
  Completer<void>? confirmation;

  _AskHaptic(super.prefs);

  @override
  Future<void> confirmAction() async {
    await confirmation?.future;
  }
}

class _AskCoordinator extends AgentCoordinator {
  int repeatCalls = 0;

  _AskCoordinator({
    required super.cameraService,
    required super.ttsService,
    required super.speechService,
    required super.ocrService,
    required super.hapticService,
    required super.preferencesService,
    required super.credentialService,
    required super.logService,
    required super.visionApi,
  });

  @override
  Future<void> repeatLast() {
    repeatCalls++;
    return super.repeatLast();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _AskCamera camera;
  late _AskSpeech speech;
  late _AskTts tts;
  late _AskVision vision;
  late _AskHaptic haptic;
  late _AskCoordinator coordinator;
  late Directory logDirectory;
  late GlobalKey<NavigatorState> navigator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'cloud_consent_granted': true,
      'terms_version_accepted': AppConfig.termsVersion,
      'app_language': 'en',
      'auto_read': false,
      'earcons_enabled': false,
    });
    final prefs = await PreferencesService.create();
    logDirectory = await Directory.systemTemp.createTemp('eyesense-ask-test');
    camera = _AskCamera();
    speech = _AskSpeech();
    tts = _AskTts(prefs);
    vision = _AskVision();
    haptic = _AskHaptic(prefs);
    navigator = GlobalKey<NavigatorState>();
    coordinator = _AskCoordinator(
      cameraService: camera,
      ttsService: tts,
      speechService: speech,
      ocrService: FakeOcrService(),
      hapticService: haptic,
      preferencesService: prefs,
      credentialService: CredentialService(),
      logService: DiagnosticLogService(prefs, directory: logDirectory),
      visionApi: vision,
    );
  });

  tearDown(() async {
    if (await logDirectory.exists()) {
      await logDirectory.delete(recursive: true);
    }
  });

  Future<void> openAsk(
    WidgetTester tester, {
    Size size = const Size(800, 1200),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: Text('Home')),
      ),
    );
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => AskScreen(coordinator: coordinator)),
      ),
    );
    await tester.pumpAndSettle();
  }

  AccessibleActionButton action(WidgetTester tester, String key) =>
      tester.widget<AccessibleActionButton>(find.byKey(Key(key)));

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.pump();
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  Future<void> tapAction(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await reveal(tester, finder);
    await tester.tap(finder);
    await tester.pump();
  }

  void expectInputsDisabled(WidgetTester tester) {
    expect(action(tester, 'ask-speak').onPressed, isNull);
    expect(action(tester, 'ask-submit').onPressed, isNull);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  }

  testWidgets(
    'opening and leaving Ask does not start work or request permission',
    (tester) async {
      camera.permissionGranted = false;
      await openAsk(tester);

      expect(camera.permissionChecks, 0);
      expect(camera.permissionRequests, 0);
      expect(camera.captureCount, 0);
      expect(speech.listenCalls, 0);
      expect(vision.questions, isEmpty);
      expect(tts.spokenTexts, isEmpty);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.textContaining('one picture'), findsOneWidget);
      expect(find.textContaining('internet'), findsOneWidget);
      expect(action(tester, 'ask-speak').onPressed, isNotNull);
      expect(action(tester, 'ask-stop').onPressed, isNull);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(speech.cancelCalls, 0);
      expect(tts.stopCalls, 0);
      expect(camera.disposals, 0);
    },
  );

  testWidgets(
    'Speak disables both inputs and accessible Stop cancels listening',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await openAsk(tester);
        await tester.enterText(find.byType(TextField), 'Where is the cup?');
        await tapAction(tester, 'ask-speak');

        expect(camera.permissionChecks, 1);
        expect(speech.listenCalls, 1);
        expect(speech.isListening, isTrue);
        expect(find.text('Listening'), findsOneWidget);
        expectInputsDisabled(tester);
        final stop = tester.getSemantics(find.byKey(const Key('ask-stop')));
        expect(stop.label, 'Stop');
        expect(stop.hint, 'Stop listening, processing or playback');
        expect(stop.flagsCollection.isButton, isTrue);
        expect(stop.flagsCollection.isEnabled, Tristate.isTrue);

        await tapAction(tester, 'ask-stop');
        await tester.pumpAndSettle();
        expect(speech.cancelCalls, 1);
        expect(speech.isListening, isFalse);
        expect(tts.spokenTexts, contains('Stopped'));
        expect(find.byType(AskScreen), findsOneWidget);
        expect(action(tester, 'ask-speak').onPressed, isNotNull);
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isTrue,
        );
        speech.finish('A late question');
        await tester.pumpAndSettle();
        expect(vision.questions, isEmpty);
        expect(camera.captureCount, 0);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'leaving owned listening cancels silently without disposing camera',
    (tester) async {
      await openAsk(tester);
      await tapAction(tester, 'ask-speak');
      expect(speech.isListening, isTrue);
      final stopsBeforeExit = tts.stopCalls;

      navigator.currentState!.pop();
      speech.finish('A question during the exit animation');
      await tester.pump();
      expect(camera.captureCount, 0);
      await tester.pumpAndSettle();
      expect(speech.cancelCalls, 1);
      expect(speech.isListening, isFalse);
      expect(tts.stopCalls, greaterThan(stopsBeforeExit));
      expect(tts.spokenTexts, isNot(contains('Stopped')));
      expect(camera.disposals, 0);
      speech.finish('A late question');
      await tester.pumpAndSettle();
      expect(vision.questions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('permission completion after route exit cannot start Ask', (
    tester,
  ) async {
    camera.permissionCheck = Completer<bool>();
    await openAsk(tester);
    await tapAction(tester, 'ask-speak');
    expectInputsDisabled(tester);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    camera.permissionCheck!.complete(false);
    await tester.pumpAndSettle();
    expect(camera.permissionRequests, 0);
    expect(speech.listenCalls, 0);
    expect(speech.cancelCalls, 0);
    expect(camera.captureCount, 0);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final voice in [true, false]) {
    testWidgets(
      'popping during ${voice ? 'voice' : 'typed'} readiness prevents microphone and capture',
      (tester) async {
        haptic.confirmation = Completer<void>();
        await openAsk(tester);
        if (!voice) {
          await tester.enterText(find.byType(TextField), 'Where is the cup?');
        }
        await tapAction(tester, voice ? 'ask-speak' : 'ask-submit');
        expect(
          coordinator.state,
          voice ? OperationState.listening : OperationState.capturing,
        );
        expect(camera.captureCount, 0);
        expect(speech.listenCalls, 0);

        navigator.currentState!.pop();
        haptic.confirmation!.complete();
        await tester.pump();
        expect(camera.captureCount, 0);
        expect(speech.listenCalls, 0);
        await tester.pumpAndSettle();
        expect(speech.cancelCalls, 1);
        expect(camera.disposals, 0);
        expect(vision.questions, isEmpty);
        expect(tts.spokenTexts, isNot(contains('Stopped')));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('popping during typed permission check prevents late capture', (
    tester,
  ) async {
    camera.permissionCheck = Completer<bool>();
    await openAsk(tester);
    await tester.enterText(find.byType(TextField), 'Where is the cup?');
    await tapAction(tester, 'ask-submit');
    navigator.currentState!.pop();
    camera.permissionCheck!.complete(true);
    await tester.pump();
    expect(camera.captureCount, 0);
    expect(vision.questions, isEmpty);
    await tester.pumpAndSettle();
    expect(speech.listenCalls, 0);
    expect(speech.cancelCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permission granted after popping cannot start a submitted Ask', (
    tester,
  ) async {
    camera.permissionGranted = false;
    camera.permissionRequest = Completer<bool>();
    await openAsk(tester);
    await tester.enterText(find.byType(TextField), 'Where is the cup?');
    await tapAction(tester, 'ask-submit');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(camera.permissionRequests, 1);

    navigator.currentState!.pop();
    camera.permissionRequest!.complete(true);
    await tester.pumpAndSettle();
    expect(camera.captureCount, 0);
    expect(vision.questions, isEmpty);
    expect(speech.listenCalls, 0);
    expect(tester.takeException(), isNull);
  });

  for (final settingsOpen in [true, false]) {
    testWidgets(
      'permanent denial offers app settings (opened: $settingsOpen)',
      (tester) async {
        camera.permissionGranted = false;
        camera.permanentlyDenied = true;
        final methods = <String>[];
        const permissions = MethodChannel(
          'flutter.baseflow.com/permissions/methods',
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          permissions,
          (call) async {
            methods.add(call.method);
            return settingsOpen;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            permissions,
            null,
          ),
        );
        await openAsk(tester, size: const Size(320, 640), textScale: 2);
        await tapAction(tester, 'ask-speak');
        await tester.pumpAndSettle();
        expect(find.text('Camera permission is off'), findsOneWidget);
        await tester.ensureVisible(find.text('Open app settings'));
        await tester.tap(find.text('Open app settings'));
        await tester.pumpAndSettle();
        expect(methods, ['openAppSettings']);
        expect(camera.permissionRequests, 0);
        expect(camera.captureCount, 0);
        expect(speech.listenCalls, 0);
        expect(tts.spokenTexts, isEmpty);
        expect(find.byType(AskScreen), findsOneWidget);
        if (!settingsOpen) {
          await tester.scrollUntilVisible(
            find.textContaining('Could not open app settings.'),
            -180,
            scrollable: find.byType(Scrollable).first,
          );
          expect(
            find.textContaining('Could not open app settings.'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('new permanent denial offers settings without starting Ask', (
    tester,
  ) async {
    camera.permissionGranted = false;
    camera.permanentlyDenyOnRequest = true;
    await openAsk(tester);
    await tapAction(tester, 'ask-speak');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Camera permission is off'), findsOneWidget);
    expect(find.text('Open app settings'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(camera.permissionRequests, 1);
    expect(camera.captureCount, 0);
    expect(speech.listenCalls, 0);
    expect(action(tester, 'ask-speak').onPressed, isNotNull);
  });

  testWidgets('typed question and result stay on Ask and Repeat is manual', (
    tester,
  ) async {
    await openAsk(tester);
    await tester.enterText(find.byType(TextField), '  Where is the cup?  ');
    await tapAction(tester, 'ask-submit');

    expect(find.byType(AskScreen), findsOneWidget);
    expect(navigator.currentState!.canPop(), isTrue);
    expect(vision.questions, ['Where is the cup?']);
    expect(find.text('Your question: Where is the cup?'), findsOneWidget);
    expectInputsDisabled(tester);
    expect(action(tester, 'ask-stop').onPressed, isNotNull);

    vision.responseReady.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AskScreen), findsOneWidget);
    expect(navigator.currentState!.canPop(), isTrue);
    expect(
      find.text('The cup is on the left side of the desk.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ResponsePanelWidget>(find.byType(ResponsePanelWidget))
          .resultText,
      'The cup is on the left side of the desk.',
    );
    expect(coordinator.repeatCalls, 0);
    expect(tts.spokenTexts.any((text) => text.contains('The cup is')), isFalse);
    expect(action(tester, 'ask-repeat').onPressed, isNotNull);
    await tapAction(tester, 'ask-repeat');
    await tester.pumpAndSettle();
    expect(coordinator.repeatCalls, 1);
    expect(
      tts.spokenTexts.last,
      contains('The cup is on the left side of the desk.'),
    );
    expect(camera.captureCount, 1);
    expect(vision.questions, hasLength(1));
    expect(speech.listenCalls, 0);
  });

  testWidgets('voice result also stays on Ask', (tester) async {
    await openAsk(tester);
    await tapAction(tester, 'ask-speak');
    speech.finish('Where is the cup?');
    await tester.pump();
    expect(vision.questions, ['Where is the cup?']);
    expectInputsDisabled(tester);

    vision.responseReady.complete();
    await tester.pump();
    expect(
      coordinator.state,
      OperationState.idle,
      reason: coordinator.errorMessage,
    );
    await tester.pumpAndSettle();
    expect(find.byType(AskScreen), findsOneWidget);
    expect(navigator.currentState!.canPop(), isTrue);
    expect(
      find.text('The cup is on the left side of the desk.'),
      findsOneWidget,
    );
    expect(action(tester, 'ask-repeat').onPressed, isNotNull);
    expect(coordinator.repeatCalls, 0);
  });

  testWidgets(
    'TTS-only playback updates controls and owned route exit cancels it',
    (tester) async {
      vision.responseReady.complete();
      await openAsk(tester);
      await tester.enterText(find.byType(TextField), 'Where is the cup?');
      await tapAction(tester, 'ask-submit');
      await tester.pumpAndSettle();
      expect(coordinator.state, OperationState.idle);

      tts.setSpeaking(true);
      await tester.pump();
      expect(find.text('Speaking'), findsOneWidget);
      expectInputsDisabled(tester);
      expect(action(tester, 'ask-repeat').onPressed, isNull);
      expect(action(tester, 'ask-stop').onPressed, isNotNull);
      await tapAction(tester, 'ask-stop');
      await tester.pumpAndSettle();
      expect(tts.isSpeaking, isFalse);
      expect(tts.spokenTexts, contains('Stopped'));

      tts.spokenTexts.clear();
      tts.setSpeaking(true);
      await tester.pump();
      final cancellationsBeforeExit = speech.cancelCalls;
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tts.isSpeaking, isFalse);
      expect(speech.cancelCalls, greaterThan(cancellationsBeforeExit));
      expect(tts.spokenTexts, isEmpty);
      expect(camera.disposals, 0);
    },
  );

  testWidgets('leaving Ask does not cancel speech it did not start', (
    tester,
  ) async {
    await openAsk(tester);
    tts.setSpeaking(true);
    await tester.pump();
    expectInputsDisabled(tester);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tts.isSpeaking, isTrue);
    expect(tts.stopCalls, 0);
    expect(speech.cancelCalls, 0);
    tts.setSpeaking(false);
  });

  testWidgets(
    'Ask fits 320 px at 200 percent text with Stop outside scrolling',
    (tester) async {
      vision.responseReady.complete();
      await openAsk(tester, size: const Size(320, 640), textScale: 2);
      expect(tester.takeException(), isNull);
      final stopPosition = tester.getRect(find.byKey(const Key('ask-stop')));
      expect(stopPosition.left, greaterThanOrEqualTo(0));
      expect(stopPosition.right, lessThanOrEqualTo(320));
      expect(stopPosition.bottom, lessThanOrEqualTo(640));
      expect(stopPosition.height, greaterThanOrEqualTo(48));

      await reveal(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Where is the cup?');
      await tapAction(tester, 'ask-submit');
      await tester.pumpAndSettle();
      await reveal(tester, find.byType(ResponsePanelWidget));
      await tester.pumpAndSettle();
      expect(
        find.text('The cup is on the left side of the desk.'),
        findsOneWidget,
      );
      await reveal(tester, find.byKey(const Key('ask-repeat')));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const Key('ask-stop'))), stopPosition);
      expect(tester.takeException(), isNull);

      coordinator.debugSetOperationState(OperationState.listening);
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byType(OperationStatusWidget),
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byKey(const Key('ask-stop'))), stopPosition);
      await tapAction(tester, 'ask-stop');
      await tester.pumpAndSettle();
      expect(find.byType(AskScreen), findsOneWidget);
    },
  );
}
