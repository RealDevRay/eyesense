import 'package:eyesense/models/app_operation.dart';
import 'package:flutter/material.dart';

class OperationStatusWidget extends StatelessWidget {
  final OperationState state;
  final String? errorMessage;

  const OperationStatusWidget({
    super.key,
    required this.state,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isError = state == OperationState.error;
    final isBusy = state != OperationState.idle && !isError;

    final displayText = isError
        ? (errorMessage ?? 'Error occurred')
        : state.localizedAnnouncement;

    final containerColor = isError
        ? colorScheme.error.withOpacity(isDark ? 0.2 : 0.1)
        : (isDark ? const Color(0xFF132240) : colorScheme.surfaceContainerHighest.withOpacity(0.6));

    final borderColor = isError
        ? colorScheme.error
        : (isBusy ? colorScheme.primary : colorScheme.outline.withOpacity(0.3));

    final textColor = isError
        ? colorScheme.error
        : colorScheme.onSurface;

    return Semantics(
      readOnly: true,
      label: 'Status: $displayText',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isBusy || isError ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            if (isBusy)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colorScheme.primary,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(
                  isError ? Icons.error_outline : Icons.info_outline,
                  color: isError ? colorScheme.error : colorScheme.primary,
                  size: 24,
                ),
              ),
            Expanded(
              child: Text(
                displayText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
