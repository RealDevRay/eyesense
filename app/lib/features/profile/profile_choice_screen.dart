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
        : AssistanceProfile.sightedAssistant;
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
            'Gestures, spoken results, and framing cues start on. The camera preview stays off.',
          ),
          _choice(
            context,
            suggested,
            AssistanceProfile.lowVision,
            'I have some usable vision',
            'High contrast, larger type, and a camera preview with reserved space.',
          ),
          _choice(
            context,
            suggested,
            AssistanceProfile.sightedAssistant,
            'I am sighted and assisting someone',
            'Spoken results start off. Every action stays available.',
          ),
        ],
      ),
    );
  }

  Widget _choice(
    BuildContext context,
    AssistanceProfile suggested,
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
          onChosen();
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
