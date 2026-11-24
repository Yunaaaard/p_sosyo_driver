import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/modules/van_loadout/controller/van_loadout_controller.dart';
import 'package:p_sosyo_driver/app/widgets/custom_appBar.dart';
import 'package:p_sosyo_driver/app/widgets/status_badge.dart';

class VanLoadoutPage extends StatelessWidget {
  const VanLoadoutPage({super.key});

  VanLoadoutController get controller => Get.isRegistered<VanLoadoutController>()
      ? Get.find<VanLoadoutController>()
      : Get.put(VanLoadoutController());

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const CustomAppBar(
        title: 'Van Loadout Manifest',
        showBackButton: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.lifoStops.isEmpty) {
          return const EmptyStateView(
            icon: Icons.local_shipping_outlined,
            title: 'No Active Stops to Load',
            subtitle: 'Sync your delivery route to generate a LIFO truck manifest.',
          );
        }

        final isLifo = controller.activeTab.value == 'lifo';
        final loadedCount = controller.checkedOrderIds.length;
        final totalStops = controller.lifoStops.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Dark Depot Summary Banner ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDarkElevated,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LIFO Loading Guide',
                            style: AppTypography.title.copyWith(
                              fontSize: 17,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Load Stop #$totalStops first (front) → Stop #1 last (door)',
                            style: AppTypography.monoRef.copyWith(
                              fontSize: 11.5,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: loadedCount == totalStops
                            ? AppColors.success
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        '$loadedCount / $totalStops',
                        style: AppTypography.monoRef.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Smooth Gliding Segment Tabs ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _buildTabs(isLifo, reduceMotion),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Tab Content ──
            Expanded(
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: isLifo
                    ? _buildLifoList(totalStops)
                    : _buildSkuSummaryList(),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildTabs(bool isLifo, bool reduceMotion) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final halfWidth = (constraints.maxWidth - 4) / 2;
        return SizedBox(
          height: 38,
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: isLifo ? 0 : halfWidth + 4,
                top: 0,
                bottom: 0,
                width: halfWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E6BFF), Color(0xFF1542B5)],
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => controller.switchTab('lifo'),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          style: AppTypography.label.copyWith(
                            fontSize: 13.5,
                            color: isLifo
                                ? Colors.white
                                : AppColors.inkSecondary,
                          ),
                          child: const Text('LIFO Truck Load'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () => controller.switchTab('summary'),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          style: AppTypography.label.copyWith(
                            fontSize: 13.5,
                            color: !isLifo
                                ? Colors.white
                                : AppColors.inkSecondary,
                          ),
                          child: Text(
                            'SKU Summary (${controller.consolidatedSkus.length})',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLifoList(int totalStops) {
    return ListView.separated(
      key: const ValueKey('van_lifo_list'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      itemCount: controller.lifoStops.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, index) {
        final order = controller.lifoStops[index];
        final stopNumber = order.routeSequence ?? (totalStops - index);
        final isLoaded = controller.checkedOrderIds.contains(order.id);
        final items = controller.itemsByOrderId[order.id] ??
            controller.itemsByOrderId[order.transactionId] ??
            [];

        return SurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          borderColor:
              isLoaded ? AppColors.successBorder : AppColors.border,
          child: InkWell(
            onTap: () => controller.toggleStopLoaded(order.id),
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isLoaded
                            ? AppColors.successTint
                            : AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        'STOP #$stopNumber',
                        style: AppTypography.monoRef.copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isLoaded
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label.copyWith(fontSize: 15),
                      ),
                    ),
                    Icon(
                      isLoaded
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isLoaded
                          ? AppColors.success
                          : AppColors.inkMuted,
                    ),
                  ],
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 8),
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body.copyWith(
                                fontSize: 13,
                                color: AppColors.inkSecondary,
                              ),
                            ),
                          ),
                          Text(
                            item.displayQty,
                            style: AppTypography.monoRef.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkuSummaryList() {
    return ListView.separated(
      key: const ValueKey('van_sku_summary'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      itemCount: controller.consolidatedSkus.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, index) {
        final sku = controller.consolidatedSkus[index];
        return SurfaceCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sku.title,
                      style: AppTypography.label.copyWith(fontSize: 14.5),
                    ),
                    if (sku.stockCode.isNotEmpty)
                      Text(
                        sku.stockCode,
                        style: AppTypography.monoRef.copyWith(
                          fontSize: 11.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(
                  '${sku.totalQty} ${sku.uom}',
                  style: AppTypography.monoRef.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
