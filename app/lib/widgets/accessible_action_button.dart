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
    final colors = context.eyeColors;
    final enabled = onPressed != null && !isLoading;

    final Color background;
    final Color foreground;
    if (isDestructive) {
      background = colors.error;
      foreground = colors.background;
    } else if (isSecondary) {
      background = colors.surfaceRaised;
      foreground = colors.textPrimary;
    } else {
      background = colors.accent;
      foreground = colors.onAccent;
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      hint: semanticHint,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppTheme.primaryButtonHeight,
            minWidth: double.infinity,
          ),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              disabledBackgroundColor: colors.surfaceRaised,
              disabledForegroundColor: colors.textTertiary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                side: BorderSide(
                  color: isDestructive ? colors.error : colors.border,
                  width: isLoading ? 2 : 1,
                ),
              ),
            ),
            onPressed: isLoading ? null : onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: AppTheme.iconStandard,
                      height: AppTheme.iconStandard,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: foreground,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(icon, size: AppTheme.iconPrimary, color: foreground),
                  ),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: foreground),
                    softWrap: true,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
