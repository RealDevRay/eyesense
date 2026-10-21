import 'package:eyesense/core/theme/app_theme.dart';
import 'package:eyesense/models/presentation_record.dart';
import 'package:eyesense/models/scene_result.dart';
import 'package:flutter/material.dart';

class ResponsePanelWidget extends StatelessWidget {
  final String? resultText;
  final SceneResult? sceneResult;
  final PresentationRecord? presentationRecord;
  final VoidCallback? onMoreDetail;
  final FocusNode? focusNode;

  const ResponsePanelWidget({
    super.key,
    required this.resultText,
    this.sceneResult,
    this.presentationRecord,
    this.onMoreDetail,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.eyeColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final text = presentationRecord?.responseText ?? resultText;
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasConcern =
        presentationRecord?.possibleConcern == true ||
        sceneResult?.possibleConcern == true;
    final concernDesc =
        presentationRecord?.concernDescription ??
        sceneResult?.concernDescription;
    final isPrevious =
        presentationRecord?.status == PresentationStatus.previous;
    final uncertainty =
        presentationRecord?.uncertainty ?? sceneResult?.uncertainty;

    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey(text),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: hasConcern ? colors.concern : colors.border,
            width: hasConcern ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPrevious)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Previous output',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.accent,
                  ),
                ),
              ),
            if (hasConcern)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  concernDesc != null && concernDesc.isNotEmpty
                      ? 'Potential concern: $concernDesc'
                      : 'Potential concern',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.concern,
                  ),
                ),
              ),
            Focus(
              focusNode: focusNode,
              child: Semantics(
                readOnly: true,
                child: Text(
                  isPrevious ? 'Previous result: $text' : text,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            if (uncertainty != null && uncertainty.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Note: $uncertainty',
                  style: theme.textTheme.bodySmall,
                ),
              ),

            if (onMoreDetail != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onMoreDetail,
                child: const Text('Read full response aloud'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
