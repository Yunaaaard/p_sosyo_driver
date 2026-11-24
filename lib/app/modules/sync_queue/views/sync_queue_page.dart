import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/modules/sync_queue/controller/sync_queue_controller.dart';
import 'package:p_sosyo_driver/app/widgets/custom_appBar.dart';
import 'package:p_sosyo_driver/app/widgets/custom_button.dart';
import 'package:p_sosyo_driver/app/widgets/status_badge.dart';

class SyncQueuePage extends StatelessWidget {
  const SyncQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<SyncQueueController>()
        ? Get.find<SyncQueueController>()
        : Get.put(SyncQueueController());

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const CustomAppBar(
        title: 'Offline Sync Queue',
        showBackButton: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.pendingTransactions.isEmpty) {
          return const EmptyStateView(
            icon: Icons.cloud_done_outlined,
            title: 'All Transactions Synced',
            subtitle:
                'Every delivery, cancellation, attempt, and SKU adjustment is synced.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warningTint,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: AppColors.warningBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_upload_outlined,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${controller.pendingTransactions.length} offline transaction(s) queued for upload',
                        style: AppTypography.label.copyWith(
                          fontSize: 13.5,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: controller.pendingTransactions.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, index) {
                  final txn = controller.pendingTransactions[index];
                  final (Color pillBg, Color pillFg) = switch (txn.actionType) {
                    'DELIVERED' => (AppColors.successTint, AppColors.success),
                    'CANCELLED' => (AppColors.dangerTint, AppColors.danger),
                    'ATTEMPT' => (AppColors.warningTint, AppColors.warning),
                    _ => (AppColors.primaryTint, AppColors.primary),
                  };

                  return SurfaceCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                txn.storeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    AppTypography.label.copyWith(fontSize: 15),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: pillBg,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.pill),
                              ),
                              child: Text(
                                txn.actionType,
                                style: AppTypography.monoRef.copyWith(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: pillFg,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ref #${txn.orderId} · ${txn.summary}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            fontSize: 12.5,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              txn.amount,
                              style: AppTypography.monoRef.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkPrimary,
                              ),
                            ),
                            Text(
                              txn.retryCount > 0
                                  ? 'Retries: ${txn.retryCount}'
                                  : 'Queued offline',
                              style: AppTypography.monoRef.copyWith(
                                fontSize: 11,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: CustomButton(
                  label: controller.isFlushing.value
                      ? 'Syncing Queue...'
                      : 'Flush & Sync Now',
                  icon: Icons.cloud_sync_rounded,
                  isLoading: controller.isFlushing.value,
                  onPressed: () {
                    if (!controller.isFlushing.value) {
                      controller.flushQueueNow();
                    }
                  },
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
