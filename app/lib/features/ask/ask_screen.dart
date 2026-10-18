import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/core/config/app_config.dart';
import 'package:flutter/material.dart';

class AskScreen extends StatefulWidget {
  final AgentCoordinator coordinator;

  const AskScreen({super.key, required this.coordinator});

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final TextEditingController _question = TextEditingController();
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  Future<void> _begin() async {
    if (_started || !mounted) return;
    _started = true;
    final granted = await widget.coordinator.cameraService.hasPermission();
    if (!granted) {
      final ok = await widget.coordinator.cameraService.requestPermission();
      if (!ok || !mounted) return;
    }
    await widget.coordinator.startVoiceAsk();
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _question.text.trim();
    if (text.isEmpty) {
      await widget.coordinator.speechFeedbackCoordinator.interruptWith('Say or type a question first.');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    await widget.coordinator.executeAskQuestion(text);
  }

  @override
  Widget build(BuildContext context) {
    final length = _question.text.characters.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Ask a question')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Listening starts first. Type only if you want to.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.coordinator.startVoiceAsk,
              icon: const Icon(Icons.mic),
              label: const Text('Speak the question'),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _question,
              autofocus: false,
              maxLength: AppConfig.maxQuestionCharacters,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Or type a question',
                border: OutlineInputBorder(),
              ),
            ),
            Semantics(
              liveRegion: true,
              child: Text(
                '$length of ${AppConfig.maxQuestionCharacters} characters',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: const Text('Submit question'),
            ),
          ],
        ),
      ),
    );
  }
}
