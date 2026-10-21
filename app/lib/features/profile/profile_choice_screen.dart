import 'package:eyesense/services/preferences_service.dart';
import 'package:flutter/material.dart';

class ProfileChoiceScreen extends StatelessWidget {
  final PreferencesService preferences;
  final VoidCallback onChosen;

  const ProfileChoiceScreen({
    super.key,
    required this.preferences,
    required this.onChosen,
  });

  @override
  Widget build(BuildContext context) {
    final suggested = MediaQuery.accessibleNavigationOf(context)
        ? AssistanceProfile.screenReader
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('How do you use EyeSense?')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'This only sets starting preferences. You can change every option later, and nothing is turned off permanently.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          _choice(
            context,
            suggested,
            AssistanceProfile.screenReader,
            'I use a screen reader',
            'Spoken results and image-quality cues start on. Use labelled buttons with TalkBack. No preview is needed.',
          ),
          _choice(
            context,
            suggested,
            AssistanceProfile.lowVision,
            'I have some usable vision',
            'High contrast, larger type, and an optional camera preview to help you aim.',
          ),
          _choice(
            context,
            suggested,
            AssistanceProfile.sightedAssistant,
            'I am sighted and assisting someone',
            'Help aim the camera and choose a task. Results are spoken so you can both hear them.',
          ),
        ],
      ),
    );
  }

  Widget _choice(
    BuildContext context,
    AssistanceProfile? suggested,
    AssistanceProfile profile,
    String title,
    String subtitle,
  ) {
    final suggestedMark = profile == suggested ? ' Suggested.' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton(
        onPressed: () async {
          await preferences.applyProfileDefaults(profile);
          if (context.mounted) onChosen();
        },
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$title$suggestedMark'),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
