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

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _questionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.coordinator.cameraService.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  void _showAskDialog() {
    _questionController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceNavy,
        title: const Text('Ask a Visual Question', style: TextStyle(color: AppTheme.textNearWhite)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Capture a new image and answer a question grounded in the image.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _questionController,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textNearWhite),
              decoration: const InputDecoration(
                labelText: 'Question (e.g. Where is the door?)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.tealAccent,
              foregroundColor: AppTheme.backgroundNavy,
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
              backgroundColor: AppTheme.tealLight,
              foregroundColor: AppTheme.backgroundNavy,
            ),
            onPressed: () {
              final q = _questionController.text.trim();
              if (q.isNotEmpty) {
                Navigator.of(ctx).pop();
                widget.coordinator.executeAskQuestion(q);
              }
            },
            child: const Text('Ask Question'),
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

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EyeSense',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 0.5),
                ),
                Text(
                  'Your world, described.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.tealLight),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, size: 28),
                tooltip: 'Settings',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                        preferencesService: coordinator.preferencesService,
                        credentialService: coordinator.credentialService,
                        logService: coordinator.logService,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // Camera preview box (bounded, non-obscuring)
                  if (coordinator.cameraService.isInitialized)
                    Container(
                      height: 140,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.surfaceVariant, width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CameraPreview(coordinator.cameraService.controller!),
                    ),

                  // Status bar
                  OperationStatusWidget(
                    state: state,
                    errorMessage: coordinator.errorMessage,
                  ),
                  const SizedBox(height: 12),

                  // Response and playback panel
                  if (coordinator.lastResultText != null)
                    Expanded(
                      child: SingleChildScrollView(
                        child: ResponsePanelWidget(
                          resultText: coordinator.lastResultText,
                          sceneResult: coordinator.lastSceneResult,
                          onRepeat: coordinator.repeatLast,
                          onStop: coordinator.stop,
                          isSpeaking: coordinator.ttsService.isSpeaking,
                        ),
                      ),
                    )
                  else
                    const Spacer(),

                  const SizedBox(height: 12),

                  // Stop action prominent during operation or speech
                  if (isBusy || coordinator.ttsService.isSpeaking)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AccessibleActionButton(
                        label: 'Stop',
                        icon: Icons.stop_circle_outlined,
                        isDestructive: true,
                        semanticHint: 'Immediately stops speech and cancels operation',
                        onPressed: coordinator.stop,
                      ),
                    ),

                  // Primary Core Actions
                  AccessibleActionButton(
                    label: 'Describe',
                    icon: Icons.visibility_outlined,
                    isLoading: state == OperationState.capturing || state == OperationState.processingCloud,
                    semanticHint: 'Takes a picture and describes the indoor scene',
                    onPressed: isBusy ? null : coordinator.executeDescribe,
                  ),
                  const SizedBox(height: 12),

                  AccessibleActionButton(
                    label: 'Read Text',
                    icon: Icons.text_snippet_outlined,
                    isSecondary: true,
                    isLoading: state == OperationState.processingLocal,
                    semanticHint: 'Recognizes on-device visible text and reads it aloud',
                    onPressed: isBusy ? null : coordinator.executeReadText,
                  ),
                  const SizedBox(height: 12),

                  AccessibleActionButton(
                    label: 'Ask',
                    icon: Icons.chat_bubble_outline,
                    isSecondary: true,
                    semanticHint: 'Ask a voice or typed question about what you point at',
                    onPressed: isBusy ? null : _showAskDialog,
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
