import 'package:eyesense/core/theme/app_theme.dart';
import 'package:eyesense/models/scene_result.dart';
import 'package:flutter/material.dart';

class ResponsePanelWidget extends StatelessWidget {
  final String? resultText;
  final SceneResult? sceneResult;
  final VoidCallback onRepeat;
  final VoidCallback onStop;
  final bool isSpeaking;

  const ResponsePanelWidget({
    super.key,
    required this.resultText,
    this.sceneResult,
    required this.onRepeat,
    required this.onStop,
    required this.isSpeaking,
  });

  @override
  Widget build(BuildContext context) {
    if (resultText == null || resultText!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sceneResult?.possibleConcern == true
              ? AppTheme.warningOrange
              : AppTheme.tealAccent.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sceneResult?.possibleConcern == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.warningOrange, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Potential Concern Detected',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.warningOrange,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          Semantics(
            readOnly: true,
            child: Text(
              resultText!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.4,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.tealLight,
                    side: const BorderSide(color: AppTheme.tealLight, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.replay, size: 22),
                  label: const Text('Repeat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: onRepeat,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorRed,
                    foregroundColor: AppTheme.backgroundNavy,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.stop, size: 22),
                  label: const Text('Stop', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: onStop,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
