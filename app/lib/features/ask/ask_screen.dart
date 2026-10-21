import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/models/app_operation.dart';
import 'package:eyesense/widgets/accessible_action_button.dart';
import 'package:eyesense/widgets/operation_status.dart';
import 'package:eyesense/widgets/response_panel.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AskScreen extends StatefulWidget {
  final AgentCoordinator coordinator;

  const AskScreen({super.key, required this.coordinator});

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final TextEditingController _question = TextEditingController();
  String? _submittedQuestion;
  String? _cameraError;
  bool _preparing = false;
  bool _ownsWork = false;
  int _requestGeneration = 0;

  bool get _isBusy {
    final coordinator = widget.coordinator;
    return _preparing ||
        (coordinator.state != OperationState.idle &&
            coordinator.state != OperationState.error) ||
        coordinator.ttsService.isSpeaking;
  }

  void _cancelOwnedWork() {
    _requestGeneration++;
    final coordinator = widget.coordinator;
    final shouldCancel =
        _ownsWork &&
        (_preparing ||
            coordinator.activeWork == ActiveWork.ask ||
            coordinator.state == OperationState.listening ||
            coordinator.state == OperationState.speaking ||
            coordinator.ttsService.isSpeaking);
    _ownsWork = false;
    _preparing = false;
    if (shouldCancel) coordinator.cancelActiveWork();
  }

  @override
  void dispose() {
    _cancelOwnedWork();
    _question.dispose();
    super.dispose();
  }

  bool _requestIsCurrent(int request) =>
      mounted &&
      request == _requestGeneration &&
      ModalRoute.of(context)?.isCurrent == true;

  Future<void> _showCameraSettings(int request) async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera permission is off'),
        scrollable: true,
        content: const Text(
          'Enable camera access in app settings, then return and choose Speak or Submit again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open app settings'),
          ),
        ],
      ),
    );
    if (openSettings != true || !_requestIsCurrent(request)) return;
    final opened = await openAppSettings();
    if (!opened && _requestIsCurrent(request)) {
      setState(
        () => _cameraError = 'Could not open app settings. Enable camera access in your device settings.',
      );
    }
  }

  Future<bool> _ensureCameraPermission(int request) async {
    final camera = widget.coordinator.cameraService;
    final granted = await camera.hasPermission();
    if (!_requestIsCurrent(request)) return false;
    if (granted) return true;
    final permanentlyDenied = await camera.isPermissionPermanentlyDenied();
    if (!mounted || !_requestIsCurrent(request)) return false;
    if (permanentlyDenied) {
      await _showCameraSettings(request);
      return false;
    }
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera access'),
        content: const Text(
          'EyeSense needs the camera to take one picture for your question. The permission dialog comes next.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (!_requestIsCurrent(request) || proceed != true) {
      return false;
    }
    final allowed = await camera.requestPermission();
    if (!_requestIsCurrent(request)) return false;
    if (!allowed) {
      setState(
        () => _cameraError = 'Camera access was not allowed. Choose Speak or Submit to try again.',
      );
      final permanentlyDenied = await camera.isPermissionPermanentlyDenied();
      if (_requestIsCurrent(request) && permanentlyDenied) {
        await _showCameraSettings(request);
      }
    }
    return allowed;
  }

  Future<void> _runAsk(Future<void> Function() action) async {
    if (!mounted || _isBusy || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final request = ++_requestGeneration;
    setState(() {
      _preparing = true;
      _cameraError = null;
    });
    try {
      final granted = await _ensureCameraPermission(request);
      if (!mounted || !_requestIsCurrent(request) || !granted) return;
      FocusScope.of(context).unfocus();
      // Own the work before the coordinator's first asynchronous state change.
      _ownsWork = true;
      await action();
    } finally {
      if (mounted && request == _requestGeneration) {
        setState(() => _preparing = false);
      }
    }
  }

  Future<void> _speak() => _runAsk(() {
    setState(() => _submittedQuestion = null);
    return widget.coordinator.startVoiceAsk();
  });

  Future<void> _submit() async {
    final text = _question.text.trim();
    if (text.isEmpty) return;
    await _runAsk(() {
      setState(() => _submittedQuestion = text);
      return widget.coordinator.executeAskQuestion(text);
    });
  }

  Future<void> _repeat() async {
    if (!mounted || _isBusy) return;
    _ownsWork = true;
    await widget.coordinator.repeatLast();
  }

  void _stop() {
    _requestGeneration++;
    setState(() => _preparing = false);
    widget.coordinator.stop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.coordinator,
        widget.coordinator.ttsService,
      ]),
      builder: (context, _) {
        final coordinator = widget.coordinator;
        final busy = _isBusy;
        final state =
            coordinator.ttsService.isSpeaking &&
                (coordinator.state == OperationState.idle ||
                    coordinator.state == OperationState.error)
            ? OperationState.speaking
            : coordinator.state;
        final length = _question.text.characters.length;
        final hasResult = coordinator.lastResultText?.isNotEmpty == true;
        return PopScope<void>(
          onPopInvokedWithResult: (didPop, _) {
            // Dispose waits for the exit animation; invalidate pending work now.
            if (didPop) _cancelOwnedWork();
          },
          child: Scaffold(
            appBar: AppBar(title: const Text('Ask a question')),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Speak or type a question. EyeSense takes one picture and uses the internet to answer.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        OperationStatusWidget(
                          announceChanges:
                              _cameraError != null ||
                              (!coordinator.preferencesService.autoRead &&
                                  state == OperationState.error),
                          state: _cameraError == null
                              ? state
                              : OperationState.error,
                          errorMessage:
                              _cameraError ?? coordinator.errorMessage,
                          onDismissError: _cameraError == null
                              ? coordinator.dismissError
                              : () => setState(() => _cameraError = null),
                        ),
                        const SizedBox(height: 16),
                        AccessibleActionButton(
                          key: const Key('ask-speak'),
                          label: 'Speak the question',
                          icon: Icons.mic,
                          semanticHint: 'Start listening for your question',
                          onPressed: busy ? null : _speak,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _question,
                          enabled: !busy,
                          autofocus: false,
                          maxLength: AppConfig.maxQuestionCharacters,
                          minLines: 2,
                          maxLines: 4,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Or type a question',
                            border: OutlineInputBorder(),
                            counterText: '',
                          ),
                        ),
                        Semantics(
                          child: Text(
                            '$length of ${AppConfig.maxQuestionCharacters} characters',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AccessibleActionButton(
                          key: const Key('ask-submit'),
                          label: 'Submit question',
                          icon: Icons.send_outlined,
                          isSecondary: true,
                          semanticHint:
                              'Take one picture and answer your typed question',
                          onPressed: busy || _question.text.trim().isEmpty
                              ? null
                              : _submit,
                        ),
                        if (_submittedQuestion != null) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Your question: $_submittedQuestion',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                        const SizedBox(height: 16),
                        ResponsePanelWidget(
                          resultText: coordinator.lastResultText,
                          sceneResult: coordinator.lastSceneResult,
                          presentationRecord: coordinator.lastPresentation,
                        ),
                        if (hasResult) ...[
                          const SizedBox(height: 16),
                          AccessibleActionButton(
                            key: const Key('ask-repeat'),
                            label: 'Repeat response',
                            icon: Icons.replay,
                            isSecondary: true,
                            semanticHint: 'Read the response aloud again',
                            onPressed: busy ? null : _repeat,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: AccessibleActionButton(
                      key: const Key('ask-stop'),
                      label: 'Stop',
                      icon: Icons.stop_circle_outlined,
                      isDestructive: true,
                      semanticHint: 'Stop listening, processing or playback',
                      onPressed: busy ? _stop : null,
                    ),
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
