import 'package:eyesense/core/theme/app_theme.dart';
import 'package:eyesense/models/presentation_record.dart';
import 'package:eyesense/models/scene_result.dart';
import 'package:flutter/material.dart';

class ResponsePanelWidget extends StatelessWidget {
  final String? resultText;
  final SceneResult? sceneResult;
  final PresentationRecord? presentationRecord;
  final VoidCallback onRepeat;
  final VoidCallback onStop;
  final bool isSpeaking;

  const ResponsePanelWidget({
    super.key,
    required this.resultText,
    this.sceneResult,
    this.presentationRecord,
    required this.onRepeat,
    required this.onStop,
    required this.isSpeaking,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final text = presentationRecord?.responseText ?? resultText;
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasConcern = presentationRecord?.possibleConcern == true ||
        sceneResult?.possibleConcern == true;
    final concernDesc = presentationRecord?.concernDescription ??
        sceneResult?.concernDescription;
    final isPrevious = presentationRecord?.status == PresentationStatus.previous;
    final uncertainty = presentationRecord?.uncertainty ?? sceneResult?.uncertainty;

    final warningColor = isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
    final warningBg = isDark ? AppTheme.darkWarning.withOpacity(0.15) : AppTheme.lightWarning.withOpacity(0.1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132240) : colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasConcern
              ? warningColor
              : (isDark ? colorScheme.primary.withOpacity(0.4) : colorScheme.outline.withOpacity(0.3)),
          width: hasConcern ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPrevious)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, color: colorScheme.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Previous Output',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          if (hasConcern)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: warningBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: warningColor.withOpacity(0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: warningColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      concernDesc != null && concernDesc.isNotEmpty
                          ? 'Potential Concern: $concernDesc'
                          : 'Potential Concern Detected',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: warningColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Semantics(
            readOnly: true,
            child: Text(
              isPrevious ? 'Previous result: $text' : text,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (uncertainty != null && uncertainty.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Note: $uncertainty',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(color: colorScheme.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  minimumSize: const Size(120, AppTheme.minTouchTarget),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.replay, size: 22),
                label: const Text('Repeat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: onRepeat,
              ),
              if (isSpeaking)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    minimumSize: const Size(120, AppTheme.minTouchTarget),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.stop, size: 22),
                  label: const Text('Stop Audio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: onStop,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
