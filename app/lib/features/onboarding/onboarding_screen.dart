import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/core/theme/app_theme.dart';
import 'package:eyesense/features/onboarding/safety_briefing.dart';
import 'package:eyesense/services/camera_service.dart';
import 'package:eyesense/widgets/accessible_action_button.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class OnboardingScreen extends StatefulWidget {
  final AgentCoordinator coordinator;
  final VoidCallback onFinish;

  const OnboardingScreen({
    super.key,
    required this.coordinator,
    required this.onFinish,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late int _currentStep;
  bool _practiceCaptureSuccess = false;
  late bool _safetyAcknowledged;

  /// The safety briefing's position. Named because several things key off it.
  static const int _safetyStep = 1;

  final int _totalSteps = 7;

  @override
  void initState() {
    super.initState();
    _safetyAcknowledged = widget.coordinator.preferencesService.hasAcknowledgedSafety;
    if (!widget.coordinator.preferencesService.hasCompletedOnboarding) {
      _currentStep = widget.coordinator.preferencesService.onboardingStep.clamp(0, _totalSteps - 1);
    } else {
      _currentStep = 0;
    }
    if (_currentStep == _safetyStep) _speakSafetyBriefing();
  }

  void _speakSafetyBriefing() {
    widget.coordinator.speechFeedbackCoordinator.speakResult(spokenSafetyBriefing());
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    if (!widget.coordinator.preferencesService.hasCompletedOnboarding) {
      widget.coordinator.preferencesService.setOnboardingStep(step);
    }
    // Read aloud on arrival. Someone who relies on this app most is least
    // likely to find a wall of text by exploring for it.
    if (step == _safetyStep) _speakSafetyBriefing();
  }

  bool get _blockedBySafety => _currentStep == _safetyStep && !_safetyAcknowledged;

  void _explainSafetyGate() {
    widget.coordinator.speechFeedbackCoordinator.speakResult(
      'Please select "I understand these limits" to continue.',
    );
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _goToStep(_currentStep + 1);
    } else {
      _finish();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  /// Skipping the tutorial is fine; skipping the safety briefing is not. If it
  /// has not been acknowledged, "Skip" lands on it instead of leaving.
  void _skip() {
    if (!_safetyAcknowledged) {
      _goToStep(_safetyStep);
      return;
    }
    _finish();
  }

  Future<void> _finish() async {
    await widget.coordinator.preferencesService.setOnboardingStep(0);
    await widget.coordinator.preferencesService.setCompletedOnboarding(true);
    widget.onFinish();
  }

  Future<void> _requestCameraPermissionAndPractice() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      CapturedImageData? captured;
      try {
        await widget.coordinator.cameraService.initialize();
        captured = await widget.coordinator.cameraService.captureAndCompress();
        setState(() {
          _practiceCaptureSuccess = true;
        });
        widget.coordinator.speechFeedbackCoordinator.speakResult(
          'Practice picture taken successfully. Camera is ready.',
        );
      } catch (e) {
        widget.coordinator.speechFeedbackCoordinator.speakResult(
          'Camera capture test failed. Please try again.',
        );
      } finally {
        await widget.coordinator.cameraService.deleteTemporaryCapture(captured?.file);
      }
    } else {
      widget.coordinator.speechFeedbackCoordinator.speakResult(
        'Camera permission was not granted. Direct camera features will remain disabled until granted in Android Settings.',
      );
    }
  }

  String _narration() {
    switch (_currentStep) {
      case 0:
        return 'Welcome to EyeSense. '
            'EyeSense turns camera images into spoken descriptions and reads printed text aloud. '
            'The next screen covers what it cannot do. Please read or listen to it before you rely on the app.';
      case _safetyStep:
        return 'Safety and limits. ${spokenSafetyBriefing()} '
            'Select I understand these limits to continue.';
      case 2:
        return 'How to Interact. EyeSense works with TalkBack. '
            'Explore the screen to hear button labels. '
            'Double-tap anywhere to activate the selected button. '
            'Use Start voice command at any time for one-touch voice tasks. '
            'The Stop button is always available to cancel speech or active tasks.';
      case 3:
        return 'Language and Speech. Select your preferred response language. '
            'English is the default. Kiswahili is also available.';
      case 4:
        return 'Privacy and Connection. How EyeSense processes data. '
            'Read Text operates on the device. No images or text are sent over the network. '
            'Describe and Ask send one captured snapshot and your question to your configured AI provider. '
            'Requests sent to a cloud provider cannot be recalled. '
            'Spoken commands use the device system speech service. '
            'Bring-your-own-key mode uses your personal Groq API key. '
            'Allow Cloud AI Analysis is required for Describe Scene and Ask Question.';
      case 5:
        return 'Practice Camera Capture. '
            'Let’s test taking a picture with the rear camera to make sure permissions are ready.';
      case 6:
        return 'Setup Complete. You are all set to use EyeSense. '
            'You can always access this tutorial, change voices, or enter your personal Groq key in Settings.';
      default:
        return 'EyeSense setup.';
    }
  }

  Widget _buildStepContent() {
    final theme = Theme.of(context);
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to EyeSense',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'EyeSense turns camera images into spoken descriptions and reads printed text aloud.\n\n'
              'The next screen covers what it cannot do. Please read or listen to it before you rely on the app.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        );

      case _safetyStep:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Safety and limits',
                style: theme.textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 16),
            const SafetyBriefing(),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _safetyAcknowledged,
              onChanged: (val) {
                setState(() => _safetyAcknowledged = val ?? false);
                if (_safetyAcknowledged) {
                  widget.coordinator.preferencesService.recordSafetyAcknowledgement();
                }
              },
              title: const Text(
                'I understand these limits',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to Interact',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'EyeSense works seamlessly with TalkBack:\n\n'
              '1. Explore the screen to hear button labels.\n'
              '2. Double-tap anywhere to activate the selected button.\n'
              '3. Use "Start voice command" at any time for one-touch voice tasks.\n'
              '4. The Stop button is always available to cancel speech or active tasks.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        );

      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Language & Speech',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Select your preferred response language:',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: widget.coordinator.preferencesService.language,
              onChanged: (val) {
                if (val == null) return;
                setState(() {});
                widget.coordinator.preferencesService.setLanguage(val);
                widget.coordinator.speechFeedbackCoordinator.speakResult(
                  val == 'sw' ? 'Lugha imewekwa kuwa Kiswahili.' : 'Language set to English.',
                );
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    title: Text('English (Default)'),
                    value: 'en',
                  ),
                  RadioListTile<String>(
                    title: Text('Kiswahili'),
                    value: 'sw',
                  ),
                ],
              ),
            ),
          ],
        );

      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy & Connection',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'How EyeSense processes data:\n\n'
              '• Read Text: Operates 100% on-device (offline OCR). No images or text are sent over the network.\n'
              '• Describe & Ask: Sends one captured snapshot and your question to your configured AI provider (EyeSense Hosted Worker proxy or direct Groq BYOK).\n'
              '• Upstream Processing: Requests sent to cloud providers are subject to provider processing and commercial retention terms. Once received by the cloud provider, requests cannot be recalled.\n'
              '• Speech Recognition: Spoken commands use the device system speech service.\n'
              '• BYOK mode: Uses your personal Groq API key and account quotas.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow Cloud AI Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Required for Describe Scene and Ask Question'),
              value: widget.coordinator.preferencesService.cloudConsentGranted,
              onChanged: (val) {
                setState(() {});
                widget.coordinator.preferencesService.setCloudConsentGranted(val);
              },
            ),
          ],
        );

      case 5:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Practice Camera Capture',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Let’s test taking a picture with the rear camera to make sure permissions are ready.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            AccessibleActionButton(
              label: _practiceCaptureSuccess ? 'Take Another Picture' : 'Practice Capture',
              icon: Icons.camera_alt,
              onPressed: _requestCameraPermissionAndPractice,
            ),
            if (_practiceCaptureSuccess) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: context.eyeColors.success,
                    size: AppTheme.iconStandard,
                  ),
                  const SizedBox(width: 8),
                  const Text('Camera tested and ready!', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ],
        );

      case 6:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Setup Complete',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'You are all set to use EyeSense!\n\n'
              'You can always access this tutorial, change voices, or enter your personal Groq key in Settings.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Step ${_currentStep + 1} of $_totalSteps'),
        actions: [
          if (_currentStep != _safetyStep)
            TextButton(
              onPressed: _skip,
              child: const Text('Skip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.defaultPadding),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: _buildStepContent(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, AppTheme.minTouchTarget + 8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    widget.coordinator.speechFeedbackCoordinator.speakResult(_narration());
                  },
                  child: const Text('Read this aloud', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              if (_currentStep > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, AppTheme.minTouchTarget + 8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _previousStep,
                      child: const Text('Back', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: Semantics(
                  hint: _blockedBySafety ? 'Confirm you understand the limits first' : null,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, AppTheme.minTouchTarget + 8),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    // Left enabled deliberately. A disabled button announces
                    // itself as dimmed and gives no reason, which strands a
                    // screen-reader user with no way to find out why.
                    onPressed: _blockedBySafety ? _explainSafetyGate : _nextStep,
                    child: Text(
                      _currentStep == _totalSteps - 1 ? 'Get Started' : 'Continue',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
