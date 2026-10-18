import 'package:flutter/material.dart';

/// A limit of the app that someone must know before relying on it.
///
/// Held as data rather than written into the widget so that the same wording is
/// spoken aloud and shown on screen. A blind user hears this once, so the
/// spoken and the readable version must not drift apart.
class SafetyLimit {
  final String title;
  final String detail;

  const SafetyLimit(this.title, this.detail);
}

/// Mirrors the Safety section of `assets/legal/terms-of-service.md`. If the
/// terms change, change both.
const safetyLimits = <SafetyLimit>[
  SafetyLimit(
    'This is not a mobility aid',
    'EyeSense cannot replace a cane, a guide dog, or your own judgement. Do not '
        'use it to decide whether it is safe to cross a road, or to find your way '
        'through a space.',
  ),
  SafetyLimit(
    'It can be confidently wrong',
    'The AI reports what it thinks it sees. Sometimes it is mistaken and still '
        'sounds certain. Treat every description as a guess rather than a fact.',
  ),
  SafetyLimit(
    'Check anything that could harm you',
    'Medication names and doses, allergens and ingredients, financial documents, '
        'and hazard or warning signs should be confirmed by a person you trust or '
        'by a device built for that purpose.',
  ),
  SafetyLimit(
    'It depends on the photo',
    'In poor light, or when the camera is not pointed at what you meant, EyeSense '
        'may describe something else entirely without telling you it has.',
  ),
  SafetyLimit(
    'Nobody is watching',
    'EyeSense is not monitored by a person and cannot call for help. In an '
        'emergency, use your phone\u2019s emergency features.',
  ),
];

/// One utterance, because TalkBack users should be able to hear the whole
/// briefing without hunting for five separate pieces of text.
String spokenSafetyBriefing() => safetyLimits
    .map((limit) => '${limit.title}. ${limit.detail}')
    .join(' ');

class SafetyBriefing extends StatelessWidget {
  const SafetyBriefing({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final limit in safetyLimits)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            // One node per limit: swiping through them one at a time is the
            // only way to re-read a single point without replaying the lot.
            child: Semantics(
              container: true,
              label: '${limit.title}. ${limit.detail}',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(limit.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(limit.detail, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
