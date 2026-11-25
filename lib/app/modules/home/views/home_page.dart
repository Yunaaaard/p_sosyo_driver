import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/core/utils/paqner_qr_codec.dart';
import 'package:p_sosyo_driver/app/core/utils/peso_formatter.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/services/bluetooth_printer_service.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';
import 'package:p_sosyo_driver/app/widgets/app_date_picker.dart';
import 'package:p_sosyo_driver/app/widgets/custom_appBar.dart';
import 'package:p_sosyo_driver/app/widgets/custom_button.dart';
import 'package:p_sosyo_driver/app/widgets/delivery_attempt_dialog.dart';
import 'package:p_sosyo_driver/app/widgets/home_sidebar_drawer.dart';
import 'package:p_sosyo_driver/app/widgets/printer_picker_dialog.dart';
import 'package:p_sosyo_driver/app/widgets/status_badge.dart';
import 'package:p_sosyo_driver/app/widgets/store_image_widget.dart';
import 'package:p_sosyo_driver/app/widgets/swipe_action_background.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      drawer: HomeSidebarDrawer(
        controller: controller,
        onOpenNotifications: () => _showSmsNotificationStatusDialog(context),
      ),
      appBar: CustomAppBar(
        leading: _buildMenuDrawerButton(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Rounded Route Telemetry Card & Pill Tabs ────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: Column(
              children: [
                _buildRouteLedgerCard(reduceMotion),
                const SizedBox(height: AppSpacing.lg),
                _buildTabSelector(reduceMotion),
                Obx(() {
                  final filterIso = controller.selectedDateFilter.value;
                  if (filterIso == null || filterIso.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Date Filter: ${HomeController.formatDateLabel(filterIso)}',
                            style: AppTypography.caption.copyWith(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: controller.clearDateFilter,
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Rounded Delivery Stop Cards ─────────────────────────────
          Expanded(
            child: Obx(() {
              final active = controller.activeTab.value;
              final filtered = controller.orders
                  .where((o) =>
                      (active == 'All' || o.status.value == active) &&
                      controller.matchesDateFilter(o))
                  .toList();

              final Widget tabContent;
              if (filtered.isEmpty) {
                final isDeliveredTab = active == 'Delivered';
                final isCancelledTab = active == 'Cancelled';
                final hasAnyOrders = controller.orders.isNotEmpty;
                tabContent = EmptyStateView(
                  key: ValueKey('tab_empty_$active'),
                  icon: isDeliveredTab
                      ? Icons.fact_check_outlined
                      : isCancelledTab
                          ? Icons.cancel_outlined
                          : Icons.local_shipping_outlined,
                  title: isDeliveredTab
                      ? 'No Delivered Stops Yet'
                      : isCancelledTab
                          ? 'No Cancelled Deliveries'
                          : hasAnyOrders
                              ? 'All Stops Completed'
                              : 'No Deliveries Synced',
                  subtitle: isDeliveredTab
                      ? 'Completed deliveries and verified receipts will appear here.'
                      : isCancelledTab
                          ? 'Orders swiped right-to-left to cancel will appear here.'
                          : hasAnyOrders
                              ? 'Every active order on your route has been processed.'
                              : 'Sync your dispatch route to load assigned store deliveries.',
                  actionLabel:
                      (!isDeliveredTab && !isCancelledTab && !hasAnyOrders)
                          ? 'Sync Route'
                          : null,
                  onAction: (!isDeliveredTab && !isCancelledTab && !hasAnyOrders)
                      ? controller.showSyncDialog
                      : null,
                );
              } else {
                tabContent = Column(
                  key: ValueKey('tab_list_$active'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  if (controller.isSyncing.value &&
                      controller.isSyncDialogMinimized.value)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: GestureDetector(
                        onTap: () => controller.showSyncDialog(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm + 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(color: AppColors.primaryBorder),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Syncing in background (${(controller.syncProgress.value * 100).toInt()}%)… Tap to view',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.label.copyWith(
                                    fontSize: 13.5,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.open_in_full_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xs,
                    ),
                    child: _buildDistanceSortHeader(),
                  ),
                  Expanded(
                    child: (active == 'All' || active == 'Out for Delivery')
                        ? ReorderableListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.xs,
                              AppSpacing.lg,
                              AppSpacing.xl,
                            ),
                            buildDefaultDragHandles: false,
                            itemCount: filtered.length,
                            proxyDecorator: (child, index, animation) {
                              return Material(
                                color: Colors.transparent,
                                elevation: 6,
                                shadowColor: AppColors.primary.withOpacity(0.2),
                                borderRadius:
                                    BorderRadius.circular(AppRadii.lg),
                                child: child,
                              );
                            },
                            onReorder: (oldIndex, newIndex) =>
                                controller.reorderOutForDelivery(
                              filtered,
                              oldIndex,
                              newIndex,
                            ),
                            itemBuilder: (context, index) {
                              final order = filtered[index];
                              return Padding(
                                key: ValueKey('timeline_item_${order.id}'),
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildTimelineStopRow(
                                  context,
                                  order: order,
                                  index: index,
                                  totalCount: filtered.length,
                                  isDraggable:
                                      order.status.value == 'Out for Delivery' &&
                                          !order.isLocked,
                                ),
                              );
                            },
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.xs,
                              AppSpacing.lg,
                              AppSpacing.xl,
                            ),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) =>
                                _buildTimelineStopRow(
                              context,
                              order: filtered[index],
                              index: index,
                              totalCount: filtered.length,
                              isDraggable: false,
                            ),
                          ),
                  ),
                ],
              );
              }

              return AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.03, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: tabContent,
              );
            }),
          ),

          // ── Clean Bottom Nav Bar (No Lines / Dividers) ──────────────
          _buildBottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildMenuDrawerButton() {
    return Obx(() {
      final alertCount = controller.ordersMissingPhone.length +
          controller.ordersPendingSmsWithPhone.length +
          controller.pendingOfflineCount.value;

      return Builder(
        builder: (btnContext) => Tooltip(
          message: 'Driver Menu',
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: InkWell(
                  onTap: () => Scaffold.of(btnContext).openDrawer(),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.menu_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                ),
              ),
              if (alertCount > 0)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  void _showSmsNotificationStatusDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Obx(() {
          final missing = controller.ordersMissingPhone;
          final notified = controller.ordersSmsNotified;
          final pending = controller.ordersPendingSmsWithPhone;

          return Dialog(
            backgroundColor: AppColors.surface,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl,
            ),
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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: missing.isNotEmpty
                              ? AppColors.warningTint
                              : AppColors.successTint,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(
                            color: missing.isNotEmpty
                                ? AppColors.warningBorder
                                : AppColors.successBorder,
                          ),
                        ),
                        child: Icon(
                          missing.isNotEmpty
                              ? Icons.sms_failed_outlined
                              : Icons.mark_chat_read_outlined,
                          size: 20,
                          color: missing.isNotEmpty
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customer SMS Status',
                              style: AppTypography.title.copyWith(fontSize: 20),
                            ),
                            Text(
                              '${notified.length} notified · ${missing.length} missing phone',
                              style: AppTypography.caption.copyWith(
                                fontSize: 14,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (missing.isEmpty && pending.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.successTint,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.successBorder),
                      ),
                      child: Text(
                        'All Out-for-Delivery customers have received their mandatory SMS notification.',
                        style: AppTypography.body.copyWith(
                          fontSize: 15,
                          color: AppColors.success,
                        ),
                      ),
                    )
                  else ...[
                    if (missing.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.dangerTint,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(color: AppColors.dangerBorder),
                        ),
                        child: Text(
                          '${missing.length} ${missing.length == 1 ? 'customer did not' : 'customers did not'} receive the mandatory SMS because no phone number is assigned. Tap a store to add a phone number:',
                          style: AppTypography.caption.copyWith(
                            fontSize: 14,
                            color: AppColors.danger,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: missing.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (_, idx) {
                            final o = missing[idx];
                            return Material(
                              color: AppColors.canvas,
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(dialogContext).pop();
                                  Get.toNamed(
                                    AppRoutes.orderDetails,
                                    arguments: o,
                                  );
                                },
                                borderRadius:
                                    BorderRadius.circular(AppRadii.md),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.md),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              o.storeName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.label
                                                  .copyWith(fontSize: 15.5),
                                            ),
                                            Text(
                                              'Ref #${o.id} · No phone number',
                                              style: AppTypography.monoRef
                                                  .copyWith(
                                                fontSize: 12.5,
                                                color: AppColors.danger,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.inkMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    if (pending.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton.icon(
                        onPressed: () async {
                          for (final o in pending) {
                            await controller.notifyCustomerOutForDelivery(o);
                          }
                        },
                        icon: const Icon(Icons.sms_outlined, size: 18),
                        label: Text(
                          'Send Pending SMS (${pending.length})',
                          style: AppTypography.label.copyWith(
                            fontSize: 15.5,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.inkSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: AppTypography.label.copyWith(
                        fontSize: 16,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  /// Rounded dark-plum route card with collected sales, stop count,
  /// and segmented per-stop progress blocks.
  Widget _buildRouteLedgerCard(bool reduceMotion) {
    return Obx(() {
      final totalOrders = controller.orders.length;
      final delivered = controller.deliveredCount.value;
      final remaining = controller.orders
          .where((o) => o.status.value == 'Out for Delivery')
          .length;
      final ratio =
          totalOrders > 0 ? (delivered / totalOrders).clamp(0.0, 1.0) : 0.0;

      String formatSales(double value) {
        final parts = value.toStringAsFixed(2).split('.');
        final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
        parts[0] = parts[0].replaceAllMapped(regExp, (Match m) => ',');
        return parts.join('.');
      }

      return Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: AppColors.surfaceDarkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.mint,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'COLLECTED SALES',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.eyebrow.copyWith(
                                  fontSize: 13,
                                  color: AppColors.mint,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            PesoFormatter.buildPesoTextSpan(
                              amount: formatSales(controller.totalSales.value),
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    color: AppColors.surfaceDarkBorder,
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'DELIVERED',
                          style: AppTypography.eyebrow.copyWith(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.68),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$delivered',
                                style: AppTypography.heroMetric.copyWith(
                                  fontSize: 33,
                                  color: Colors.white,
                                ),
                              ),
                              if (totalOrders > 0)
                                TextSpan(
                                  text: ' / $totalOrders',
                                  style: AppTypography.label.copyWith(
                                    fontSize: 18.5,
                                    color: Colors.white.withOpacity(0.55),
                                    fontFeatures: AppTypography.tabular,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Segmented per-stop route tick track (rounded pills)
            if (totalOrders > 0 && totalOrders <= 24)
              Row(
                children: [
                  for (int i = 0; i < totalOrders; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: AnimatedContainer(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        height: 6,
                        decoration: BoxDecoration(
                          color: i < delivered
                              ? AppColors.mint
                              : AppColors.surfaceDarkElevated,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                      ),
                    ),
                  ],
                ],
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: Container(
                  height: 6,
                  color: AppColors.surfaceDarkElevated,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ratio,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    totalOrders == 0
                        ? 'Sync required to load today\'s manifest'
                        : remaining == 0
                            ? 'All synced route stops delivered'
                            : '$remaining ${remaining == 1 ? 'stop' : 'stops'} remaining',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                ),
                if (totalOrders > 0) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${(ratio * 100).round()}%',
                    style: AppTypography.monoRef.copyWith(
                      fontSize: 15,
                      color: AppColors.mint,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    });
  }

  /// Rounded segmented pill switcher for "All", "Out for Delivery", "Delivered", and "Cancelled".
  Widget _buildTabSelector(bool reduceMotion) {
    return Obx(() {
      final active = controller.activeTab.value;
      final allCount = controller.orders
          .where((o) => controller.matchesDateFilter(o))
          .length;
      final outForDeliveryCount = controller.orders
          .where((o) =>
              o.status.value == 'Out for Delivery' &&
              controller.matchesDateFilter(o))
          .length;
      final deliveredCount = controller.orders
          .where((o) =>
              o.status.value == 'Delivered' &&
              controller.matchesDateFilter(o))
          .length;
      final cancelledCount = controller.orders
          .where((o) =>
              o.status.value == 'Cancelled' &&
              controller.matchesDateFilter(o))
          .length;

      final tabs = <({String label, String key, int count, int flex})>[
        (label: 'All', key: 'All', count: allCount, flex: 7),
        (
          label: 'Undelivered',
          key: 'Out for Delivery',
          count: outForDeliveryCount,
          flex: 14,
        ),
        (label: 'Delivered', key: 'Delivered', count: deliveredCount, flex: 12),
        (label: 'Cancelled', key: 'Cancelled', count: cancelledCount, flex: 12),
      ];
      final selectedIndex = tabs.indexWhere((t) => t.key == active);
      final safeIndex = selectedIndex < 0 ? 0 : selectedIndex;
      final totalFlex = tabs.fold<int>(0, (sum, t) => sum + t.flex);
      const double gap = 2.0;
      const double tabHeight = 36.0;

      return LayoutBuilder(
        builder: (context, constraints) {
          final totalGapsWidth = gap * (tabs.length - 1);
          final usableWidth =
              (constraints.maxWidth - totalGapsWidth).clamp(0.0, double.infinity);

          double pillLeft = 0;
          for (int i = 0; i < safeIndex; i++) {
            pillLeft += usableWidth * (tabs[i].flex / totalFlex) + gap;
          }
          final pillWidth = usableWidth * (tabs[safeIndex].flex / totalFlex);

          return SizedBox(
            height: tabHeight,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  left: pillLeft,
                  top: 0,
                  bottom: 0,
                  width: pillWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFF2E6BFF),
                          Color(0xFF1542B5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1542B5).withOpacity(0.28),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (int i = 0; i < tabs.length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      Expanded(
                        flex: tabs[i].flex,
                        child: _buildTabButton(
                          label: tabs[i].label,
                          tabKey: tabs[i].key,
                          count: tabs[i].count,
                          isSelected: i == safeIndex,
                          reduceMotion: reduceMotion,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildTabButton({
    required String label,
    String? tabKey,
    required int count,
    required bool isSelected,
    required bool reduceMotion,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => controller.changeTab(tabKey ?? label),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            style: AppTypography.label.copyWith(
              fontSize: 13.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.inkSecondary,
            ),
            child: Text(
              '$label ($count)',
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ),
      ),
    );
  }

  /// Compact sort bar indicating ascending distance sorting (Nearest -> Farthest).
  Widget _buildDistanceSortHeader() {
    return Obx(() {
      final nearestFirst = controller.sortNearestFirst.value;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.near_me_rounded,
                  size: 13,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    controller.activeTab.value == 'Out for Delivery'
                        ? '${nearestFirst ? "Nearest to Farthest" : "Farthest to Nearest"} · Swipe left to cancel'
                        : controller.activeTab.value == 'Delivered'
                            ? '${nearestFirst ? "Nearest to Farthest" : "Farthest to Nearest"} · Swipe left within 1h to cancel'
                            : nearestFirst
                                ? 'Sorted by location · Nearest to Farthest'
                                : 'Sorted by location · Farthest to Nearest',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      fontSize: 14,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: InkWell(
              onTap: controller.toggleDistanceSort,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.swap_vert_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      nearestFirst ? 'Nearest First' : 'Farthest First',
                      style: AppTypography.micro.copyWith(
                        fontSize: 13.5,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  /// Builds the vertical timeline index rail (matching the route sequence
  /// numbers 1, 2, 3 / ✓ / ⊘) beside each delivery card, with a drag handle
  /// for active Out-for-Delivery cards.
  Widget _buildTimelineStopRow(
    BuildContext context, {
    required DeliveryOrder order,
    required int index,
    required int totalCount,
    required bool isDraggable,
  }) {
    final status = order.status.value.trim();
    final isDelivered = status == 'Delivered';
    final isCancelled = status == 'Cancelled';
    final isLocked = order.isLocked && !isDelivered && !isCancelled;
    final isFirstActive = !isDelivered && !isCancelled && !isLocked && index == 0;
    final displayNumber = index + 1;
    final isLast = index == totalCount - 1;

    Widget nodeCircle;
    if (isDelivered) {
      nodeCircle = Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
      );
    } else if (isCancelled) {
      nodeCircle = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.dangerTint,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.dangerBorder, width: 1.5),
        ),
        child: const Icon(
          Icons.do_not_disturb_alt_rounded,
          size: 16,
          color: AppColors.danger,
        ),
      );
    } else if (isLocked) {
      nodeCircle = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.warningTint,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.warning, width: 1.5),
        ),
        child: const Icon(Icons.lock_clock_outlined,
            size: 14, color: AppColors.warning),
      );
    } else if (isFirstActive) {
      nodeCircle = Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.28),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '$displayNumber',
          style: AppTypography.monoRef.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    } else {
      nodeCircle = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primaryBorder, width: 1.8),
        ),
        alignment: Alignment.center,
        child: Text(
          '$displayNumber',
          style: AppTypography.monoRef.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                const SizedBox(height: 14),
                nodeCircle,
                if (isDraggable) ...[
                  const SizedBox(height: 6),
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        size: 18,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                ],
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ReorderableDelayedDragStartListener(
              index: index,
              enabled: isDraggable,
              child: _buildSwipeableDeliveryCard(context, order),
            ),
          ),
        ],
      ),
    );
  }

  /// Wraps active "Out for Delivery" cards (and "Delivered" cards within the 1-hour
  /// cancellation window) in a right-to-left swipe-to-cancel gesture.
  Widget _buildSwipeableDeliveryCard(
    BuildContext context,
    DeliveryOrder order,
  ) {
    return Obx(() {
      final statusLower = order.status.value.trim().toLowerCase();
      final isOutForDelivery = statusLower == 'out for delivery';
      final isDelivered = statusLower == 'delivered';
      final isLocked = isOutForDelivery && order.isLocked;
      final canSwipe = isOutForDelivery || isDelivered;

      if (!canSwipe) {
        return _buildDeliveryCard(order);
      }

      final swipeProgress = ValueNotifier<double>(0.0);
      var hapticTriggered = false;

      return Dismissible(
        key: ValueKey(
            'delivery_swipe_${order.id}_${order.status.value}_${order.isLocked}'),
        direction: DismissDirection.endToStart,
        movementDuration: const Duration(milliseconds: 280),
        resizeDuration: const Duration(milliseconds: 240),
        onUpdate: (details) {
          swipeProgress.value = details.progress;
          if (details.reached && !hapticTriggered) {
            hapticTriggered = true;
            HapticFeedback.selectionClick();
          } else if (!details.reached) {
            hapticTriggered = false;
          }
        },
        background: isDelivered
            ? Obx(() => SwipeActionBackground(
                  progressListenable: swipeProgress,
                  isLocked: isLocked,
                  isDelivered: true,
                  isDeliveredCancelable:
                      order.canCancelDelivered(controller.currentTime.value),
                ))
            : SwipeActionBackground(
                progressListenable: swipeProgress,
                isLocked: isLocked,
                isDelivered: false,
                isDeliveredCancelable: false,
              ),
        confirmDismiss: (_) async {
          if (isDelivered) {
            final isDeliveredCancelable =
                order.canCancelDelivered(DateTime.now().toUtc());
            if (isDeliveredCancelable) {
              final action = await _promptDeliveredSwipeActionDialog(
                context,
                order,
              );
              if (action == null || !context.mounted) return false;
              if (action == 'reprint') {
                await _reprintDeliveredReceipt(context, order);
                return false;
              }
              final reason = await _promptCancelReasonDialog(
                context,
                order,
                requiresQrVerification: true,
              );
              if (reason == null || reason.trim().isEmpty) return false;
              if (!context.mounted) return false;
              await _showPaqnerCancelReceiptDialog(
                context,
                order,
                cancelReason: reason,
              );
              return false;
            } else {
              await _reprintDeliveredReceipt(context, order);
              return false;
            }
          }

          final action = await _promptSwipeActionDialog(context, order);
          if (action == null || !context.mounted) return false;

          if (action == 'lock') {
            final input = await showDeliveryAttemptDialog(
              context,
              storeName: order.storeName,
              orderId: order.id,
              currentAttemptCount: order.attemptCount,
              initialLockAndQueue: true,
            );
            if (input != null) {
              await controller.recordDeliveryAttempt(
                orderId: order.id,
                reason: input.reason,
                remarks: input.remarks,
                lockAndQueue: input.lockAndQueue,
                scheduledDateIso: input.scheduledDateIso,
              );
            }
            return false;
          }

          final reason = await _promptCancelReasonDialog(
            context,
            order,
            requiresQrVerification: false,
          );
          if (reason == null || reason.trim().isEmpty) {
            return false;
          }
          await controller.markOrderAsCancelled(order.id, reason: reason);
          return true;
        },
        child: _buildDeliveryCard(order),
      );
    });
  }

  /// 2-Way Paqner Trade Terms Cancellation Receipt Dialog:
  /// 1. Shows encoded Cancellation QR (`s="cancelled"`, `r=paymentReference`)
  ///    for the Paqner user to scan (pressable to maximize).
  /// 2. Provides "Scan Paqner Cancellation QR" to scan back the Paqner user's
  ///    confirmation QR and verify `r` + `s == 'cancelled'` before cancelling.
  Future<void> _showPaqnerCancelReceiptDialog(
    BuildContext context,
    DeliveryOrder order, {
    required String cancelReason,
  }) async {
    final paymentRef = await controller.resolveCancelPaymentReference(order);
    final amountValue = order.numericTotalAmount;
    final cleanAmountText =
        order.totalAmount.replaceAll('₱', '').trim();
    final cancelPayload = PaqnerQrCodec.buildCancelPayload(
      paymentReference: paymentRef,
      totalAmount: amountValue,
      principal: 'Monde',
    );
    final plainJson = jsonEncode(cancelPayload);
    final cancelQrData = PaqnerQrCodec.encode(cancelPayload);

    logImportant(
      'Paqner Cancel QR JSON: $plainJson',
      tag: 'CANCEL_QR',
    );
    logImportant(
      'Paqner Cancel QR Base64(GZIP): $cancelQrData',
      tag: 'CANCEL_QR',
    );

    bool isVerifying = false;

    await Get.dialog(
      StatefulBuilder(
        builder: (dialogContext, setState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.24),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Dark Header Stub
                      Container(
                        color: AppColors.surfaceDark,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.xl,
                          AppSpacing.md,
                          AppSpacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withOpacity(0.18),
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.sm),
                                    border: Border.all(
                                      color: AppColors.danger.withOpacity(0.45),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.cancel_outlined,
                                        color: Color(0xFFFF8A8A),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'CANCELLATION QR',
                                        style: AppTypography.eyebrow.copyWith(
                                          fontSize: 13,
                                          color: const Color(0xFFFF8A8A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Get.back(),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              order.storeName,
                              style: AppTypography.title.copyWith(
                                color: Colors.white,
                                fontSize: 20,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Order #${order.id}  ·  Pay Ref #$paymentRef',
                              style: AppTypography.monoRef.copyWith(
                                fontSize: 13.5,
                                color: Colors.white.withOpacity(0.75),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // White Receipt Body
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showMaximizedCancelQrDialog(
                                  context,
                                  qrData: cancelQrData,
                                  storeName: order.storeName,
                                  refText: 'Pay Ref #$paymentRef',
                                  amountText: cleanAmountText,
                                ),
                                borderRadius:
                                    BorderRadius.circular(AppRadii.md),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    QrImageView(
                                      data: cancelQrData,
                                      version: QrVersions.auto,
                                      errorCorrectionLevel:
                                          QrErrorCorrectLevel.M,
                                      size: 196.0,
                                      backgroundColor: Colors.white,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryTint,
                                        borderRadius: BorderRadius.circular(
                                            AppRadii.pill),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.open_in_full_rounded,
                                            size: 12,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Tap QR to maximize',
                                            style:
                                                AppTypography.caption.copyWith(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Divider(
                              height: 1,
                              color: AppColors.border.withOpacity(0.8),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'AMOUNT TO CANCEL',
                              style: AppTypography.eyebrow
                                  .copyWith(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text.rich(
                                PesoFormatter.buildPesoTextSpan(
                                  amount: cleanAmountText,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.inkPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.canvas,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.sm),
                              ),
                              child: Text(
                                '1. Let the Paqner user scan this QR.\n2. Tap below to scan their confirmation QR.',
                                textAlign: TextAlign.center,
                                style: AppTypography.caption.copyWith(
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            CustomButton(
                              label: 'Scan Paqner Cancellation QR',
                              icon: Icons.qr_code_scanner_rounded,
                              height: 48,
                              isLoading: isVerifying,
                              onPressed: () async {
                                setState(() => isVerifying = true);
                                final err = await controller
                                    .verifyAndCompletePaqnerCancellation(
                                  order,
                                  paymentRef,
                                  reason: cancelReason,
                                );
                                if (!dialogContext.mounted) return;
                                setState(() => isVerifying = false);

                                if (err == null) {
                                  Get.back();
                                  Get.snackbar(
                                    'Order Cancelled',
                                    '2-way Paqner cancellation verified for ${order.storeName}.',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: AppColors.successTint,
                                    colorText: AppColors.success,
                                    margin: const EdgeInsets.all(16),
                                    borderRadius: 12,
                                    duration: const Duration(seconds: 3),
                                  );
                                } else if (err != 'Scan cancelled') {
                                  Get.snackbar(
                                    'Verification Failed',
                                    err,
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: AppColors.dangerTint,
                                    colorText: AppColors.danger,
                                    margin: const EdgeInsets.all(16),
                                    borderRadius: 12,
                                    duration: const Duration(seconds: 3),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      barrierColor: AppColors.surfaceDark.withOpacity(0.65),
    );
  }

  void _showMaximizedCancelQrDialog(
    BuildContext context, {
    required String qrData,
    required String storeName,
    required String refText,
    required String amountText,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final qrBoxSize = (screenWidth - 48).clamp(240.0, 360.0);

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            storeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.title.copyWith(fontSize: 19),
                          ),
                          Text(
                            refText,
                            style: AppTypography.monoRef.copyWith(
                              fontSize: 14,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(
                        Icons.close_fullscreen_rounded,
                        color: AppColors.inkPrimary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 2.5,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    color: Colors.white,
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      size: qrBoxSize,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    PesoFormatter.buildPesoTextSpan(
                      amount: amountText,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierColor: AppColors.surfaceDark.withOpacity(0.88),
    );
  }

  Future<String?> _promptDeliveredSwipeActionDialog(
    BuildContext context,
    DeliveryOrder order,
  ) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.surface,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
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
                  'Delivered Order Options',
                  style: AppTypography.title.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.storeName} · Ref #${order.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.monoRef.copyWith(
                    fontSize: 13.5,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop('cancel'),
                        icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                        label: Text(
                          'Cancel',
                          style: AppTypography.label.copyWith(
                            fontSize: 15.5,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop('reprint'),
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: Text(
                          'Reprint',
                          style: AppTypography.label.copyWith(
                            fontSize: 15.5,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: Text(
                    'Back',
                    style: AppTypography.label.copyWith(
                      fontSize: 15.5,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _reprintDeliveredReceipt(
    BuildContext context,
    DeliveryOrder order,
  ) async {
    if (!Get.isRegistered<BluetoothPrinterService>()) return;
    final printerService = BluetoothPrinterService.to;
    final ready = await printerService.ensureConnected();
    if (!ready) {
      final devices = await printerService.getPairedPrinters();
      if (!context.mounted) return;
      final selected = await showThermalPrinterPickerDialog(context, devices);
      if (selected == null) return;
      final connected = await printerService.connectPrinter(selected);
      if (!connected) {
        Get.snackbar(
          'Printer Connection Failed',
          'Could not connect to ${selected.name}.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.dangerTint,
          colorText: AppColors.danger,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return;
      }
    }

    final db = DatabaseService.to;
    final receipts = await db.getReceipts(order.id);
    final receipt = receipts.isNotEmpty ? receipts.last : null;
    var items = await db.getOrderItems(order.id);
    if (items.isEmpty && order.transactionId != order.id) {
      items = await db.getOrderItems(order.transactionId);
    }

    final refNo = receipt?.referenceNumber.trim().isNotEmpty == true
        ? receipt!.referenceNumber.trim()
        : (order.paymentReference?.trim().isNotEmpty == true
            ? order.paymentReference!.trim()
            : order.id);
    final dateStr = receipt?.date.trim().isNotEmpty == true
        ? receipt!.date.trim()
        : (order.deliveryDate.isNotEmpty
            ? order.deliveryDate
            : DateTime.now().toIso8601String().split('T').first);
    final totalStr = receipt != null
        ? PesoFormatter.formatAmount(receipt.totalAmount)
        : PesoFormatter.formatAmount(order.numericTotalAmount);

    final printed = await printerService.printDeliveryReceipt(
      customerName: order.storeName,
      referenceNumber: refNo,
      date: dateStr,
      totalAmount: totalStr,
      items: items,
    );

    Get.snackbar(
      printed ? 'Receipt Reprinted' : 'Reprint Failed',
      printed
          ? 'Delivery receipt for ${order.storeName} sent to thermal printer.'
          : 'Please check Bluetooth printer paper and connection.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor:
          printed ? AppColors.successTint : AppColors.dangerTint,
      colorText: printed ? AppColors.success : AppColors.danger,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  Future<String?> _promptSwipeActionDialog(
    BuildContext context,
    DeliveryOrder order,
  ) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.surface,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
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
                  'Choose Action',
                  style: AppTypography.title.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.storeName} · Ref #${order.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.monoRef.copyWith(
                    fontSize: 13.5,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop('lock'),
                        icon: const Icon(Icons.lock_clock_outlined, size: 18),
                        label: Text(
                          'Lock & Queue',
                          style: AppTypography.label.copyWith(
                            fontSize: 15.5,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop('cancel'),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: Text(
                          'Cancel Order',
                          style: AppTypography.label.copyWith(
                            fontSize: 15.5,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: Text(
                    'Back',
                    style: AppTypography.label.copyWith(
                      fontSize: 15.5,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _promptCancelReasonDialog(
    BuildContext context,
    DeliveryOrder order, {
    bool requiresQrVerification = false,
  }) {
    const presetReasons = <String>[
      'Store Closed',
      'Customer Refused Order',
      'Damaged / Incomplete Items',
      'Wrong Address / Unreachable',
      'Customer Requested Cancellation',
      'Others',
    ];

    String selectedReason = presetReasons.first;
    final customController = TextEditingController();
    String? errorText;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) {
          final isOthers = selectedReason == 'Others';
          return Dialog(
            backgroundColor: AppColors.surface,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              side: const BorderSide(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.dangerTint,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(color: AppColors.dangerBorder),
                        ),
                        child: const Icon(
                          Icons.cancel_outlined,
                          color: AppColors.danger,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cancellation Reason',
                              style: AppTypography.title.copyWith(fontSize: 20),
                            ),
                            Text(
                              '${order.storeName} · Ref #${order.id}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.monoRef.copyWith(
                                fontSize: 13.5,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Select a reason or choose Others to enter remarks:',
                    style: AppTypography.caption.copyWith(
                      fontSize: 15,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.danger,
                    ),
                    dropdownColor: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    style: AppTypography.body.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkPrimary,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.canvas,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 4,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        borderSide:
                            const BorderSide(color: AppColors.dangerBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        borderSide: const BorderSide(
                          color: AppColors.danger,
                          width: 1.5,
                        ),
                      ),
                    ),
                    items: presetReasons
                        .map(
                          (reason) => DropdownMenuItem<String>(
                            value: reason,
                            child: Text(
                              reason,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (reason) {
                      if (reason == null) return;
                      setState(() {
                        selectedReason = reason;
                        errorText = null;
                      });
                    },
                  ),
                  if (isOthers) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: customController,
                      maxLines: 2,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        if (errorText != null) {
                          setState(() => errorText = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Enter cancellation remarks...',
                        errorText: errorText,
                        filled: true,
                        fillColor: AppColors.canvas,
                        contentPadding: const EdgeInsets.all(AppSpacing.md),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          borderSide:
                              const BorderSide(color: AppColors.danger),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(null),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.inkSecondary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                          ),
                          child: Text(
                            'Keep',
                            style: AppTypography.label.copyWith(
                              fontSize: 17,
                              color: AppColors.inkSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final finalReason = isOthers
                                ? customController.text.trim()
                                : selectedReason;
                            if (finalReason.isEmpty) {
                              setState(() {
                                errorText = 'Please enter cancellation remarks';
                              });
                              return;
                            }
                            Navigator.of(dialogContext).pop(finalReason);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                          ),
                          child: Text(
                            requiresQrVerification
                                ? 'Proceed to QR'
                                : 'Cancel Order',
                            style: AppTypography.label.copyWith(
                              fontSize: 17,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Compact, clean 2-row delivery card designed so 2+ cards fit comfortably
  /// in the viewport at once.
  Widget _buildDeliveryCard(DeliveryOrder order) {
    return Obx(() {
      final isDelivered = order.status.value == 'Delivered';
      final isCancelled = order.status.value == 'Cancelled';
      final isLocked = order.isLocked && !isDelivered && !isCancelled;

      final metaParts = <String>[
        if (order.routeSequence != null) '#${order.routeSequence}',
        'Ref #${order.id}',
        '${order.sku} ${order.sku == '1' ? 'SKU' : 'SKUs'}',
        if (order.deliveryDate.isNotEmpty) order.deliveryDate else 'Scheduled',
      ];

      final Color borderColor = isLocked
          ? AppColors.warningBorder
          : isDelivered
              ? AppColors.successBorder
              : isCancelled
                  ? AppColors.dangerBorder
                  : AppColors.border;

      return Container(
        decoration: BoxDecoration(
          color: isLocked ? AppColors.surfaceMuted : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.surfaceDark.withOpacity(0.025),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            splashColor: AppColors.primary.withOpacity(0.05),
            highlightColor: AppColors.primary.withOpacity(0.03),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            onTap: () => Get.toNamed(AppRoutes.orderDetails, arguments: order),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Compact Store Header Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      StoreImageWidget(
                        imageUrl: order.storePhoto,
                        custCode: order.custCode,
                        width: 44,
                        height: 44,
                        borderRadius: BorderRadius.circular(AppRadii.sm + 2),
                        fallback: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius:
                                BorderRadius.circular(AppRadii.sm + 2),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.storeName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.title.copyWith(
                                fontSize: 17.5,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.address.isNotEmpty
                                  ? order.address
                                  : 'No delivery address listed',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body.copyWith(
                                fontSize: 14,
                                color: AppColors.inkSecondary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    metaParts.join('  ·  '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.monoRef.copyWith(
                                      fontSize: 12.5,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ),
                                if (order.attemptCount > 0 && !isDelivered)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.warningTint,
                                      borderRadius:
                                          BorderRadius.circular(AppRadii.sm),
                                      border: Border.all(
                                        color: AppColors.warningBorder,
                                      ),
                                    ),
                                    child: Text(
                                      'Attempt #${order.attemptCount}',
                                      style: AppTypography.monoRef.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ── Amount & Distance Strip ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            PesoFormatter.buildPesoTextSpan(
                              amount: order.totalAmount
                                  .replaceAll('₱', '')
                                  .trim(),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: isCancelled
                                  ? AppColors.inkMuted
                                  : AppColors.inkPrimary,
                            ),
                          ),
                        ),
                        Obx(() {
                          final distanceBadge =
                              controller.liveDistanceLabels[order.id] ??
                                  order.formattedDistanceAway;
                          if (distanceBadge.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Material(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            child: InkWell(
                              onTap: () =>
                                  controller.openOrderNavigation(order),
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.pill),
                                  border: Border.all(
                                    color: AppColors.primaryBorder,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.directions_rounded,
                                      size: 12,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      distanceBadge,
                                      style: AppTypography.monoRef.copyWith(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 2. Dedicated Bottom Action Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isDelivered)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Obx(() {
                              final remaining = order.remainingCancelDuration(
                                controller.currentTime.value,
                              );
                              final mins = remaining.inMinutes;
                              final secs = remaining.inSeconds % 60;
                              final active = remaining > Duration.zero;
                              if (!active) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                                  style: AppTypography.monoRef.copyWith(
                                    fontSize: 12,
                                    color: AppColors.warning,
                                  ),
                                ),
                              );
                            }),
                            const StatusPill(
                              label: 'Delivered',
                              isPositive: true,
                              icon: Icons.check_circle_outline_rounded,
                            ),
                          ],
                        )
                      else if (isCancelled)
                        const StatusPill(
                          label: 'Cancelled',
                          isPositive: false,
                          isDanger: true,
                          icon: Icons.cancel_outlined,
                        )
                      else if (isLocked)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warningTint,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.sm),
                                border: Border.all(
                                  color: AppColors.warningBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.lock_clock_outlined,
                                    size: 12,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    order.scheduledDeliveryDate != null &&
                                            order.scheduledDeliveryDate!
                                                .isNotEmpty
                                        ? HomeController.formatDateLabel(
                                            order.scheduledDeliveryDate!)
                                        : 'Queued',
                                    style: AppTypography.monoRef.copyWith(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            OutlinedButton(
                              onPressed: () async {
                                final tomorrow = DateTime.now()
                                    .add(const Duration(days: 1));
                                final picked = await showAppDatePicker(
                                  context: Get.context!,
                                  initialDate: DateTime.tryParse(
                                          order.scheduledDeliveryDate ?? '') ??
                                      tomorrow,
                                  firstDate: tomorrow,
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 60)),
                                );
                                if (picked != null) {
                                  final iso =
                                      '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                  await controller.rescheduleLockedOrder(
                                      order.id, iso);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                    color: AppColors.primaryBorder),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 5),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Date',
                                style: AppTypography.label.copyWith(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            ElevatedButton(
                              onPressed: () =>
                                  controller.unlockOrder(order.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.warning,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 5),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Unlock',
                                style: AppTypography.label.copyWith(
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Expanded(
                          child: Row(
                            children: [
                              Tooltip(
                                message: order.customerPhone.trim().isNotEmpty
                                    ? 'Copy & Call ${order.customerPhone}'
                                    : 'Add Customer Phone',
                                child: Material(
                                  color: AppColors.primaryTint,
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.sm),
                                  child: InkWell(
                                    onTap: () {
                                      final phone = order.customerPhone.trim();
                                      if (phone.isEmpty) {
                                        Get.toNamed(
                                          AppRoutes.orderDetails,
                                          arguments: order,
                                        );
                                      } else {
                                        Clipboard.setData(
                                            ClipboardData(text: phone));
                                        Get.snackbar(
                                          'Customer Phone Copied',
                                          '$phone copied for ${order.storeName}',
                                          snackPosition: SnackPosition.BOTTOM,
                                          margin: const EdgeInsets.all(16),
                                          borderRadius: 12,
                                          duration: const Duration(seconds: 2),
                                        );
                                      }
                                    },
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.sm),
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(AppRadii.sm),
                                        border: Border.all(
                                          color: AppColors.primaryBorder,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.phone_outlined,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Tooltip(
                                message: 'Navigate to Stop',
                                child: Material(
                                  color: AppColors.successTint,
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.sm),
                                  child: InkWell(
                                    onTap: () =>
                                        controller.openOrderNavigation(order),
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.sm),
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(AppRadii.sm),
                                        border: Border.all(
                                          color: AppColors.successBorder,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.near_me_outlined,
                                        size: 16,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Material(
                              color: AppColors.warningTint,
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                              child: InkWell(
                                onTap: () async {
                                  final input = await showDeliveryAttemptDialog(
                                    Get.context!,
                                    storeName: order.storeName,
                                    orderId: order.id,
                                    currentAttemptCount: order.attemptCount,
                                  );
                                  if (input != null) {
                                    await controller.recordDeliveryAttempt(
                                      orderId: order.id,
                                      reason: input.reason,
                                      remarks: input.remarks,
                                      lockAndQueue: input.lockAndQueue,
                                      scheduledDateIso: input.scheduledDateIso,
                                    );
                                  }
                                },
                                borderRadius:
                                    BorderRadius.circular(AppRadii.sm),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.sm),
                                    border: Border.all(
                                      color: AppColors.warningBorder,
                                    ),
                                  ),
                                  child: Text(
                                    'Attempt',
                                    style: AppTypography.label.copyWith(
                                      fontSize: 14,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.sm),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Deliver',
                                    style: AppTypography.label.copyWith(
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  /// Clean floating-feel white Bottom Utility Bar without divider lines.
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.xl),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.surfaceDark.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 10,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBottomBarItem(
                svgPath: 'assets/icons/resync-icon.svg',
                label: 'Resync',
                isPrimary: true,
                onTap: () {
                  if (controller.isPostUnlockTouchGuardActive) return;
                  controller.showSyncDialog();
                },
              ),
              _buildBottomBarItem(
                svgPath: 'assets/icons/endofday_icon.svg',
                label: 'End of Day',
                isPrimary: false,
                onTap: () {
                  if (controller.isPostUnlockTouchGuardActive) return;
                  Get.toNamed(AppRoutes.endOfDay);
                },
              ),
              _buildBottomBarItem(
                svgPath: 'assets/icons/date-icon.svg',
                label: 'Date',
                isPrimary: false,
                onTap: () {
                  if (controller.isPostUnlockTouchGuardActive) return;
                  Get.toNamed(AppRoutes.routeCalendar);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBarItem({
    required String svgPath,
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final color = isPrimary ? AppColors.primary : AppColors.inkMuted;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isPrimary ? AppColors.primaryTint : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: SvgPicture.asset(
                    svgPath,
                    width: 22,
                    height: 22,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    fontSize: 15.5,
                    fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
                    color: color,
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
