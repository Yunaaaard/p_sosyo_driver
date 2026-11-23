import 'package:flutter/material.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';

/// Animated swipe-to-reveal backdrop for delivery cards on Home.
/// Reacts smoothly to [progressListenable] (`0.0 -> 1.0`) with progressive
/// pill scaling, slide-in, and threshold highlight.
class SwipeActionBackground extends StatelessWidget {
  const SwipeActionBackground({
    super.key,
    required this.progressListenable,
    required this.isLocked,
    required this.isDelivered,
    required this.isDeliveredCancelable,
  });

  final ValueNotifier<double> progressListenable;
  final bool isLocked;
  final bool isDelivered;
  final bool isDeliveredCancelable;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: progressListenable,
      builder: (context, rawProgress, _) {
        final progress = rawProgress.clamp(0.0, 1.0);
        final reached = progress >= 0.38;
        final scale = 0.86 + (0.14 * (progress / 0.45).clamp(0.0, 1.0));
        final opacity = (0.35 + (0.65 * (progress / 0.30).clamp(0.0, 1.0)));

        final List<Color> gradientColors = isLocked
            ? [
                AppColors.danger.withOpacity(0.82),
                AppColors.danger,
              ]
            : [
                AppColors.surfaceDark.withOpacity(0.92),
                AppColors.surfaceDark,
              ];

        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: reached
                ? Border.all(
                    color: isLocked
                        ? Colors.white.withOpacity(0.45)
                        : AppColors.primary.withOpacity(0.75),
                    width: 1.5,
                  )
                : null,
          ),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.centerRight,
              child: isLocked
                  ? _buildLockedContent(reached)
                  : isDelivered
                      ? _buildDeliveredContent(reached)
                      : _buildActiveContent(reached),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLockedContent(bool reached) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Cancel Delivery',
              style: AppTypography.label.copyWith(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            Text(
              reached ? 'Release to confirm' : 'Swipe left to cancel',
              style: AppTypography.monoRef.copyWith(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(reached ? 0.28 : 0.16),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.cancel_outlined,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveredContent(bool reached) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDeliveredCancelable) ...[
              _SwipeActionPill(
                icon: Icons.qr_code_2_rounded,
                label: 'Cancel',
                color: AppColors.danger,
                highlighted: reached,
              ),
              const SizedBox(width: 8),
            ],
            _SwipeActionPill(
              icon: Icons.print_rounded,
              label: 'Reprint',
              color: AppColors.primary,
              highlighted: reached,
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          reached ? 'Release to choose action' : 'Swipe left for actions',
          style: AppTypography.monoRef.copyWith(
            fontSize: 10.5,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveContent(bool reached) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SwipeActionPill(
              icon: Icons.lock_clock_outlined,
              label: 'Lock',
              color: AppColors.warning,
              highlighted: reached,
            ),
            const SizedBox(width: 8),
            _SwipeActionPill(
              icon: Icons.cancel_outlined,
              label: 'Cancel',
              color: AppColors.danger,
              highlighted: reached,
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          reached ? 'Release to choose action' : 'Swipe left to lock or cancel',
          style: AppTypography.monoRef.copyWith(
            fontSize: 10.5,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }
}

class _SwipeActionPill extends StatelessWidget {
  const _SwipeActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.highlighted,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: color.withOpacity(0.42),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.label.copyWith(
              fontSize: 14.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
