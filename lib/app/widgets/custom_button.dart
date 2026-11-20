import 'package:flutter/material.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';

enum CustomButtonVariant {
  primary,
  secondary,
  success,
}

/// Cohesive design-system action button with subtle press feedback
/// and reduced-motion support.
class CustomButton extends StatefulWidget {
  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.icon,
    this.variant = CustomButtonVariant.primary,
    this.isLoading = false,
    this.height = 54,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final IconData? icon;
  final CustomButtonVariant variant;
  final bool isLoading;
  final double height;

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isInteractive = widget.enabled && !widget.isLoading;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    final Color backgroundColor;
    final Color foregroundColor;
    final BorderSide borderSide;

    if (!widget.enabled) {
      backgroundColor = AppColors.surfaceMuted;
      foregroundColor = AppColors.inkSubtle;
      borderSide = const BorderSide(color: AppColors.border, width: 1);
    } else {
      switch (widget.variant) {
        case CustomButtonVariant.primary:
          backgroundColor = AppColors.primary;
          foregroundColor = Colors.white;
          borderSide = BorderSide.none;
          break;
        case CustomButtonVariant.secondary:
          backgroundColor = AppColors.surface;
          foregroundColor = AppColors.primary;
          borderSide =
              const BorderSide(color: AppColors.primaryBorder, width: 1.5);
          break;
        case CustomButtonVariant.success:
          backgroundColor = AppColors.success;
          foregroundColor = Colors.white;
          borderSide = BorderSide.none;
          break;
      }
    }

    return AnimatedScale(
      scale: (_isPressed && isInteractive && !reduceMotion) ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        width: double.infinity,
        height: widget.height,
        child: Material(
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            side: borderSide,
          ),
          child: InkWell(
            onTap: isInteractive ? widget.onPressed : null,
            onHighlightChanged: (value) {
              if (_isPressed != value) {
                setState(() => _isPressed = value);
              }
            },
            borderRadius: BorderRadius.circular(AppRadii.md),
            splashColor: foregroundColor.withOpacity(0.12),
            highlightColor: foregroundColor.withOpacity(0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: foregroundColor,
                          strokeWidth: 2.4,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: foregroundColor, size: 19),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          Flexible(
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label.copyWith(
                                fontSize: 20.5,
                                color: foregroundColor,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
