import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';

/// Post-sync dialog asking the driver to keep the default route order or
/// open the interactive Route Planner (Today or Weekly).
Future<void> showPostSyncRouteChoiceDialog({
  required int unplannedCount,
  required void Function(String mode) onSelectMode,
}) async {
  await Get.dialog(
    PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: AppColors.surface,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: const Icon(
                    Icons.alt_route_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plan Your Route',
                        style: AppTypography.title.copyWith(fontSize: 20),
                      ),
                      Text(
                        '$unplannedCount ${unplannedCount == 1 ? 'stop ready' : 'stops ready'} for delivery',
                        style: AppTypography.monoRef.copyWith(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Would you like to keep the default route order or generate your own custom route plan?',
              style: AppTypography.body.copyWith(
                fontSize: 15.5,
                color: AppColors.inkSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ChoiceOptionCard(
              icon: Icons.auto_awesome_rounded,
              title: 'Generate Route Plan',
              subtitle: 'Sequence Today or Weekly (Mon–Sat) stops',
              isPrimary: true,
              onTap: () {
                Get.back();
                showRoutePlanModeDialog(onSelectMode: onSelectMode);
              },
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            _ChoiceOptionCard(
              icon: Icons.near_me_outlined,
              title: 'Use Default Route',
              subtitle: 'Keep nearest-distance order on Home',
              isPrimary: false,
              onTap: () => Get.back(),
            ),
          ],
        ),
      ),
    ),
    ),
    barrierDismissible: false,
  );
}

/// Second-step dialog letting the driver choose Today's Route vs Weekly Route.
Future<void> showRoutePlanModeDialog({
  required void Function(String mode) onSelectMode,
}) async {
  await Get.dialog(
    Dialog(
      backgroundColor: AppColors.surface,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select Plan Mode',
              style: AppTypography.title.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose how you want to organize your synced deliveries:',
              style: AppTypography.caption.copyWith(
                fontSize: 14.5,
                color: AppColors.inkSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ChoiceOptionCard(
              icon: Icons.today_rounded,
              title: "Today's Route",
              subtitle:
                  "Sequence today's unloading stops & drag to set #1, #2, #3",
              isPrimary: true,
              onTap: () {
                Get.back();
                onSelectMode('today');
              },
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            _ChoiceOptionCard(
              icon: Icons.date_range_rounded,
              title: 'Weekly Route (Mon–Sat)',
              subtitle:
                  'Sort by unloading date, insert stops per day & optional Sun',
              isPrimary: false,
              onTap: () {
                Get.back();
                onSelectMode('weekly');
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                'Cancel',
                style: AppTypography.label.copyWith(
                  fontSize: 15.5,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: true,
  );
}

class _ChoiceOptionCard extends StatelessWidget {
  const _ChoiceOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isPrimary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? AppColors.primaryTint : AppColors.canvas,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: isPrimary ? AppColors.primaryBorder : AppColors.border,
              width: isPrimary ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isPrimary ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: isPrimary
                      ? null
                      : Border.all(color: AppColors.border),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isPrimary ? Colors.white : AppColors.inkPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.label.copyWith(
                        fontSize: 16.5,
                        color: isPrimary
                            ? AppColors.primary
                            : AppColors.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        fontSize: 13.5,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: isPrimary ? AppColors.primary : AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
