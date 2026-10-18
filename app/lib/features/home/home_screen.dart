import 'package:camera/camera.dart';
import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/core/theme/app_theme.dart';
import 'package:eyesense/features/ask/ask_screen.dart';
import 'package:eyesense/features/settings/settings_screen.dart';
import 'package:eyesense/models/app_operation.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:eyesense/widgets/accessible_action_button.dart';
import 'package:eyesense/widgets/operation_status.dart';
import 'package:eyesense/widgets/response_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  final AgentCoordinator coordinator;

  const HomeScreen({super.key, required this.coordinator});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final FocusNode _resultFocus = FocusNode();
  final Map<int, Offset> _pointerOrigin = <int, Offset>{};
  int _peakPointers = 0;
  bool _pointerMoved = false;
  String? _lastFocusedResult;
  static const _hardware = MethodChannel('eyesense/hardware');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hardware.setMethodCallHandler((call) async {
      if (call.method == 'volumeKey') widget.coordinator.stop();
    });
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOrient());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _resultFocus.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerOrigin[event.pointer] = event.position;
    if (_pointerOrigin.length > _peakPointers) {
      _peakPointers = _pointerOrigin.length;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final origin = _pointerOrigin[event.pointer];
    if (origin != null && (event.position - origin).distance > 32) {
      _pointerMoved = true;
    }
  }

  void _onPointerEnd(PointerEvent event) {
    _pointerOrigin.remove(event.pointer);
    if (_pointerOrigin.isNotEmpty) return;
    final peak = _peakPointers;
    final moved = _pointerMoved;
    _peakPointers = 0;
    _pointerMoved = false;
    if (moved) return;
    if (peak >= 3) {
      widget.coordinator.repeatLast();
    } else if (peak == 2) {
      widget.coordinator.stop();
    }
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp ||
        event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
      widget.coordinator.stop();
      return false;
    }
    return false;
  }

  Future<void> _maybeOrient() async {
    final prefs = widget.coordinator.preferencesService;
    if (prefs.launchOrientationCount >= 3) return;
    await prefs.incrementLaunchOrientationCount();
    if (!mounted) return;
    widget.coordinator.speechFeedbackCoordinator.speakStatus(
      'EyeSense is ready. Mode is ${widget.coordinator.currentMode.displayName}. '
      'Double-tap to run it, or use the buttons.',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      widget.coordinator.suspend();
    }
  }

  Future<bool> _ensureCameraPermission() async {
    final camera = widget.coordinator.cameraService;
    if (await camera.hasPermission()) return true;
    if (!mounted) return false;
    if (await camera.isPermissionPermanentlyDenied()) {
      await widget.coordinator.speechFeedbackCoordinator.interruptWith(
        'Camera permission is off. Enable it in system settings.',
      );
      return false;
    }
    if (!mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Camera access'),
        content: const Text(
          'EyeSense needs the camera to take one picture. The permission dialog comes next. Nothing else starts until you allow it.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    if (proceed != true) return false;
    return camera.requestPermission();
  }

  Future<void> _runCapture(Future<void> Function() action) async {
    final granted = await _ensureCameraPermission();
    if (!granted || !mounted) return;
    await action();
  }

  void _openAsk() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AskScreen(coordinator: widget.coordinator)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eyeColors;
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.coordinator,
        widget.coordinator.ttsService,
        widget.coordinator.preferencesService,
      ]),
      builder: (context, _) {
        final coordinator = widget.coordinator;
        final state = coordinator.state;
        final isBusy = state != OperationState.idle && state != OperationState.error;
        final stopEnabled = isBusy || coordinator.ttsService.isSpeaking;
        final result = coordinator.lastResultText;
        if (result != null && result != _lastFocusedResult) {
          _lastFocusedResult = result;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _resultFocus.requestFocus();
          });
        }

        final showPreview = coordinator.preferencesService.assistanceProfile == AssistanceProfile.lowVision;

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
                    icon: const Icon(Icons.settings, size: AppTheme.iconPrimary),
                    tooltip: 'Settings',
                    onPressed: () => _openSettings(coordinator),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Semantics(
              customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
                CustomSemanticsAction(label: 'Run the current mode'): coordinator.runCurrentMode,
                CustomSemanticsAction(label: 'Stop'): coordinator.stop,
                CustomSemanticsAction(label: 'Next mode'): () => coordinator.cycleMode(1),
                CustomSemanticsAction(label: 'Previous mode'): () => coordinator.cycleMode(-1),
                CustomSemanticsAction(label: 'Start voice command'): coordinator.executeVoiceCommand,
                CustomSemanticsAction(label: 'Repeat last result'): coordinator.repeatLast,
              },
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerEnd,
                onPointerCancel: _onPointerEnd,
                child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTap: coordinator.runCurrentMode,
                onLongPress: coordinator.executeVoiceCommand,
                onSecondaryTap: coordinator.stop,
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -200) coordinator.cycleMode(1);
                  if (velocity > 200) coordinator.cycleMode(-1);
                },
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        'EyeSense is a supplementary visual assistant. It is not a cane, guide dog, or mobility aid.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.defaultPadding, vertical: 12),
                        child: Column(
                          children: [
                            OperationStatusWidget(
                              state: state,
                              errorMessage: coordinator.errorMessage,
                              onDismissError: coordinator.dismissError,
                            ),
                            const SizedBox(height: AppTheme.elementSpacing),
                            if (showPreview) _reservedPreview(coordinator, colors),
                            ResponsePanelWidget(
                              resultText: coordinator.lastResultText,
                              sceneResult: coordinator.lastSceneResult,
                              presentationRecord: coordinator.lastPresentation,
                              focusNode: _resultFocus,
                              onMoreDetail: coordinator.lastResultText == null ? null : coordinator.speakMoreDetail,
                            ),
                            const SizedBox(height: 24),
                            AccessibleActionButton(
                              key: const Key('action-voice'),
                              label: 'Start voice command',
                              icon: Icons.mic,
                              isLoading: coordinator.activeWork == ActiveWork.voiceCommand,
                              semanticHint: 'Start listening for a short request',
                              onPressed: isBusy ? null : coordinator.executeVoiceCommand,
                            ),
                            const SizedBox(height: AppTheme.elementSpacing),
                            AccessibleActionButton(
                              key: const Key('action-describe'),
                              label: 'Describe scene',
                              icon: Icons.visibility_outlined,
                              isSecondary: true,
                              isLoading: coordinator.activeWork == ActiveWork.describe,
                              semanticHint: 'Take a picture and describe visible information',
                              onPressed: isBusy ? null : () => _runCapture(coordinator.executeDescribe),
                            ),
                            const SizedBox(height: AppTheme.elementSpacing),
                            AccessibleActionButton(
                              key: const Key('action-read'),
                              label: 'Read text',
                              icon: Icons.text_snippet_outlined,
                              isSecondary: true,
                              isLoading: coordinator.activeWork == ActiveWork.readText,
                              semanticHint: 'Take a picture and read recognised words',
                              onPressed: isBusy ? null : () => _runCapture(coordinator.executeReadText),
                            ),
                            const SizedBox(height: AppTheme.elementSpacing),
                            AccessibleActionButton(
                              key: const Key('action-ask'),
                              label: 'Ask a question',
                              icon: Icons.chat_bubble_outline,
                              isSecondary: true,
                              isLoading: coordinator.activeWork == ActiveWork.ask,
                              semanticHint: 'Ask about a fresh camera image',
                              onPressed: isBusy ? null : _openAsk,
                            ),
                            const SizedBox(height: AppTheme.elementSpacing),
                            AccessibleActionButton(
                              key: const Key('action-repeat'),
                              label: 'Repeat last response',
                              icon: Icons.replay,
                              isSecondary: true,
                              semanticHint: 'Hear previous information again',
                              onPressed: coordinator.lastResultText != null ? coordinator.repeatLast : null,
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
                        onPressed: stopEnabled ? coordinator.stop : null,
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _reservedPreview(AgentCoordinator coordinator, EyeSenseColors colors) {
    return ExcludeSemantics(
      child: Container(
        height: 140,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: coordinator.cameraService.isInitialized && coordinator.cameraService.controller != null
            ? CameraPreview(coordinator.cameraService.controller!)
            : Center(child: Text('Camera preview', style: TextStyle(color: colors.textSecondary, fontSize: 14))),
      ),
    );
  }

  Future<void> _openSettings(AgentCoordinator coordinator) async {
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
    coordinator.refreshVisionProvider();
  }
}
