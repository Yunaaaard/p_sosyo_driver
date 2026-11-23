import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/core/utils/peso_formatter.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';
import 'package:p_sosyo_driver/app/modules/route_planner/controller/route_planner_controller.dart';
import 'package:p_sosyo_driver/app/widgets/custom_appBar.dart';
import 'package:p_sosyo_driver/app/widgets/custom_button.dart';
import 'package:p_sosyo_driver/app/widgets/status_badge.dart';
import 'package:p_sosyo_driver/app/widgets/store_image_widget.dart';

class RoutePlannerPage extends GetView<RoutePlannerController> {
  const RoutePlannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const CustomAppBar(
        title: 'Route Planner',
        showBackButton: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }

        final isTodayMode = controller.mode.value == 'today';
        final activeDayIso = controller.selectedDayIso;
        final List<DeliveryOrder> displayedStops = isTodayMode
            ? controller.todayStops
            : (controller.weeklyDayBuckets[activeDayIso] ?? []);
        final double dayValue = displayedStops.fold<double>(
          0.0,
          (sum, o) => sum + o.numericTotalAmount,
        );
        final int overdueCount =
            displayedStops.where((o) => controller.isOverdue(o)).length;

        return SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Mode Switcher ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ModeTabButton(
                              label: "Today's Route",
                              selected: isTodayMode,
                              onTap: () => controller.switchMode('today'),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _ModeTabButton(
                              label: 'Weekly (Mon–Sat)',
                              selected: !isTodayMode,
                              onTap: () => controller.switchMode('weekly'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ── Dark Route Summary Banner ─────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(color: AppColors.surfaceDarkBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isTodayMode
                                      ? 'TODAY · ${HomeController.formatDateLabel(controller.todayIso).toUpperCase()}'
                                      : HomeController.formatDateLabel(
                                              activeDayIso)
                                          .toUpperCase(),
                                  style: AppTypography.eyebrow.copyWith(
                                    fontSize: 12,
                                    color: AppColors.mint,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${displayedStops.length} ${displayedStops.length == 1 ? 'stop' : 'stops'} · Drag to set sequence',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text.rich(
                                PesoFormatter.buildPesoTextSpan(
                                  amount: PesoFormatter.formatAmount(dayValue),
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              if (overdueCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withOpacity(0.25),
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.pill),
                                  ),
                                  child: Text(
                                    '$overdueCount overdue',
                                    style: AppTypography.monoRef.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFFF8A8A),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (!isTodayMode) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Select day & insert or move stops:',
                              style: AppTypography.caption.copyWith(
                                fontSize: 13.5,
                                color: AppColors.inkSecondary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.only(left: 10, right: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Sun',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Switch.adaptive(
                                  value: controller.includeSunday.value,
                                  activeColor: AppColors.primary,
                                  onChanged: controller.toggleIncludeSunday,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SizedBox(
                        height: 56,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: controller.activeWeekDays.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 6),
                          itemBuilder: (_, idx) {
                            final day = controller.activeWeekDays[idx];
                            final iso = RoutePlannerController.toIsoDate(day);
                            final count =
                                (controller.weeklyDayBuckets[iso] ?? []).length;
                            final selected =
                                controller.selectedDayIndex.value == idx;
                            const wk = [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun'
                            ];
                            return InkWell(
                              onTap: () =>
                                  controller.selectedDayIndex.value = idx,
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.surface,
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.md),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${wk[day.weekday - 1]} ${day.month}/${day.day}',
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: selected
                                            ? Colors.white
                                            : AppColors.inkPrimary,
                                      ),
                                    ),
                                    Text(
                                      '$count ${count == 1 ? 'stop' : 'stops'}',
                                      style: AppTypography.monoRef.copyWith(
                                        fontSize: 11,
                                        color: selected
                                            ? Colors.white.withOpacity(0.85)
                                            : AppColors.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),

                    // ── Quick Actions Row: Auto-Suggest + Insert Stop ──
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isTodayMode
                                ? controller.autoSuggestTodayOrder
                                : controller.autoOptimizeWeeklyPlan,
                            icon: const Icon(Icons.auto_awesome_rounded,
                                size: 17),
                            label: Text(
                              isTodayMode
                                  ? 'Auto-Suggest Order'
                                  : 'Auto-Sort by Unloading Date',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label.copyWith(
                                fontSize: 13.5,
                                color: AppColors.primary,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              backgroundColor: AppColors.primaryTint,
                              side: const BorderSide(
                                  color: AppColors.primaryBorder),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadii.md),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showInsertStopSheet(
                            context,
                            isTodayMode: isTodayMode,
                            targetDayIso: activeDayIso,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Insert Stop',
                                style: AppTypography.label.copyWith(
                                  fontSize: 13.5,
                                  color: AppColors.inkPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryTint,
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.pill),
                                ),
                                child: Text(
                                  '${controller.allOutForDeliveryOrders.length}',
                                  style: AppTypography.monoRef.copyWith(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.inkPrimary,
                            backgroundColor: AppColors.surface,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Draggable Timeline Stop List ────────────────────────
              Expanded(
                child: displayedStops.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.alt_route_rounded,
                                size: 32,
                                color: AppColors.inkMuted,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'No stops queued for this day.\nTap "Insert Stop" to add deliveries here.',
                                textAlign: TextAlign.center,
                                style: AppTypography.body.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.xs,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        buildDefaultDragHandles: false,
                        proxyDecorator: (child, index, animation) {
                          return Material(
                            color: Colors.transparent,
                            elevation: 6,
                            shadowColor: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            child: child,
                          );
                        },
                        itemCount: displayedStops.length,
                        onReorder: (oldIndex, newIndex) {
                          if (isTodayMode) {
                            controller.reorderTodayStops(oldIndex, newIndex);
                          } else {
                            controller.reorderWeeklyDayStops(
                              activeDayIso,
                              oldIndex,
                              newIndex,
                            );
                          }
                        },
                        itemBuilder: (context, index) {
                          final order = displayedStops[index];
                          final overdue = controller.isOverdue(order);
                          final isLast = index == displayedStops.length - 1;

                          return Padding(
                            key: ValueKey('planner_${order.id}'),
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: 34,
                                    child: Column(
                                      children: [
                                        const SizedBox(height: 12),
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: index == 0
                                                ? AppColors.primary
                                                : AppColors.surface,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: index == 0
                                                  ? AppColors.primary
                                                  : AppColors.primaryBorder,
                                              width: 1.6,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${index + 1}',
                                            style:
                                                AppTypography.monoRef.copyWith(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: index == 0
                                                  ? Colors.white
                                                  : AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: const Padding(
                                            padding: EdgeInsets.all(3),
                                            child: Icon(
                                              Icons.drag_indicator_rounded,
                                              size: 17,
                                              color: AppColors.inkMuted,
                                            ),
                                          ),
                                        ),
                                        if (!isLast)
                                          Expanded(
                                            child: Container(
                                              width: 2,
                                              color: AppColors.border,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SurfaceCard(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.sm + 2,
                                      ),
                                      child: Row(
                                        children: [
                                          StoreImageWidget(
                                            imageUrl: order.storePhoto,
                                            custCode: order.custCode,
                                            width: 40,
                                            height: 40,
                                            borderRadius: BorderRadius.circular(
                                                AppRadii.sm),
                                            fallback: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryTint,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        AppRadii.sm),
                                              ),
                                              child: const Icon(
                                                Icons.storefront_rounded,
                                                size: 18,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  order.storeName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AppTypography.label
                                                      .copyWith(fontSize: 15.5),
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    if (order.isLocked || order.attemptCount > 0)
                                                      Container(
                                                        margin: const EdgeInsets
                                                            .only(right: 5),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 5,
                                                          vertical: 1,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: AppColors
                                                              .warningTint,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      AppRadii
                                                                          .sm),
                                                        ),
                                                        child: Text(
                                                          '${order.attemptCount} ${order.attemptCount == 1 ? 'ATTEMPT' : 'ATTEMPTS'}',
                                                          style: AppTypography
                                                              .monoRef
                                                              .copyWith(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: AppColors
                                                                .warning,
                                                          ),
                                                        ),
                                                      ),
                                                    if (overdue)
                                                      Container(
                                                        margin: const EdgeInsets
                                                            .only(right: 5),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 5,
                                                          vertical: 1,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: AppColors
                                                              .dangerTint,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      AppRadii
                                                                          .sm),
                                                        ),
                                                        child: Text(
                                                          'OVERDUE',
                                                          style: AppTypography
                                                              .monoRef
                                                              .copyWith(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: AppColors
                                                                .danger,
                                                          ),
                                                        ),
                                                      ),
                                                    Expanded(
                                                      child: Text(
                                                        '${order.formattedDistanceAway} · ${order.deliveryDate}',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: AppTypography
                                                            .monoRef
                                                            .copyWith(
                                                          fontSize: 11.5,
                                                          color: AppColors
                                                              .inkMuted,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text.rich(
                                                PesoFormatter.buildPesoTextSpan(
                                                  amount: order.totalAmount
                                                      .replaceAll('₱', '')
                                                      .trim(),
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.inkPrimary,
                                                ),
                                              ),
                                              if (!isTodayMode)
                                                GestureDetector(
                                                  onTap: () =>
                                                      _showMoveToDayDialog(
                                                    context,
                                                    order,
                                                    activeDayIso,
                                                  ),
                                                  child: Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            top: 4),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2.5,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          AppColors.primaryTint,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              AppRadii.sm),
                                                      border: Border.all(
                                                        color: AppColors
                                                            .primaryBorder,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      'Move Day',
                                                      style: AppTypography
                                                          .caption
                                                          .copyWith(
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // ── Apply Route Plan Bar ────────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: CustomButton(
                  label: isTodayMode
                      ? 'Apply Today Route (${controller.todayStops.length} stops)'
                      : 'Apply Weekly Route Plan',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: controller.applyRoutePlan,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _showMoveToDayDialog(
    BuildContext context,
    DeliveryOrder order,
    String currentDayIso,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
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
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: const Icon(
                      Icons.drive_file_move_outlined,
                      size: 19,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Move to Day',
                          style: AppTypography.title.copyWith(fontSize: 19),
                        ),
                        Text(
                          order.storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: controller.activeWeekDays.map((day) {
                  final iso = RoutePlannerController.toIsoDate(day);
                  final isCurrent = iso == currentDayIso;
                  return ChoiceChip(
                    label: Text(
                      HomeController.formatDateLabel(iso),
                      style: AppTypography.caption.copyWith(
                        fontSize: 14,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent
                            ? AppColors.primary
                            : AppColors.inkPrimary,
                      ),
                    ),
                    selected: isCurrent,
                    selectedColor: AppColors.primaryTint,
                    backgroundColor: AppColors.canvas,
                    side: BorderSide(
                      color: isCurrent
                          ? AppColors.primaryBorder
                          : AppColors.border,
                    ),
                    onSelected: (_) {
                      Navigator.of(dialogContext).pop();
                      if (!isCurrent) {
                        controller.moveOrderToDay(order, iso);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
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
    );
  }

  void _showInsertStopSheet(
    BuildContext context, {
    required bool isTodayMode,
    required String targetDayIso,
  }) {
    final candidates = isTodayMode
        ? controller.ordersNotInToday
        : controller.weeklyInsertCandidates(targetDayIso);
    final selectableCandidates = isTodayMode
        ? candidates
        : candidates
            .where((o) => controller.assignedDayIsoForOrder(o.id) != targetDayIso)
            .toList();

    final selectedIds = <String>{};

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final allSelected = selectableCandidates.isNotEmpty &&
                selectedIds.length == selectableCandidates.length;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isTodayMode
                                    ? 'Insert Stops into Today'
                                    : 'Insert Stops into ${HomeController.formatDateLabel(targetDayIso)}',
                                style: AppTypography.title.copyWith(fontSize: 19),
                              ),
                              Text(
                                '${controller.allOutForDeliveryOrders.length} synced · ${selectableCandidates.length} available to add',
                                style: AppTypography.monoRef.copyWith(
                                  fontSize: 12,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selectableCandidates.length > 1)
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                if (allSelected) {
                                  selectedIds.clear();
                                } else {
                                  selectedIds.addAll(
                                    selectableCandidates.map((c) => c.id),
                                  );
                                }
                              });
                            },
                            child: Text(
                              allSelected ? 'Clear' : 'Select All',
                              style: AppTypography.label.copyWith(
                                fontSize: 13.5,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (candidates.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'All active orders are already included.',
                          textAlign: TextAlign.center,
                          style: AppTypography.body.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      )
                    else ...[
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 340),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: candidates.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, idx) {
                            final o = candidates[idx];
                            final assignedDayIso = isTodayMode
                                ? null
                                : controller.assignedDayIsoForOrder(o.id);
                            final alreadyOnTargetDay =
                                !isTodayMode && assignedDayIso == targetDayIso;
                            final isSelected = selectedIds.contains(o.id);
                            final unloadingIso =
                                o.deliveryDate.trim().length >= 10
                                    ? o.deliveryDate.trim().substring(0, 10)
                                    : o.deliveryDate.trim();
                            final compareIso =
                                isTodayMode ? controller.todayIso : targetDayIso;
                            final isOtherDate = unloadingIso.isNotEmpty &&
                                unloadingIso != compareIso;
                            final lockReason =
                                o.lastAttemptReason?.trim() ?? '';

                            return SurfaceCard(
                              padding: EdgeInsets.zero,
                              borderColor: alreadyOnTargetDay
                                  ? AppColors.successBorder
                                  : isSelected
                                      ? AppColors.primaryBorder
                                      : AppColors.border,
                              child: ListTile(
                                enabled: !alreadyOnTargetDay,
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        o.storeName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.label.copyWith(
                                          color: alreadyOnTargetDay
                                              ? AppColors.inkMuted
                                              : AppColors.inkPrimary,
                                        ),
                                      ),
                                    ),
                                    if (alreadyOnTargetDay)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.successTint,
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.pill,
                                          ),
                                        ),
                                        child: Text(
                                          'Already on ${HomeController.formatDateLabel(targetDayIso)}',
                                          style: AppTypography.monoRef.copyWith(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      )
                                    else if (o.isLocked || o.attemptCount > 0)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.warningTint,
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.pill,
                                          ),
                                        ),
                                        child: Text(
                                          o.isLocked
                                              ? 'Locked • ${o.attemptCount} ${o.attemptCount == 1 ? 'Attempt' : 'Attempts'}'
                                              : '${o.attemptCount} ${o.attemptCount == 1 ? 'Attempt' : 'Attempts'}',
                                          style: AppTypography.monoRef.copyWith(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.warning,
                                          ),
                                        ),
                                      )
                                    else if (!isTodayMode &&
                                        assignedDayIso != null)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryTint,
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.pill,
                                          ),
                                        ),
                                        child: Text(
                                          'On ${HomeController.formatDateLabel(assignedDayIso)}',
                                          style: AppTypography.monoRef.copyWith(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      )
                                    else if (isOtherDate)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryTint,
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.pill,
                                          ),
                                        ),
                                        child: Text(
                                          'Unloading: $unloadingIso',
                                          style: AppTypography.monoRef.copyWith(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  o.isLocked && lockReason.isNotEmpty
                                      ? 'Ref #${o.id} · $lockReason · ${o.formattedDistanceAway}'
                                      : 'Ref #${o.id} · ${o.deliveryDate} · ${o.formattedDistanceAway}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.monoRef
                                      .copyWith(fontSize: 12),
                                ),
                                trailing: Icon(
                                  alreadyOnTargetDay
                                      ? Icons.check_circle_outline_rounded
                                      : isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons
                                              .radio_button_unchecked_rounded,
                                  color: alreadyOnTargetDay
                                      ? AppColors.success
                                      : isSelected
                                          ? AppColors.primary
                                          : AppColors.inkMuted,
                                ),
                                onTap: alreadyOnTargetDay
                                    ? null
                                    : () {
                                        setSheetState(() {
                                          if (isSelected) {
                                            selectedIds.remove(o.id);
                                          } else {
                                            selectedIds.add(o.id);
                                          }
                                        });
                                      },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton.icon(
                        onPressed: selectedIds.isEmpty
                            ? null
                            : () {
                                final selectedOrders = candidates
                                    .where((o) => selectedIds.contains(o.id))
                                    .toList();
                                Navigator.of(sheetContext).pop();
                                if (isTodayMode) {
                                  controller.insertOrdersIntoToday(
                                    selectedOrders,
                                  );
                                } else {
                                  controller.moveOrdersToDay(
                                    selectedOrders,
                                    targetDayIso,
                                  );
                                }
                              },
                        icon: const Icon(Icons.playlist_add_check_rounded),
                        label: Text(
                          selectedIds.isEmpty
                              ? 'Select Stops to Add'
                              : 'Add ${selectedIds.length} ${selectedIds.length == 1 ? 'Stop' : 'Stops'}',
                          style: AppTypography.label.copyWith(
                            color: selectedIds.isEmpty
                                ? AppColors.inkMuted
                                : Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.surfaceMuted,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md),
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
      },
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.sm + 2),
          border: selected ? Border.all(color: AppColors.border) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            fontSize: 14.5,
            color: selected ? AppColors.primary : AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}
