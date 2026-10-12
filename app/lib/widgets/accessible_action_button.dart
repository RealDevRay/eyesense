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
      foregroundColor = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    } else if (isSecondary) {
      backgroundColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
      foregroundColor = isDark ? AppTheme.darkMainText : AppTheme.lightMainText;
    } else {
      backgroundColor = colorScheme.primary;
      foregroundColor = colorScheme.onPrimary;
    }

    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      label: label,
      hint: semanticHint,
      child: SizedBox(
        width: double.infinity,
        height: AppTheme.primaryButtonHeight, // 72 logical pixels minimum height
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            elevation: isSecondary ? 1 : 3,
            side: isSecondary
                ? BorderSide(
                    color: isDark ? AppTheme.darkSecondaryText.withOpacity(0.3) : AppTheme.lightSecondaryText.withOpacity(0.3),
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
                    Icon(icon, size: 30, color: foregroundColor),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: foregroundColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
