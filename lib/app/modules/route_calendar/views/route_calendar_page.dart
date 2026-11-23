import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/core/utils/peso_formatter.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';
import 'package:p_sosyo_driver/app/modules/route_calendar/controller/route_calendar_controller.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';
import 'package:p_sosyo_driver/app/widgets/custom_appBar.dart';
import 'package:p_sosyo_driver/app/widgets/route_plan_progress_dialog.dart';
import 'package:p_sosyo_driver/app/widgets/status_badge.dart';
import 'package:p_sosyo_driver/app/widgets/store_image_widget.dart';

class RouteCalendarPage extends GetView<RouteCalendarController> {
  const RouteCalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: CustomAppBar(
        title: 'Route Calendar',
        showBackButton: true,
        trailing: TextButton(
          onPressed: controller.jumpToToday,
          child: Text(
            'Today',
            style: AppTypography.label.copyWith(
              fontSize: 15.5,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }

        final dayOrders = controller.selectedDateOrders;
        final activeHomeFilter = Get.isRegistered<HomeController>()
            ? Get.find<HomeController>().selectedDateFilter.value
            : null;
        final isThisDateActiveOnHome =
            activeHomeFilter == controller.selectedDateIso;

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Weekly & Monthly Performance Analytics Card ────
                _buildAnalyticsHeaderCard(),
                const SizedBox(height: AppSpacing.md),

                // ── 1b. Weekly Route Plan Generator CTA ───────────────
                OutlinedButton.icon(
                  onPressed: () => _showGenerateWeeklyPlanDialog(context),
                  icon: const Icon(Icons.alt_route_rounded, size: 19),
                  label: Text(
                    'Generate Weekly Route Plan (${controller.unlockedOutForDeliveryCount} active)',
                    style: AppTypography.label.copyWith(
                      fontSize: 15.5,
                      color: AppColors.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: AppColors.primaryTint,
                    side: const BorderSide(color: AppColors.primaryBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── 2. Interactive Monthly Calendar Grid ──────────────
                _buildMonthCalendarCard(),
                const SizedBox(height: AppSpacing.lg),

                // ── 3. Selected Date Header & Date Setter ─────────────
                SurfaceCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(color: AppColors.primaryBorder),
                        ),
                        child: const Icon(
                          Icons.event_available_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              controller.selectedDateLabel,
                              style: AppTypography.title.copyWith(fontSize: 18),
                            ),
                            Text(
                              '${dayOrders.length} ${dayOrders.length == 1 ? 'route stop' : 'route stops'} on this date',
                              style: AppTypography.caption.copyWith(
                                fontSize: 14,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isThisDateActiveOnHome)
                        OutlinedButton(
                          onPressed: controller.clearHomeDateFilter,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side:
                                const BorderSide(color: AppColors.dangerBorder),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          child: Text(
                            'Show All',
                            style: AppTypography.label.copyWith(
                              fontSize: 14.5,
                              color: AppColors.danger,
                            ),
                          ),
                        )
                      else
                        ElevatedButton(
                          onPressed: controller.applySelectedDateToHome,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                          ),
                          child: Text(
                            'Use This Date',
                            style: AppTypography.label.copyWith(
                              fontSize: 14.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── 4. Selected Day Routes & Past Transactions ────────
                SectionHeader(
                  title: 'Routes & Transactions',
                  count: dayOrders.length,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (dayOrders.isEmpty)
                  SurfaceCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.xxl,
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 28,
                          color: AppColors.inkMuted,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'No Deliveries on ${controller.selectedDateLabel}',
                          textAlign: TextAlign.center,
                          style: AppTypography.label.copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select another day on the calendar above to view past transactions or scheduled routes.',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption.copyWith(
                            fontSize: 14.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...dayOrders.map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
                      child: _buildDayOrderCard(order),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAnalyticsHeaderCard() {
    final period = controller.analyticsPeriod.value;
    final pct = (controller.periodCompletionRate * 100).round();
    final buckets = controller.periodBuckets;
    final maxVal = buckets.fold<double>(
      1.0,
      (prev, b) => b.collectedAmount > prev ? b.collectedAmount : prev,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.surfaceDarkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DRIVER ANALYTICS',
                style: AppTypography.eyebrow.copyWith(
                  fontSize: 12.5,
                  color: AppColors.mint,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['Weekly', 'Monthly'].map((p) {
                    final selected = period == p;
                    return GestureDetector(
                      onTap: () => controller.setAnalyticsPeriod(p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          p,
                          style: AppTypography.caption.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text.rich(
            PesoFormatter.buildPesoTextSpan(
              amount:
                  PesoFormatter.formatAmount(controller.periodCollectedAmount),
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'of ₱ ${PesoFormatter.formatAmount(controller.periodTargetAmount)} target · $pct% delivered (${controller.periodDeliveredCount}/${controller.periodOrders.length})',
            style: AppTypography.caption.copyWith(
              fontSize: 14,
              color: Colors.white.withOpacity(0.75),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Mini Bar Chart
          SizedBox(
            height: 76,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: buckets.map((b) {
                final ratio = (b.collectedAmount / maxVal).clamp(0.0, 1.0);
                final hasStops = b.totalCount > 0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${b.deliveredCount}/${b.totalCount}',
                          style: AppTypography.monoRef.copyWith(
                            fontSize: 10.5,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 36 * (ratio > 0 ? ratio.clamp(0.18, 1.0) : (hasStops ? 0.14 : 0.06)),
                          decoration: BoxDecoration(
                            color: ratio > 0
                                ? AppColors.mint
                                : Colors.white.withOpacity(hasStops ? 0.35 : 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          b.label,
                          style: AppTypography.caption.copyWith(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniPill(
                'Delivered: ${controller.periodDeliveredCount}',
                AppColors.mint,
              ),
              _buildMiniPill(
                'Active: ${controller.periodActiveCount}',
                Colors.white,
              ),
              _buildMiniPill(
                'Queued: ${controller.periodQueuedCount}',
                const Color(0xFFFCD34D),
              ),
              _buildMiniPill(
                'Cancelled: ${controller.periodCancelledCount}',
                const Color(0xFFFF8A8A),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPill(String text, Color color) {
    return Text(
      text,
      style: AppTypography.monoRef.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  Widget _buildMonthCalendarCard() {
    final month = controller.focusedMonth.value;
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Sunday=0 .. Saturday=6
    final leadingEmpty = firstDay.weekday % 7;
    final totalCells = leadingEmpty + daysInMonth;
    final selectedIso = controller.selectedDateIso;
    final phtNow = DateTime.now().toUtc().add(const Duration(hours: 8));
    final todayIso = RouteCalendarController.toIsoDate(phtNow);

    const weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: controller.previousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
                visualDensity: VisualDensity.compact,
              ),
              Text(
                controller.focusedMonthTitle,
                style: AppTypography.title.copyWith(fontSize: 19),
              ),
              IconButton(
                onPressed: controller.nextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: weekdays
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: AppTypography.eyebrow.copyWith(
                          fontSize: 11.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (_, index) {
              if (index < leadingEmpty) {
                return const SizedBox.shrink();
              }
              final dayNum = index - leadingEmpty + 1;
              final date = DateTime(month.year, month.month, dayNum);
              final iso = RouteCalendarController.toIsoDate(date);
              final isSelected = iso == selectedIso;
              final isToday = iso == todayIso;
              final st = controller.statusForDate(date);

              return InkWell(
                onTap: () => controller.selectDay(date),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (st.totalCount > 0
                            ? AppColors.primaryTint.withOpacity(0.55)
                            : AppColors.canvas),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isToday ? AppColors.primaryBorder : AppColors.border),
                      width: isToday && !isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: AppTypography.label.copyWith(
                          fontSize: 15,
                          color: isSelected
                              ? Colors.white
                              : AppColors.inkPrimary,
                        ),
                      ),
                      if (st.totalCount > 0) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (st.deliveredCount > 0)
                              _buildStatusDot(
                                isSelected ? Colors.white : AppColors.success,
                              ),
                            if (st.activeCount > 0)
                              _buildStatusDot(
                                isSelected ? Colors.white : AppColors.primary,
                              ),
                            if (st.queuedCount > 0)
                              _buildStatusDot(
                                isSelected ? Colors.white : AppColors.warning,
                              ),
                            if (st.cancelledCount > 0)
                              _buildStatusDot(
                                isSelected ? Colors.white : AppColors.danger,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('Delivered', AppColors.success),
              _buildLegendItem('Active', AppColors.primary),
              _buildLegendItem('Queued', AppColors.warning),
              _buildLegendItem('Cancelled', AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDot(Color color) {
    return Container(
      width: 5,
      height: 5,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 12.5,
            color: AppColors.inkSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDayOrderCard(DeliveryOrder order) {
    final status = order.status.value.trim();
    final isDelivered = status == 'Delivered';
    final isCancelled = status == 'Cancelled';
    final isLocked = order.isLocked && !isDelivered && !isCancelled;
    final receipt = controller.receiptsByOrderId[order.id] ??
        controller.receiptsByOrderId[order.transactionId];

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Get.toNamed(AppRoutes.orderDetails, arguments: order),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              StoreImageWidget(
                imageUrl: order.storePhoto,
                custCode: order.custCode,
                width: 46,
                height: 46,
                borderRadius: BorderRadius.circular(AppRadii.md),
                fallback: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(fontSize: 16.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      receipt != null
                          ? 'Order #${order.id} · Pay Ref #${receipt.referenceNumber}'
                          : '${order.routeSequence != null ? '#${order.routeSequence} · ' : ''}Order #${order.id} · ${order.sku} SKUs',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.monoRef.copyWith(
                        fontSize: 12.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    if (receipt != null && receipt.date.isNotEmpty)
                      Text(
                        receipt.date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          fontSize: 12,
                          color: AppColors.success,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(
                    PesoFormatter.buildPesoTextSpan(
                      amount: order.totalAmount,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusPill(
                    label: isDelivered
                        ? 'Delivered'
                        : isCancelled
                            ? 'Cancelled'
                            : isLocked
                                ? 'Queued'
                                : 'Active',
                    isPositive: isDelivered,
                    isDanger: isCancelled,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGenerateWeeklyPlanDialog(BuildContext context) async {
    final activeCount = controller.unlockedOutForDeliveryCount;
    if (activeCount == 0) {
      Get.snackbar(
        'No Active Orders',
        'There are no unlocked Out-for-Delivery orders to schedule.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }

    final phtNow = DateTime.now().toUtc().add(const Duration(hours: 8));
    final todayPht = DateTime(phtNow.year, phtNow.month, phtNow.day);
    final sel = controller.selectedDate.value;
    final startAnchor = sel.isBefore(todayPht) ? todayPht : sel;
    // Upcoming 7 days starting from startAnchor (never before today)
    final upcomingDays = List<DateTime>.generate(
      7,
      (i) => startAnchor.add(Duration(days: i)),
    );
    // Default Mon-Sat (exclude Sunday unless user selects it)
    final selectedDayIndices = <int>{
      for (int i = 0; i < upcomingDays.length; i++)
        if (upcomingDays[i].weekday != DateTime.sunday) i,
    };
    if (selectedDayIndices.isEmpty) selectedDayIndices.add(0);
    int? maxStopsPerDay;

    const shortWeekdays = <int, String>{
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final sortedIndices = selectedDayIndices.toList()..sort();
            final targetDays =
                sortedIndices.map((idx) => upcomingDays[idx]).toList();

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
              child: SingleChildScrollView(
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
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(color: AppColors.primaryBorder),
                          ),
                          child: const Icon(
                            Icons.alt_route_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Generate Weekly Plan',
                                style:
                                    AppTypography.title.copyWith(fontSize: 20),
                              ),
                              Text(
                                '$activeCount unlocked stops · Starting ${HomeController.formatDateLabel(RouteCalendarController.toIsoDate(startAnchor))}',
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
                    Text(
                      'Select upcoming delivery days (from today):',
                      style: AppTypography.caption.copyWith(
                        fontSize: 14.5,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(upcomingDays.length, (idx) {
                        final day = upcomingDays[idx];
                        final isSelected = selectedDayIndices.contains(idx);
                        final label =
                            '${shortWeekdays[day.weekday]} ${day.month}/${day.day}';
                        return FilterChip(
                          label: Text(
                            label,
                            style: AppTypography.caption.copyWith(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.inkSecondary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primaryTint,
                          backgroundColor: AppColors.canvas,
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primaryBorder
                                : AppColors.border,
                          ),
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                selectedDayIndices.add(idx);
                              } else if (selectedDayIndices.length > 1) {
                                selectedDayIndices.remove(idx);
                              }
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Max stops per day (optional):',
                      style: AppTypography.caption.copyWith(
                        fontSize: 14.5,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <int?>[null, 3, 5, 8, 10].map((cap) {
                        final selected = maxStopsPerDay == cap;
                        return ChoiceChip(
                          label: Text(
                            cap == null ? 'Auto Balance' : '$cap / day',
                            style: AppTypography.caption.copyWith(
                              fontSize: 13.5,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.inkSecondary,
                            ),
                          ),
                          selected: selected,
                          selectedColor: AppColors.primaryTint,
                          backgroundColor: AppColors.canvas,
                          side: BorderSide(
                            color: selected
                                ? AppColors.primaryBorder
                                : AppColors.border,
                          ),
                          onSelected: (_) {
                            setState(() => maxStopsPerDay = cap);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.inkSecondary,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadii.md),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: AppTypography.label.copyWith(
                                fontSize: 16,
                                color: AppColors.inkSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              final done = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => RoutePlanProgressDialog(
                                  onGenerate: (onStageUpdate) async {
                                    final summary = await controller
                                        .generateWeeklyRoutePlan(
                                      targetDays: targetDays,
                                      maxStopsPerDay: maxStopsPerDay,
                                      onStageUpdate: onStageUpdate,
                                    );
                                    return (
                                      stops: summary.assignments.length,
                                      days: summary.daysUsed,
                                      km: summary.totalEstimatedKm,
                                      minutes: summary.totalEstimatedMinutes,
                                    );
                                  },
                                ),
                              );
                              if (done == true) {
                                Get.back(); // Return automatically to Home screen
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadii.md),
                              ),
                            ),
                            child: Text(
                              'Generate Plan',
                              style: AppTypography.label.copyWith(
                                fontSize: 16,
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
        );
      },
    );
  }
}
