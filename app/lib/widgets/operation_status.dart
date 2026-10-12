import 'package:eyesense/core/theme/app_theme.dart';
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
    final isError = state == OperationState.error;
    final isBusy = state != OperationState.idle && !isError;

    final displayText = isError
        ? (errorMessage ?? 'Error occurred')
        : state.localizedAnnouncement;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isError ? AppTheme.errorRed.withOpacity(0.2) : AppTheme.surfaceNavy,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isError ? AppTheme.errorRed : AppTheme.tealAccent.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            if (isBusy)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.tealAccent),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  isError ? Icons.error_outline : Icons.check_circle_outline,
                  color: isError ? AppTheme.errorRed : AppTheme.tealAccent,
                  size: 22,
                ),
              ),
            Expanded(
              child: Text(
                displayText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isError ? AppTheme.errorRed : AppTheme.textNearWhite,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
