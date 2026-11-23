import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/core/utils/location_helper.dart';
import 'package:p_sosyo_driver/app/core/utils/route_plan_generator.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_attempt.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/models/receipt.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';

class CalendarDayStatus {
  final int totalCount;
  final int deliveredCount;
  final int activeCount;
  final int queuedCount;
  final int cancelledCount;
  final double collectedAmount;

  const CalendarDayStatus({
    this.totalCount = 0,
    this.deliveredCount = 0,
    this.activeCount = 0,
    this.queuedCount = 0,
    this.cancelledCount = 0,
    this.collectedAmount = 0.0,
  });
}

class AnalyticsBarBucket {
  final String label;
  final double collectedAmount;
  final int deliveredCount;
  final int totalCount;

  const AnalyticsBarBucket({
    required this.label,
    required this.collectedAmount,
    required this.deliveredCount,
    required this.totalCount,
  });
}

class RouteCalendarController extends GetxController {
  final RxBool isLoading = true.obs;
  final Rx<DateTime> focusedMonth = _phtToday().obs;
  final Rx<DateTime> selectedDate = _phtToday().obs;
  final RxString analyticsPeriod = 'Weekly'.obs;

  final RxList<DeliveryOrder> allOrders = <DeliveryOrder>[].obs;
  final RxMap<String, Receipt> receiptsByOrderId = <String, Receipt>{}.obs;
  final RxList<DeliveryAttempt> allAttempts = <DeliveryAttempt>[].obs;

  static DateTime _phtToday() {
    final pht = DateTime.now().toUtc().add(const Duration(hours: 8));
    return DateTime(pht.year, pht.month, pht.day);
  }

  static String toIsoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get selectedDateIso => toIsoDate(selectedDate.value);

  String get selectedDateLabel =>
      HomeController.formatDateLabel(selectedDateIso);

  String get focusedMonthTitle {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final m = focusedMonth.value;
    return '${months[m.month - 1]} ${m.year}';
  }

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<HomeController>()) {
      final existingFilter = Get.find<HomeController>().selectedDateFilter.value;
      if (existingFilter != null && existingFilter.isNotEmpty) {
        final parsed = DateTime.tryParse(existingFilter);
        if (parsed != null) {
          selectedDate.value = DateTime(parsed.year, parsed.month, parsed.day);
          focusedMonth.value = DateTime(parsed.year, parsed.month, 1);
        }
      }
    }
    loadCalendarData();
  }

  Future<void> loadCalendarData() async {
    isLoading.value = true;
    try {
      final db = DatabaseService.to;
      final orders = await db.getAllDeliveryOrders();
      final receipts = await db.getAllReceipts();
      final attempts = await db.getAllDeliveryAttempts();

      allOrders.assignAll(orders);
      allAttempts.assignAll(attempts);

      final Map<String, Receipt> receiptMap = {};
      for (final r in receipts) {
        receiptMap[r.deliveryOrderId] = r;
      }
      receiptsByOrderId.assignAll(receiptMap);

      logImportant(
        'Loaded RouteCalendar: ${orders.length} orders, ${receipts.length} receipts',
        tag: 'CALENDAR',
      );
    } catch (e, stack) {
      logError('Error loading route calendar data', e, stack);
    } finally {
      isLoading.value = false;
    }
  }

  void previousMonth() {
    final m = focusedMonth.value;
    focusedMonth.value = DateTime(m.year, m.month - 1, 1);
  }

  void nextMonth() {
    final m = focusedMonth.value;
    focusedMonth.value = DateTime(m.year, m.month + 1, 1);
  }

  void jumpToToday() {
    final today = _phtToday();
    selectedDate.value = today;
    focusedMonth.value = DateTime(today.year, today.month, 1);
  }

  void selectDay(DateTime day) {
    selectedDate.value = DateTime(day.year, day.month, day.day);
  }

  void setAnalyticsPeriod(String period) {
    analyticsPeriod.value = period;
  }

  /// Orders and past transactions matching [dateIso], ordered by routeSequence.
  List<DeliveryOrder> ordersForDate(String dateIso) {
    final list = allOrders
        .where((o) => HomeController.resolveEffectiveDateIso(o) == dateIso)
        .toList();
    list.sort((a, b) {
      final aSeq = a.routeSequence ?? 999999;
      final bSeq = b.routeSequence ?? 999999;
      return aSeq.compareTo(bSeq);
    });
    return list;
  }

  int get unlockedOutForDeliveryCount => allOrders
      .where((o) => o.status.value == 'Out for Delivery' && !o.isLocked)
      .length;

  /// Generates a clustered, 2-opt sequenced weekly route plan across [targetDays]
  /// for all unlocked Out-for-Delivery orders.
  Future<WeeklyPlanSummary> generateWeeklyRoutePlan({
    required List<DateTime> targetDays,
    int? maxStopsPerDay,
    void Function(double progress, String stage)? onStageUpdate,
  }) async {
    onStageUpdate?.call(0.20, 'Resolving driver & store coordinates...');
    final driverCoords = await LocationHelper.getCurrentDriverLocation();
    await Future.delayed(const Duration(milliseconds: 280));

    onStageUpdate?.call(0.50, 'Clustering delivery zones (K-Means++)...');
    await Future.delayed(const Duration(milliseconds: 300));

    onStageUpdate?.call(0.75, 'Sequencing stops (2-Opt route chaining)...');
    final summary = RoutePlanGenerator.generateWeeklyPlan(
      orders: allOrders.toList(),
      startLat: driverCoords.latitude,
      startLng: driverCoords.longitude,
      deliveryDays: targetDays,
      maxStopsPerDay: maxStopsPerDay,
    );

    if (summary.assignments.isNotEmpty) {
      onStageUpdate?.call(0.92, 'Saving weekly schedule...');
      await DatabaseService.to.applyWeeklyRoutePlan(
        summary.assignments
            .map(
              (a) => (
                orderId: a.orderId,
                deliveryDate: a.plannedDateIso,
                routeSequence: a.routeSequence,
              ),
            )
            .toList(),
      );

      await loadCalendarData();
      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().loadOrdersFromDb();
      }
      if (targetDays.isNotEmpty) {
        selectDay(targetDays.first);
      }

      logImportant(
        'Generated weekly route plan: ${summary.assignments.length} stops across ${summary.daysUsed} days (~${summary.totalEstimatedKm.toStringAsFixed(1)} km)',
        tag: 'ROUTE_PLAN',
      );
    }

    return summary;
  }

  List<DeliveryOrder> get selectedDateOrders => ordersForDate(selectedDateIso);

  CalendarDayStatus statusForDate(DateTime day) {
    final iso = toIsoDate(day);
    final list = ordersForDate(iso);
    int delivered = 0;
    int active = 0;
    int queued = 0;
    int cancelled = 0;
    double collected = 0.0;

    for (final o in list) {
      final status = o.status.value.trim();
      if (status == 'Delivered') {
        delivered++;
        collected += o.numericTotalAmount;
      } else if (status == 'Cancelled') {
        cancelled++;
      } else if (o.isLocked) {
        queued++;
      } else {
        active++;
      }
    }

    return CalendarDayStatus(
      totalCount: list.length,
      deliveredCount: delivered,
      activeCount: active,
      queuedCount: queued,
      cancelledCount: cancelled,
      collectedAmount: collected,
    );
  }

  /// Orders within the currently selected analytics window (Weekly or Monthly).
  List<DeliveryOrder> get periodOrders {
    if (analyticsPeriod.value == 'Weekly') {
      final sel = selectedDate.value;
      // Monday-start 7-day week around selectedDate
      final start = sel.subtract(Duration(days: sel.weekday - 1));
      final end = start.add(const Duration(days: 6));
      final startIso = toIsoDate(start);
      final endIso = toIsoDate(end);
      return allOrders.where((o) {
        final d = HomeController.resolveEffectiveDateIso(o);
        return d.compareTo(startIso) >= 0 && d.compareTo(endIso) <= 0;
      }).toList();
    } else {
      final m = focusedMonth.value;
      final prefix =
          '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';
      return allOrders
          .where(
              (o) => HomeController.resolveEffectiveDateIso(o).startsWith(prefix))
          .toList();
    }
  }

  double get periodCollectedAmount => periodOrders
      .where((o) => o.status.value == 'Delivered')
      .fold(0.0, (sum, o) => sum + o.numericTotalAmount);

  double get periodTargetAmount =>
      periodOrders.fold(0.0, (sum, o) => sum + o.numericTotalAmount);

  int get periodDeliveredCount =>
      periodOrders.where((o) => o.status.value == 'Delivered').length;

  int get periodQueuedCount => periodOrders
      .where((o) => o.status.value == 'Out for Delivery' && o.isLocked)
      .length;

  int get periodCancelledCount =>
      periodOrders.where((o) => o.status.value == 'Cancelled').length;

  int get periodActiveCount => periodOrders
      .where((o) => o.status.value == 'Out for Delivery' && !o.isLocked)
      .length;

  double get periodCompletionRate => periodOrders.isNotEmpty
      ? (periodDeliveredCount / periodOrders.length)
      : 0.0;

  List<AnalyticsBarBucket> get periodBuckets {
    if (analyticsPeriod.value == 'Weekly') {
      const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final sel = selectedDate.value;
      final start = sel.subtract(Duration(days: sel.weekday - 1));
      return List.generate(7, (i) {
        final day = start.add(Duration(days: i));
        final st = statusForDate(day);
        return AnalyticsBarBucket(
          label: dayLabels[i],
          collectedAmount: st.collectedAmount,
          deliveredCount: st.deliveredCount,
          totalCount: st.totalCount,
        );
      });
    } else {
      final m = focusedMonth.value;
      final daysInMonth = DateTime(m.year, m.month + 1, 0).day;
      final List<AnalyticsBarBucket> buckets = [];
      for (int w = 0; w < 4; w++) {
        final startDay = w * 7 + 1;
        final endDay = (w == 3) ? daysInMonth : (w + 1) * 7;
        double collected = 0.0;
        int delivered = 0;
        int total = 0;
        for (int d = startDay; d <= endDay; d++) {
          final st = statusForDate(DateTime(m.year, m.month, d));
          collected += st.collectedAmount;
          delivered += st.deliveredCount;
          total += st.totalCount;
        }
        buckets.add(
          AnalyticsBarBucket(
            label: 'W${w + 1}',
            collectedAmount: collected,
            deliveredCount: delivered,
            totalCount: total,
          ),
        );
      }
      return buckets;
    }
  }

  void applySelectedDateToHome() {
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().setDateFilter(selectedDateIso);
    }
    Get.back();
  }

  void clearHomeDateFilter() {
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().clearDateFilter();
    }
    Get.back();
  }
}
