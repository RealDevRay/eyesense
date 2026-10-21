import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:camera/camera.dart';
import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:eyesense/core/theme/app_theme.dart';
import 'package:eyesense/features/ask/ask_screen.dart';
import 'package:eyesense/features/home/home_screen.dart';
import 'package:eyesense/models/app_operation.dart';
import 'package:eyesense/services/credential_service.dart';
import 'package:eyesense/services/diagnostic_log_service.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:eyesense/widgets/accessible_action_button.dart';
import 'package:eyesense/widgets/operation_status.dart';
import 'package:eyesense/widgets/response_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coordinator_test.dart';

class _PreviewController extends CameraController {
  _PreviewController()
    : super(
        const CameraDescription(
          name: 'test camera',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        ),
        ResolutionPreset.medium,
        enableAudio: false,
      ) {
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(640, 480),
    );
  }

  @override
  Widget buildPreview() => const ColoredBox(color: Colors.black);
}

class _HomeCamera extends FakeCameraService {
  int initializeCalls = 0;
  int permissionChecks = 0;
  int permissionRequests = 0;
  int disposals = 0;
  bool permissionGranted = true;
  bool permanentlyDenied = false;
  bool grantOnRequest = true;
  bool permanentlyDenyOnRequest = false;
  bool failInitialization = false;
  Completer<void>? initializationGate;
  Completer<bool>? permissionGate;
  CameraController? _previewController;

  @override
  CameraController? get controller => _previewController;

  @override
  bool get isInitialized => _previewController != null;

  @override
  Future<bool> hasPermission() async {
    permissionChecks++;
    return permissionGate == null
        ? permissionGranted
        : await permissionGate!.future;
  }

  @override
  Future<bool> isPermissionPermanentlyDenied() async => permanentlyDenied;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    permanentlyDenied = permanentlyDenyOnRequest;
    return permissionGranted = grantOnRequest;
  }

  @override
  Future<void> initialize({
    ResolutionPreset preset = ResolutionPreset.medium,
  }) async {
    initializeCalls++;
    await initializationGate?.future;
    if (failInitialization) {
      throw const AppException(
        code: ErrorCode.cameraUnavailable,
        userMessage: 'Could not initialize device camera.',
      );
    }
    _previewController = _PreviewController();
  }

  @override
  Future<void> dispose() async {
    disposals++;
    _previewController = null;
  }
}

class _HomeTts extends FakeTtsService {
  bool _speaking = false;

  _HomeTts(super.prefs);

  @override
  bool get isSpeaking => _speaking;

  void setSpeaking(bool value) {
    _speaking = value;
    notifyListeners();
  }

  @override
  Future<void> stop() async => setSpeaking(false);
}

class _HomeCoordinator extends AgentCoordinator {
  int stopCalls = 0;
  int repeatCalls = 0;
  int voiceCalls = 0;
  int cancelCalls = 0;

  _HomeCoordinator({
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
  void stop() {
    stopCalls++;
    super.stop();
  }

  @override
  void cancelActiveWork() {
    cancelCalls++;
    super.cancelActiveWork();
  }

  @override
  Future<void> repeatLast() {
    repeatCalls++;
    return super.repeatLast();
  }

  @override
  Future<void> executeVoiceCommand() async {
    voiceCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _HomeCoordinator coordinator;
  late _HomeCamera camera;
  late _HomeTts tts;
  late FakeOcrService ocr;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'cloud_consent_granted': true,
      'terms_version_accepted': AppConfig.termsVersion,
      'app_language': 'en',
      'auto_read': true,
      'assistance_profile_chosen': true,
      'launch_orientation_count': 3,
      'earcons_enabled': false,
    });
    final prefs = await PreferencesService.create();
    tts = _HomeTts(prefs);
    camera = _HomeCamera();
    ocr = FakeOcrService();
    coordinator = _HomeCoordinator(
      cameraService: camera,
      ttsService: tts,
      speechService: FakeSpeechService(),
      ocrService: ocr,
      hapticService: FakeHapticService(prefs),
      preferencesService: prefs,
      credentialService: CredentialService(),
      logService: DiagnosticLogService(prefs),
      visionApi: FakeVisionApiService(),
    );
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    double width = 800,
    double height = 1200,
    double scale = 1,
    FocusNode? focusNode,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: Focus(
          focusNode: focusNode,
          child: HomeScreen(coordinator: coordinator),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> semanticsTap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pump();
    final node = tester.getSemantics(finder);
    expect(
      node.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
      reason: key,
    );
    final owner = tester.renderObject(finder).owner!.semanticsOwner!;
    owner.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  Future<ByteData?> volumeKey(WidgetTester tester) async {
    final response = Completer<ByteData?>();
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'eyesense/hardware',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('volumeKey'),
      ),
      response.complete,
    );
    await tester.pumpAndSettle();
    return response.future;
  }

  const taskKeys = [
    'action-describe',
    'action-read',
    'action-ask',
    'action-voice',
  ];

  testWidgets(
    'tasks lead Home and keep offsets through states and real results',
    (tester) async {
      await coordinator.preferencesService.applyProfileDefaults(
        AssistanceProfile.lowVision,
      );
      await pumpHome(tester);
      final keys = [...taskKeys, 'action-stop'];
      final idle = {
        for (final key in keys) key: tester.getTopLeft(find.byKey(Key(key))).dy,
      };
      for (var i = 1; i < taskKeys.length; i++) {
        expect(idle[taskKeys[i]], greaterThan(idle[taskKeys[i - 1]]!));
      }
      expect(
        tester.getTopLeft(find.byType(OperationStatusWidget)).dy,
        greaterThan(idle['action-voice']!),
      );
      expect(find.text('What would you like to do?'), findsOneWidget);
      expect(find.text('One picture · Internet needed'), findsOneWidget);
      expect(find.text('One picture · Works offline'), findsOneWidget);
      expect(
        find.text('Ask about a new picture · Internet needed'),
        findsOneWidget,
      );
      expect(
        find.text('Optional · Say “describe scene” or “read text”'),
        findsOneWidget,
      );

      void expectStable() {
        for (final key in keys) {
          expect(
            tester.getTopLeft(find.byKey(Key(key))).dy,
            idle[key],
            reason: key,
          );
        }
      }

      for (final state in [
        OperationState.capturing,
        OperationState.processingCloud,
        OperationState.processingLocal,
        OperationState.listening,
        OperationState.speaking,
        OperationState.error,
        OperationState.idle,
      ]) {
        coordinator.debugSetOperationState(state);
        coordinator.debugSetActiveWork(ActiveWork.describe);
        await tester.pump();
        expectStable();
      }
      coordinator.debugSetActiveWork(null);

      await coordinator.executeDescribe();
      await tester.pumpAndSettle();
      expect(coordinator.lastResultText, contains('clean testing room'));
      expect(find.text(coordinator.lastResultText!), findsOneWidget);
      expectStable();
      expect(
        tester.getTopLeft(find.byType(ResponsePanelWidget)).dy,
        greaterThan(idle['action-voice']!),
      );
      expect(find.text('More detail'), findsNothing);

      ocr.textToReturn = List.filled(
        15,
        'A long recognised document line.',
      ).join(' ');
      await coordinator.executeReadText();
      await tester.pumpAndSettle();
      expect(find.text(ocr.textToReturn), findsOneWidget);
      expectStable();
      expect(
        tester.getTopLeft(find.byKey(const Key('action-preview'))).dy,
        greaterThan(tester.getBottomLeft(find.byType(ResponsePanelWidget)).dy),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('action-repeat'))).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(const Key('action-preview'))).dy,
        ),
      );
    },
  );

  testWidgets(
    'labelled tasks expose tap semantics and invoke real capture actions',
    (tester) async {
      await pumpHome(tester);
      final describe = tester.getSemantics(
        find.byKey(const Key('action-describe')),
      );
      expect(describe.label, 'Describe scene');
      expect(describe.hint, contains('Internet needed'));
      expect(describe.flagsCollection.isButton, isTrue);
      expect(describe.flagsCollection.isEnabled, Tristate.isTrue);

      await semanticsTap(tester, 'action-describe');
      expect(camera.captureCount, 1);
      expect(coordinator.lastResultText, contains('clean testing room'));
      await semanticsTap(tester, 'action-read');
      expect(camera.captureCount, 2);
      expect(coordinator.lastResultText, ocr.textToReturn);
      await semanticsTap(tester, 'action-repeat');
      expect(coordinator.repeatCalls, 1);
      expect(tts.spokenTexts.last, startsWith('Previous result:'));
      await semanticsTap(tester, 'action-voice');
      expect(coordinator.voiceCalls, 1);
      await semanticsTap(tester, 'action-ask');
      expect(find.byType(AskScreen), findsOneWidget);
      expect(
        camera.captureCount,
        2,
        reason: 'Opening Ask must not capture a picture',
      );
    },
  );

  testWidgets(
    'busy tasks lose tap while Stop remains a working semantic action',
    (tester) async {
      await pumpHome(tester);
      coordinator.debugSetOperationState(OperationState.capturing);
      coordinator.debugSetActiveWork(ActiveWork.describe);
      await tester.pump();
      for (final key in taskKeys) {
        final node = tester.getSemantics(find.byKey(Key(key)));
        expect(node.flagsCollection.isEnabled, Tristate.isFalse);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      }
      expect(
        tester.getSemantics(find.byKey(const Key('action-describe'))).label,
        'Describe scene',
      );
      await semanticsTap(tester, 'action-stop');
      expect(coordinator.stopCalls, 1);
      expect(coordinator.state, OperationState.idle);
      expect(tts.spokenTexts, contains('Stopped'));
    },
  );

  testWidgets('new results do not steal focus or scroll to the result', (
    tester,
  ) async {
    final focus = FocusNode();
    await pumpHome(tester, focusNode: focus, width: 320, height: 640);
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasPrimaryFocus, isTrue);
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final offset = scroll.pixels;
    await coordinator.executeDescribe();
    await tester.pumpAndSettle();
    expect(focus.hasPrimaryFocus, isTrue);
    expect(scroll.pixels, offset);
    await tester.pumpWidget(const SizedBox.shrink());
    focus.dispose();
  });

  testWidgets(
    'large text tasks scroll while Stop keeps its size and position',
    (tester) async {
      await pumpHome(tester, width: 320, height: 640, scale: 2);
      final stop = find.byKey(const Key('action-stop'));
      final stopRect = tester.getRect(stop);
      expect(
        stopRect.height,
        greaterThanOrEqualTo(AppTheme.primaryButtonHeight),
      );
      expect(stopRect.bottom, lessThanOrEqualTo(640));
      for (final key in [...taskKeys, 'action-repeat']) {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(tester.getRect(stop), stopRect);
        expect(tester.takeException(), isNull);
      }
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .maxScrollExtent,
        greaterThan(0),
      );
    },
  );

  testWidgets(
    'background double tap, long press and swipes do not run hidden actions',
    (tester) async {
      await pumpHome(tester);
      final heading = find.text('What would you like to do?');
      final mode = coordinator.currentMode;
      await tester.tap(heading);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(heading);
      await tester.pumpAndSettle();
      await tester.longPress(heading);
      await tester.fling(heading, const Offset(-300, 0), 1000);
      await tester.fling(heading, const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(camera.captureCount, 0);
      expect(camera.permissionChecks, 0);
      expect(coordinator.voiceCalls, 0);
      expect(coordinator.stopCalls, 0);
      expect(coordinator.repeatCalls, 0);
      expect(coordinator.currentMode, mode);
      expect(tts.spokenTexts, isEmpty);
    },
  );

  testWidgets(
    'all profiles start without camera initialization or permission checks',
    (tester) async {
      await pumpHome(tester);
      for (final profile in AssistanceProfile.values) {
        await coordinator.preferencesService.applyProfileDefaults(profile);
        await tester.pumpAndSettle();
        expect(camera.initializeCalls, 0);
        expect(camera.permissionChecks, 0);
        expect(camera.permissionRequests, 0);
        expect(find.byType(CameraPreview), findsNothing);
        expect(find.text('Live camera preview'), findsNothing);
        expect(
          find.byKey(const Key('action-preview')),
          profile == AssistanceProfile.screenReader
              ? findsNothing
              : findsOneWidget,
        );
      }
    },
  );

  testWidgets(
    'preview explains permission, can cancel, and shows real initialization failures',
    (tester) async {
      await coordinator.preferencesService.applyProfileDefaults(
        AssistanceProfile.lowVision,
      );
      camera.permissionGranted = false;
      camera.failInitialization = true;
      await pumpHome(tester);
      await semanticsTap(tester, 'action-preview');
      expect(find.text('Camera access'), findsOneWidget);
      expect(
        find.textContaining('This does not take a picture.'),
        findsOneWidget,
      );
      expect(camera.permissionRequests, 0);
      expect(camera.initializeCalls, 0);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(camera.initializeCalls, 0);

      await semanticsTap(tester, 'action-preview');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(camera.permissionRequests, 1);
      expect(camera.initializeCalls, 1);
      expect(find.text('Could not initialize device camera.'), findsOneWidget);
      expect(find.byType(CameraPreview), findsNothing);
      expect(find.text('Live camera preview'), findsNothing);

      camera.failInitialization = false;
      await semanticsTap(tester, 'action-preview');
      expect(camera.initializeCalls, 2);
      expect(find.byType(CameraPreview), findsOneWidget);
      expect(find.text('Live camera preview'), findsOneWidget);
      expect(find.text('Could not initialize device camera.'), findsNothing);
      expect(camera.captureCount, 0);
      camera.controller!.value = camera.controller!.value.copyWith(
        errorDescription: 'Camera disconnected',
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Camera preview unavailable. Camera disconnected'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'preview rejects double starts and stale background initialization',
    (tester) async {
      await coordinator.preferencesService.applyProfileDefaults(
        AssistanceProfile.sightedAssistant,
      );
      await pumpHome(tester);
      camera.initializationGate = Completer<void>();
      final start = tester
          .widget<AccessibleActionButton>(
            find.byKey(const Key('action-preview')),
          )
          .onPressed!;
      start();
      start();
      await tester.pump();
      expect(camera.initializeCalls, 1);
      expect(find.byType(CameraPreview), findsNothing);
      expect(
        tester
            .widget<AccessibleActionButton>(
              find.byKey(const Key('action-preview')),
            )
            .isLoading,
        isTrue,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      camera.initializationGate!.complete();
      await tester.pumpAndSettle();
      expect(
        camera.disposals,
        0,
        reason: 'Suspension belongs to the app-level observer',
      );
      expect(coordinator.cancelCalls, 0);
      expect(find.byType(CameraPreview), findsNothing);
      expect(find.text('Live camera preview'), findsNothing);
      expect(tts.spokenTexts, isEmpty);
      await semanticsTap(tester, 'action-preview');
      expect(camera.initializeCalls, 2);
      expect(find.byType(CameraPreview), findsOneWidget);
    },
  );

  testWidgets('backgrounding invalidates a pending camera permission check', (
    tester,
  ) async {
    await pumpHome(tester);
    camera.permissionGate = Completer<bool>();
    await tester.tap(find.byKey(const Key('action-describe')));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    camera.permissionGate!.complete(true);
    await tester.pumpAndSettle();
    expect(camera.captureCount, 0);
    expect(coordinator.lastResultText, isNull);
    expect(coordinator.cancelCalls, 0);
  });

  testWidgets(
    'permanent camera denial offers visible working app settings recovery',
    (tester) async {
      camera.permissionGranted = false;
      camera.permanentlyDenied = true;
      final settingsMethods = <String>[];
      const permissions = MethodChannel(
        'flutter.baseflow.com/permissions/methods',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        permissions,
        (call) async {
          settingsMethods.add(call.method);
          return true;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          permissions,
          null,
        ),
      );
      await pumpHome(tester);
      await semanticsTap(tester, 'action-describe');
      expect(find.text('Camera permission is off'), findsOneWidget);
      expect(find.text('Open app settings'), findsOneWidget);
      expect(camera.permissionRequests, 0);
      await tester.tap(find.text('Open app settings'));
      await tester.pumpAndSettle();
      expect(settingsMethods, ['openAppSettings']);
      expect(camera.captureCount, 0);
      expect(tts.spokenTexts, isEmpty);
    },
  );

  testWidgets('new permanent denial also opens the recovery dialog', (
    tester,
  ) async {
    camera.permissionGranted = false;
    camera.grantOnRequest = false;
    camera.permanentlyDenyOnRequest = true;
    await pumpHome(tester);
    await semanticsTap(tester, 'action-read');
    expect(find.text('Camera access'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Camera permission is off'), findsOneWidget);
    expect(find.text('Open app settings'), findsOneWidget);
    expect(camera.captureCount, 0);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Camera access was not allowed.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'native volume ignores idle, stops active work once, and cleans up',
    (tester) async {
      await pumpHome(tester);
      await volumeKey(tester);
      expect(coordinator.stopCalls, 0);
      expect(tts.spokenTexts, isEmpty);
      coordinator.debugSetOperationState(OperationState.processingCloud);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeDown);
      expect(
        coordinator.stopCalls,
        0,
        reason: 'No duplicate hardware keyboard listener',
      );
      await volumeKey(tester);
      expect(coordinator.stopCalls, 1);
      expect(coordinator.state, OperationState.idle);
      await volumeKey(tester);
      expect(coordinator.stopCalls, 1);
      tts.setSpeaking(true);
      await tester.pump();
      await volumeKey(tester);
      expect(coordinator.stopCalls, 2);
      expect(tts.isSpeaking, isFalse);
      final speechBeforeDispose = List<String>.of(tts.spokenTexts);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(
        coordinator.cancelCalls,
        3,
        reason: 'Two explicit Stops and silent route disposal',
      );
      expect(tts.spokenTexts, speechBeforeDispose);
      expect(
        await volumeKey(tester),
        isNull,
        reason: 'Native method handler is removed',
      );
      expect(coordinator.stopCalls, 2);
    },
  );

  testWidgets('native volume still stops active work while Ask is open', (
    tester,
  ) async {
    await pumpHome(tester);
    await semanticsTap(tester, 'action-ask');
    coordinator.debugSetOperationState(OperationState.listening);
    await tester.pump();
    await volumeKey(tester);
    expect(coordinator.stopCalls, 1);
    expect(coordinator.state, OperationState.idle);
    expect(tts.spokenTexts, contains('Stopped'));
  });

  testWidgets('Stop cancels a pending permission check before it can capture', (
    tester,
  ) async {
    await pumpHome(tester);
    camera.permissionGate = Completer<bool>();
    await tester.tap(find.byKey(const Key('action-read')));
    await tester.pump();
    await semanticsTap(tester, 'action-stop');
    camera.permissionGate!.complete(true);
    await tester.pumpAndSettle();
    expect(camera.captureCount, 0);
    expect(coordinator.stopCalls, 1);
  });

  testWidgets(
    'launch orientation describes visible tasks, not modes or gestures',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('launch_orientation_count', 0);
      await pumpHome(tester);
      await tester.pumpAndSettle();
      expect(
        tts.spokenTexts.single,
        contains('Choose Describe scene, Read text, or Ask a question'),
      );
      expect(tts.spokenTexts.single, contains('Stop is at the bottom'));
      expect(tts.spokenTexts.single.toLowerCase(), isNot(contains('mode')));
      expect(
        tts.spokenTexts.single.toLowerCase(),
        isNot(contains('double-tap')),
      );
    },
  );
}
