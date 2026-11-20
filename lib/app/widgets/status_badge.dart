import 'package:flutter/material.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';

/// Semantic status pill with restrained hairline styling.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.isPositive,
    this.isDanger = false,
    this.icon,
  });

  final String label;
  final bool isPositive;
  final bool isDanger;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = isDanger
        ? AppColors.dangerTint
        : isPositive
            ? AppColors.successTint
            : AppColors.primaryTint;
    final border = isDanger
        ? AppColors.dangerBorder
        : isPositive
            ? AppColors.successBorder
            : AppColors.primaryBorder;
    final fg = isDanger
        ? AppColors.danger
        : isPositive
            ? AppColors.success
            : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 13, color: fg)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.micro.copyWith(
              fontSize: 15.5,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hairline-framed architectural surface card.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderRadius = AppRadii.lg,
    this.backgroundColor = AppColors.surface,
    this.borderColor = AppColors.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: child,
    );
  }
}

/// Consistent section header with optional tabular count badge and trailing meta.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.trailingText,
  });

  final String title;
  final int? count;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: AppTypography.label.copyWith(fontSize: 19.5),
        ),
        if (count != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '$count',
              style: AppTypography.monoRef.copyWith(
                fontSize: 15,
                color: AppColors.inkPrimary,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (trailingText != null)
          Text(
            trailingText!,
            style: AppTypography.caption.copyWith(fontSize: 16.5),
          ),
      ],
    );
  }
}

/// Calm, actionable empty state view.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxxl,
                  vertical: AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(icon, color: AppColors.inkMuted, size: 26),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTypography.title,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(
                        fontSize: 18,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      OutlinedButton.icon(
                        onPressed: onAction,
                        icon: const Icon(Icons.sync_rounded, size: 18),
                        label: Text(
                          actionLabel!,
                          style: AppTypography.label.copyWith(
                            fontSize: 18.5,
                            color: AppColors.primary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          backgroundColor: AppColors.surface,
                          side:
                              const BorderSide(color: AppColors.primaryBorder),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
