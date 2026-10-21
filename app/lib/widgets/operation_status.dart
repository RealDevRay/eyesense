import 'package:eyesense/core/theme/app_theme.dart';
import 'package:eyesense/models/app_operation.dart';
import 'package:flutter/material.dart';

class OperationStatusWidget extends StatelessWidget {
  final OperationState state;
  final String? errorMessage;
  final VoidCallback? onDismissError;
  final bool announceChanges;

  const OperationStatusWidget({
    super.key,
    required this.state,
    this.errorMessage,
    this.onDismissError,
    this.announceChanges = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.eyeColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final isError = state == OperationState.error;
    final isBusy = state != OperationState.idle && !isError;

    final displayText = isError
        ? (errorMessage ?? 'Something went wrong')
        : state.localizedAnnouncement;

    final containerColor = isError
        ? colors.surfaceRaised
        : (isBusy ? colors.surfaceRaised : colors.surface);
    final borderColor = isError
        ? colors.error
        : isBusy
        ? colors.accent
        : colors.border;

    return Semantics(
      liveRegion: announceChanges,
      readOnly: true,
      label: 'Status: $displayText',
      child: AnimatedContainer(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: borderColor,
            width: isBusy || isError ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (isBusy)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: AppTheme.iconStandard,
                  height: AppTheme.iconStandard,
                  child: ExcludeSemantics(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: colors.accent,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  isError ? Icons.error_outline : Icons.info_outline,
                  color: isError ? colors.error : colors.accent,
                  size: AppTheme.iconStandard,
                ),
              ),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  displayText,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isError ? colors.error : colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (isError && onDismissError != null)
              TextButton(
                onPressed: onDismissError,
                child: const Text('Dismiss'),
              ),
          ],
        ),
      ),
    );
  }
}
