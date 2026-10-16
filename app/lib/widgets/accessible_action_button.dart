import 'package:eyesense/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class AccessibleActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDestructive;
  final bool isSecondary;
  final bool isLoading;
  final String? semanticHint;

  const AccessibleActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
    this.isSecondary = false,
    this.isLoading = false,
    this.semanticHint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color backgroundColor;
    final Color foregroundColor;

    if (isDestructive) {
      backgroundColor = colorScheme.error;
      foregroundColor = colorScheme.onError;
    } else if (isSecondary) {
      backgroundColor = colorScheme.surface;
      foregroundColor = colorScheme.onSurface;
    } else {
      backgroundColor = colorScheme.primary;
      foregroundColor = colorScheme.onPrimary;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppTheme.primaryButtonHeight,
        minWidth: double.infinity,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: isSecondary ? 1 : 3,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          side: isSecondary
              ? BorderSide(
                  color: isDark
                      ? AppTheme.darkSecondaryText.withOpacity(0.3)
                      : AppTheme.lightSecondaryText.withOpacity(0.3),
                  width: 2,
                )
              : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: foregroundColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 28, color: foregroundColor),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: foregroundColor,
                      ),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
