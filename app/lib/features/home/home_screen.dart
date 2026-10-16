import 'package:camera/camera.dart';
import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/core/theme/app_theme.dart';
import 'package:eyesense/features/settings/settings_screen.dart';
import 'package:eyesense/models/app_operation.dart';
import 'package:eyesense/widgets/accessible_action_button.dart';
import 'package:eyesense/widgets/operation_status.dart';
import 'package:eyesense/widgets/response_panel.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  final AgentCoordinator coordinator;

  const HomeScreen({super.key, required this.coordinator});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _questionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Camera is initialized lazily when user activates a capture task
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _questionController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      widget.coordinator.stop();
      widget.coordinator.cameraService.dispose();
    }
  }

  void _showAskDialog() {
    _questionController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text(
          'Ask a Visual Question',
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Takes a fresh camera image and answers your question.',
              style: TextStyle(color: Theme.of(ctx).textTheme.bodyMedium?.color),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _questionController,
              autofocus: true,
              style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
              decoration: const InputDecoration(
                labelText: 'Question (e.g. Where is the door?)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actionsOverflowButtonSpacing: 10,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.primary,
              side: BorderSide(color: Theme.of(ctx).colorScheme.primary),
            ),
            icon: const Icon(Icons.mic, size: 20),
            label: const Text('Voice Ask'),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.coordinator.startVoiceAsk();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.primary,
              foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
            ),
            onPressed: () {
              final q = _questionController.text.trim();
              if (q.isNotEmpty) {
                Navigator.of(ctx).pop();
                widget.coordinator.executeAskQuestion(q);
              }
            },
            child: const Text('Submit Question'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.coordinator,
      builder: (context, _) {
        final coordinator = widget.coordinator;
        final state = coordinator.state;
        final isBusy = state != OperationState.idle && state != OperationState.error;
        final isSpeaking = coordinator.speechFeedbackCoordinator.isSpeaking;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EyeSense',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, letterSpacing: 0.5),
                ),
                Text(
                  'Your world, described.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            actions: [
              // 8. Settings action in header
              Semantics(
                label: 'Settings',
                hint: 'Change speech, language and connection preferences',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.settings, size: 30),
                  tooltip: 'Settings',
                  onPressed: () async {
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
                  },
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.defaultPadding,
                vertical: 12,
              ),
              child: Column(
                children: [
                  // Optional preview (excluded from primary accessibility traversal)
                  if (coordinator.cameraService.isInitialized)
                    ExcludeSemantics(
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(coordinator.cameraService.controller!),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.videocam, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Live Preview',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 1. Heading and Brief Status
                  OperationStatusWidget(
                    state: state,
                    errorMessage: coordinator.errorMessage,
                  ),
                  const SizedBox(height: AppTheme.elementSpacing),

                  // 7. Persistent Operation Control Area (Stop button when active or speaking)
                  if (isBusy || isSpeaking) ...[
                    AccessibleActionButton(
                      label: 'Stop current task',
                      icon: Icons.stop_circle_outlined,
                      isDestructive: true,
                      semanticHint: 'Stop listening, processing or playback',
                      onPressed: coordinator.stop,
                    ),
                    const SizedBox(height: AppTheme.elementSpacing),
                  ],

                  // 2. Start voice command (FIRST primary action in reading order)
                  AccessibleActionButton(
                    label: 'Start voice command',
                    icon: Icons.mic,
                    isLoading: state == OperationState.listening,
                    semanticHint: 'Start listening for a short request',
                    onPressed: isBusy ? null : coordinator.executeVoiceCommand,
                  ),
                  const SizedBox(height: AppTheme.elementSpacing),

                  // 3. Describe scene
                  AccessibleActionButton(
                    label: 'Describe scene',
                    icon: Icons.visibility_outlined,
                    isSecondary: true,
                    isLoading: state == OperationState.capturing || state == OperationState.processingCloud,
                    semanticHint: 'Take a picture and describe visible information',
                    onPressed: isBusy ? null : coordinator.executeDescribe,
                  ),
                  const SizedBox(height: AppTheme.elementSpacing),

                  // 4. Read text
                  AccessibleActionButton(
                    label: 'Read text',
                    icon: Icons.text_snippet_outlined,
                    isSecondary: true,
                    isLoading: state == OperationState.processingLocal,
                    semanticHint: 'Take a picture and read recognised words',
                    onPressed: isBusy ? null : coordinator.executeReadText,
                  ),
                  const SizedBox(height: AppTheme.elementSpacing),

                  // 5. Ask a question
                  AccessibleActionButton(
                    label: 'Ask a question',
                    icon: Icons.chat_bubble_outline,
                    isSecondary: true,
                    semanticHint: 'Ask about a fresh camera image',
                    onPressed: isBusy ? null : _showAskDialog,
                  ),
                  const SizedBox(height: AppTheme.elementSpacing),

                  // 6. Repeat last response
                  AccessibleActionButton(
                    label: 'Repeat last response',
                    icon: Icons.replay,
                    isSecondary: true,
                    semanticHint: 'Hear previous information again',
                    onPressed: coordinator.lastResultText != null ? coordinator.repeatLast : null,
                  ),
                  const SizedBox(height: AppTheme.elementSpacing),

                  // Response details panel
                  if (coordinator.lastResultText != null || coordinator.lastPresentation != null)
                    ResponsePanelWidget(
                      resultText: coordinator.lastResultText,
                      sceneResult: coordinator.lastSceneResult,
                      presentationRecord: coordinator.lastPresentation,
                      onRepeat: coordinator.repeatLast,
                      onStop: coordinator.stop,
                      isSpeaking: isSpeaking,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
