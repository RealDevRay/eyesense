import 'package:camera/camera.dart';
import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:eyesense/core/theme/app_theme.dart';
import 'package:eyesense/features/ask/ask_screen.dart';
import 'package:eyesense/features/settings/settings_screen.dart';
import 'package:eyesense/models/app_operation.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:eyesense/widgets/accessible_action_button.dart';
import 'package:eyesense/widgets/operation_status.dart';
import 'package:eyesense/widgets/response_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  final AgentCoordinator coordinator;

  const HomeScreen({super.key, required this.coordinator});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _hardware = MethodChannel('eyesense/hardware');
  bool _cameraRequestPending = false;
  bool _openingPreview = false;
  bool _previewOpen = false;
  bool _foreground = true;
  int _cameraRequestGeneration = 0;
  String? _cameraError;

  bool get _isBusy {
    final state = widget.coordinator.state;
    return state != OperationState.idle && state != OperationState.error;
  }

  bool get _canStop =>
      _isBusy ||
      _cameraRequestPending ||
      widget.coordinator.ttsService.isSpeaking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hardware.setMethodCallHandler((call) async {
      if (mounted && call.method == 'volumeKey' && _canStop) {
        _stop();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOrient());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hardware.setMethodCallHandler(null);
    _cameraRequestGeneration++;
    widget.coordinator.cancelActiveWork();
    super.dispose();
  }

  void _stop() {
    setState(() => _cameraRequestGeneration++);
    widget.coordinator.stop();
  }

  Future<void> _maybeOrient() async {
    if (!mounted) return;
    final prefs = widget.coordinator.preferencesService;
    if (prefs.launchOrientationCount >= 3) return;
    await prefs.incrementLaunchOrientationCount();
    if (!mounted || !_foreground) return;
    widget.coordinator.speechFeedbackCoordinator.speakStatus(
      'EyeSense is ready. Choose Describe scene, Read text, or Ask a question. '
      'You can also use the Start voice command button. Stop is at the bottom.',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App-level lifecycle handling owns suspension and camera disposal.
      // Only invalidate Home's pending permission/preview UI here.
      setState(() {
        _foreground = false;
        _cameraRequestGeneration++;
        _previewOpen = false;
        _cameraError = null;
      });
    }
  }

  bool _requestIsCurrent(int generation) =>
      mounted &&
      _foreground &&
      generation == _cameraRequestGeneration &&
      ModalRoute.of(context)?.isCurrent == true;

  Future<void> _showCameraSettings(int generation) async {
    if (!_requestIsCurrent(generation)) return;
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Camera permission is off'),
        content: const Text(
          'Enable camera access in app settings, then return and choose your task again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open app settings'),
          ),
        ],
      ),
    );

    if (openSettings != true || !_requestIsCurrent(generation)) return;
    final opened = await openAppSettings();

    if (!opened && _requestIsCurrent(generation)) {
      setState(
        () => _cameraError = 'Could not open app settings. Enable camera access in your device settings.',
      );
    }
  }

  Future<bool> _ensureCameraPermission(
    int generation, {
    required bool preview,
  }) async {
    final camera = widget.coordinator.cameraService;
    final granted = await camera.hasPermission();
    if (!_requestIsCurrent(generation)) return false;
    if (granted) return true;
    final permanentlyDenied = await camera.isPermissionPermanentlyDenied();
    if (!mounted || !_requestIsCurrent(generation)) return false;
    if (permanentlyDenied) {
      await _showCameraSettings(generation);
      return false;
    }
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Camera access'),
        content: Text(
          preview
              ? 'EyeSense needs the camera to show a live preview for aiming. This does not take a picture. The permission dialog comes next.'
              : 'EyeSense needs the camera to take one picture. The permission dialog comes next. Nothing else starts until you allow it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (proceed != true || !_requestIsCurrent(generation)) return false;
    final allowed = await camera.requestPermission();
    if (!_requestIsCurrent(generation)) return false;
    if (!allowed) {
      setState(
        () => _cameraError = 'Camera access was not allowed. Choose a task or open the preview to try again.',
      );
      final permanentlyDenied = await camera.isPermissionPermanentlyDenied();
      if (_requestIsCurrent(generation) && permanentlyDenied) {
        await _showCameraSettings(generation);
      }
    }
    return allowed;
  }

  Future<void> _runCapture(
    Future<void> Function() action, {
    bool preview = false,
  }) async {
    if (_cameraRequestPending || _isBusy || !_foreground) return;
    final generation = ++_cameraRequestGeneration;
    setState(() {
      _cameraRequestPending = true;
      _openingPreview = preview;
      _cameraError = null;
    });
    try {
      final granted = await _ensureCameraPermission(
        generation,
        preview: preview,
      );
      if (!granted || !_requestIsCurrent(generation)) return;
      await action();
      if (preview && _requestIsCurrent(generation)) {
        final camera = widget.coordinator.cameraService;
        if (!camera.isInitialized ||
            camera.controller?.value.isInitialized != true) {
          throw const AppException(
            code: ErrorCode.cameraUnavailable,
            userMessage: 'Camera preview is unavailable. Try opening it again.',
          );
        }
        setState(() => _previewOpen = true);
      }
    } catch (error) {
      if (_requestIsCurrent(generation)) {
        setState(
          () => _cameraError = error is AppException
              ? error.userMessage
              : 'Could not open the camera. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _cameraRequestPending = false;
          _openingPreview = false;
        });
      }
    }
  }

  void _openAsk() {
    _cameraRequestGeneration++;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AskScreen(coordinator: widget.coordinator),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.coordinator,
        widget.coordinator.ttsService,
        widget.coordinator.preferencesService,
      ]),
      builder: (context, _) {
        final coordinator = widget.coordinator;
        final tasksEnabled = !_isBusy && !_cameraRequestPending;
        final profile = coordinator.preferencesService.assistanceProfile;
        final offerPreview =
            profile == AssistanceProfile.lowVision ||
            profile == AssistanceProfile.sightedAssistant;
        final controller = coordinator.cameraService.controller;
        final previewReady =
            _previewOpen &&
            coordinator.cameraService.isInitialized &&
            controller != null &&
            controller.value.isInitialized;

        return Scaffold(
          appBar: AppBar(
            title: const Text('EyeSense'),
            actions: [
              Semantics(
                button: true,
                label: 'Settings',
                hint: 'Change speech, language and connection preferences',
                onTap: () => _openSettings(coordinator),
                child: ExcludeSemantics(
                  child: IconButton(
                    icon: const Icon(
                      Icons.settings,
                      size: AppTheme.iconPrimary,
                    ),
                    tooltip: 'Settings',
                    onPressed: () => _openSettings(coordinator),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.defaultPadding,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'What would you like to do?',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        const SizedBox(height: AppTheme.elementSpacing),
                        AccessibleActionButton(
                          key: const Key('action-describe'),
                          label: 'Describe scene',
                          subtitle: 'One picture · Internet needed',
                          icon: Icons.visibility_outlined,
                          isLoading:
                              coordinator.activeWork == ActiveWork.describe,
                          semanticHint: 'Take one picture and describe visible information. Internet needed.',
                          onPressed: tasksEnabled
                              ? () => _runCapture(coordinator.executeDescribe)
                              : null,
                        ),
                        const SizedBox(height: AppTheme.elementSpacing),
                        AccessibleActionButton(
                          key: const Key('action-read'),
                          label: 'Read text',
                          subtitle: 'One picture · Works offline',
                          icon: Icons.text_snippet_outlined,
                          isSecondary: true,
                          isLoading:
                              coordinator.activeWork == ActiveWork.readText,
                          semanticHint: 'Take one picture and read recognised words. Works offline.',
                          onPressed: tasksEnabled
                              ? () => _runCapture(coordinator.executeReadText)
                              : null,
                        ),
                        const SizedBox(height: AppTheme.elementSpacing),
                        AccessibleActionButton(
                          key: const Key('action-ask'),
                          label: 'Ask a question',
                          subtitle: 'Ask about a new picture · Internet needed',
                          icon: Icons.chat_bubble_outline,
                          isSecondary: true,
                          isLoading: coordinator.activeWork == ActiveWork.ask,
                          semanticHint: 'Open questions about a new camera picture. Internet needed.',
                          onPressed: tasksEnabled ? _openAsk : null,
                        ),
                        const SizedBox(height: AppTheme.elementSpacing),
                        AccessibleActionButton(
                          key: const Key('action-voice'),
                          label: 'Start voice command',
                          subtitle:
                              'Optional · Say “describe scene” or “read text”',
                          icon: Icons.mic,
                          isSecondary: true,
                          isLoading:
                              coordinator.activeWork == ActiveWork.voiceCommand,
                          semanticHint: 'Optional. Start listening; say describe scene or read text.',
                          onPressed: tasksEnabled
                              ? coordinator.executeVoiceCommand
                              : null,
                        ),
                        const SizedBox(height: 24),
                        OperationStatusWidget(
                          announceChanges:
                              !coordinator.preferencesService.autoRead &&
                              coordinator.state == OperationState.error,
                          state: coordinator.state,
                          errorMessage: coordinator.errorMessage,
                          onDismissError: coordinator.dismissError,
                        ),
                        if (_cameraError != null) ...[
                          const SizedBox(height: AppTheme.elementSpacing),
                          Semantics(
                            liveRegion: true,
                            child: Text(_cameraError!),
                          ),
                        ],
                        const SizedBox(height: AppTheme.elementSpacing),
                        ResponsePanelWidget(
                          resultText: coordinator.lastResultText,
                          sceneResult: coordinator.lastSceneResult,
                          presentationRecord: coordinator.lastPresentation,
                        ),
                        if (offerPreview) ...[
                          const SizedBox(height: AppTheme.elementSpacing),
                          AccessibleActionButton(
                            key: const Key('action-preview'),
                            label: 'Open camera preview',
                            subtitle: 'Optional · Helps you aim the camera',
                            icon: Icons.camera_alt_outlined,
                            isSecondary: true,
                            isLoading: _openingPreview,
                            semanticHint: 'Show a live camera preview for aiming. Does not take a picture.',
                            onPressed: tasksEnabled && !previewReady
                                ? () => _runCapture(
                                    () =>
                                        coordinator.cameraService.initialize(),
                                    preview: true,
                                  )
                                : null,
                          ),
                          if (previewReady) ...[
                            const SizedBox(height: 12),
                            const Text('Live camera preview'),
                            const SizedBox(height: 8),
                            ValueListenableBuilder<CameraValue>(
                              valueListenable: controller,
                              builder: (context, value, _) => value.hasError
                                  ? Text(
                                      'Camera preview unavailable. ${value.errorDescription ?? 'Choose a task to try again.'}',
                                    )
                                  : ExcludeSemantics(
                                      child: SizedBox(
                                        height: 180,
                                        child: CameraPreview(controller),
                                      ),
                                    ),
                            ),
                          ],
                        ],
                        const SizedBox(height: AppTheme.elementSpacing),
                        AccessibleActionButton(
                          key: const Key('action-repeat'),
                          label: 'Repeat last response',
                          icon: Icons.replay,
                          isSecondary: true,
                          semanticHint: 'Hear previous information again',
                          onPressed:
                              tasksEnabled && coordinator.lastResultText != null
                              ? coordinator.repeatLast
                              : null,
                        ),
                        const SizedBox(height: AppTheme.elementSpacing),
                        Text(
                          'EyeSense is a supplementary visual assistant. It is not a cane, guide dog, or mobility aid.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: AccessibleActionButton(
                    key: const Key('action-stop'),
                    label: 'Stop',
                    icon: Icons.stop_circle_outlined,
                    isDestructive: true,
                    semanticHint: 'Stop listening, processing or playback',
                    onPressed: _canStop ? _stop : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSettings(AgentCoordinator coordinator) async {
    _cameraRequestGeneration++;
    coordinator.cancelActiveWork();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          preferencesService: coordinator.preferencesService,
          credentialService: coordinator.credentialService,
          logService: coordinator.logService,
          coordinator: coordinator,
        ),
      ),
    );
    if (mounted) coordinator.refreshVisionProvider();
  }
}
