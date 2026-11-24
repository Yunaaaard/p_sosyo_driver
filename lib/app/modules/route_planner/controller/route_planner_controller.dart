import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/core/utils/location_helper.dart';
import 'package:p_sosyo_driver/app/core/utils/route_plan_generator.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';

class RoutePlannerController extends GetxController {
  /// 'today' or 'weekly'
  final RxString mode = 'today'.obs;
  final RxBool isLoading = true.obs;
  final RxBool includeSunday = false.obs;
  final RxBool endNearDepot = false.obs;
  final RxInt selectedDayIndex = 0.obs;

  /// All Out-for-Delivery orders (including locked re-deliveries) for manual Insert Stop.
  final RxList<DeliveryOrder> allOutForDeliveryOrders = <DeliveryOrder>[].obs;

  /// All unlocked Out-for-Delivery orders available for auto-planning.
  final RxList<DeliveryOrder> allUnlockedOrders = <DeliveryOrder>[].obs;

  /// Ordered stops for Today mode.
  final RxList<DeliveryOrder> todayStops = <DeliveryOrder>[].obs;

  /// Day ISO -> ordered stops for Weekly mode.
  final RxMap<String, List<DeliveryOrder>> weeklyDayBuckets =
      <String, List<DeliveryOrder>>{}.obs;

  late final DateTime todayPht;
  late final String todayIso;
  late final List<DateTime> upcomingWeekDays;

  @override
  void onInit() {
    super.onInit();
    final phtNow = DateTime.now().toUtc().add(const Duration(hours: 8));
    todayPht = DateTime(phtNow.year, phtNow.month, phtNow.day);
    todayIso = toIsoDate(todayPht);
    upcomingWeekDays = List<DateTime>.generate(
      7,
      (i) => todayPht.add(Duration(days: i)),
    );

    if (Get.arguments is Map && (Get.arguments as Map)['mode'] is String) {
      final m = (Get.arguments as Map)['mode'].toString();
      if (m == 'weekly' || m == 'today') {
        mode.value = m;
      }
    }
    _loadOrders();
  }

  static String toIsoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<DateTime> get activeWeekDays => upcomingWeekDays
      .where((d) => includeSunday.value || d.weekday != DateTime.sunday)
      .toList();

  String get selectedDayIso {
    final days = activeWeekDays;
    if (days.isEmpty) return todayIso;
    final idx = selectedDayIndex.value.clamp(0, days.length - 1);
    return toIsoDate(days[idx]);
  }

  bool isOverdue(DeliveryOrder order) {
    final raw = order.deliveryDate.trim();
    if (raw.length < 10) return false;
    return raw.substring(0, 10).compareTo(todayIso) < 0;
  }

  int overdueDays(DeliveryOrder order) {
    final raw = order.deliveryDate.trim();
    if (raw.length < 10) return 0;
    final parsed = DateTime.tryParse(raw.substring(0, 10));
    if (parsed == null) return 0;
    final diff = todayPht.difference(parsed).inDays;
    return diff > 0 ? diff : 0;
  }

  Future<void> _loadOrders() async {
    isLoading.value = true;
    try {
      final dbOrders = await DatabaseService.to.getAllDeliveryOrders();
      final driverCoords = await LocationHelper.getCurrentDriverLocation();
      final allActive = dbOrders
          .where((o) => o.status.value == 'Out for Delivery')
          .map(
            (o) => o.withResolvedLocation(
              driverLat: driverCoords.latitude,
              driverLng: driverCoords.longitude,
            ),
          )
          .toList();
      final unlocked = allActive.where((o) => !o.isLocked).toList();

      allOutForDeliveryOrders.assignAll(allActive);
      allUnlockedOrders.assignAll(unlocked);
      _buildTodayInitialStops();
      _buildWeeklyInitialBuckets();
    } catch (e, stack) {
      logError('Error loading orders in RoutePlannerController', e, stack);
    } finally {
      isLoading.value = false;
    }
  }

  void _buildTodayInitialStops() {
    // Start empty so the driver explicitly inserts stops for Today's route.
    todayStops.clear();
  }

  void _buildWeeklyInitialBuckets() {
    final days = activeWeekDays;
    final Map<String, List<DeliveryOrder>> buckets = {
      for (final d in days) toIsoDate(d): <DeliveryOrder>[],
    };
    weeklyDayBuckets.assignAll(buckets);
  }

  void switchMode(String nextMode) {
    mode.value = nextMode;
  }

  void toggleIncludeSunday(bool include) {
    includeSunday.value = include;
    if (selectedDayIndex.value >= activeWeekDays.length) {
      selectedDayIndex.value = 0;
    }
    final updated = <String, List<DeliveryOrder>>{
      for (final d in activeWeekDays)
        toIsoDate(d): List<DeliveryOrder>.from(
          weeklyDayBuckets[toIsoDate(d)] ?? <DeliveryOrder>[],
        ),
    };
    weeklyDayBuckets.assignAll(updated);
  }

  void toggleEndNearDepot(bool value) {
    endNearDepot.value = value;
  }

  Future<void> cycleDeliveryWindow(DeliveryOrder order) async {
    final String nextWindow;
    switch (order.effectiveDeliveryWindow) {
      case 'normal':
        nextWindow = 'early';
        break;
      case 'early':
        nextWindow = 'late';
        break;
      default:
        nextWindow = 'normal';
    }
    await DatabaseService.to.updateOrderDeliveryWindow(order.id, nextWindow);

    void updateList(RxList<DeliveryOrder> list) {
      final idx = list.indexWhere((o) => o.id == order.id);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(
          deliveryWindow: nextWindow,
          isEarlyPriority: nextWindow == 'early',
        );
        list.refresh();
      }
    }

    updateList(allOutForDeliveryOrders);
    updateList(allUnlockedOrders);
    updateList(todayStops);

    final updatedBuckets = Map<String, List<DeliveryOrder>>.from(weeklyDayBuckets);
    for (final key in updatedBuckets.keys) {
      updatedBuckets[key] = updatedBuckets[key]!
          .map((o) => o.id == order.id
              ? o.copyWith(
                  deliveryWindow: nextWindow,
                  isEarlyPriority: nextWindow == 'early',
                )
              : o)
          .toList();
    }
    weeklyDayBuckets.assignAll(updatedBuckets);
  }

  /// Auto-suggests the smartest delivery sequence for Today:
  /// - If Today is empty, pulls due/overdue unlocked stops (or all unlocked if none due).
  /// - Sequences 3 time-window legs: Early -> Normal -> Late.
  /// - Optionally ends near the depot/start location when [endNearDepot] is enabled.
  /// - Runs Nearest-Neighbor, 2-Opt, and Or-Opt polish.
  Future<void> autoSuggestTodayOrder() async {
    if (todayStops.isEmpty) {
      final dueToday = allUnlockedOrders.where((o) {
        final d = o.deliveryDate.trim();
        if (d.length < 10) return true;
        return d.substring(0, 10).compareTo(todayIso) <= 0;
      }).toList();
      todayStops.assignAll(
        dueToday.isNotEmpty ? dueToday : allUnlockedOrders.toList(),
      );
    }
    if (todayStops.isEmpty) return;

    final driverCoords = await LocationHelper.getCurrentDriverLocation();
    final earlyStops =
        todayStops.where((o) => o.effectiveDeliveryWindow == 'early').toList();
    final normalStops =
        todayStops.where((o) => o.effectiveDeliveryWindow == 'normal').toList();
    final lateStops =
        todayStops.where((o) => o.effectiveDeliveryWindow == 'late').toList();

    List<DeliveryOrder> sequenceSubset(
      List<DeliveryOrder> subset,
      double startLat,
      double startLng,
    ) {
      if (subset.length <= 1) return subset;
      final summary = RoutePlanGenerator.generateWeeklyPlan(
        orders: subset,
        startLat: startLat,
        startLng: startLng,
        deliveryDays: [todayPht],
      );
      final seqMap = {
        for (final a in summary.assignments) a.orderId: a.routeSequence,
      };
      final sorted = subset.toList()
        ..sort((a, b) =>
            (seqMap[a.id] ?? 999999).compareTo(seqMap[b.id] ?? 999999));
      return _polishRouteWithOrOpt(
        sorted,
        startLat: startLat,
        startLng: startLng,
      );
    }

    (double lat, double lng) tailCoords(
      List<DeliveryOrder> leg,
      double fallbackLat,
      double fallbackLng,
    ) {
      if (leg.isNotEmpty &&
          leg.last.latitude != null &&
          leg.last.longitude != null) {
        return (leg.last.latitude!, leg.last.longitude!);
      }
      return (fallbackLat, fallbackLng);
    }

    final sequencedEarly = sequenceSubset(
      earlyStops,
      driverCoords.latitude,
      driverCoords.longitude,
    );
    final leg2Start = tailCoords(
      sequencedEarly,
      driverCoords.latitude,
      driverCoords.longitude,
    );

    var sequencedNormal = sequenceSubset(
      normalStops,
      leg2Start.$1,
      leg2Start.$2,
    );
    final leg3Start = tailCoords(
      sequencedNormal,
      leg2Start.$1,
      leg2Start.$2,
    );

    var sequencedLate = sequenceSubset(
      lateStops,
      leg3Start.$1,
      leg3Start.$2,
    );

    if (endNearDepot.value) {
      List<DeliveryOrder> anchorTail(
        List<DeliveryOrder> leg,
        double startLat,
        double startLng,
      ) {
        if (leg.length < 2) return leg;
        int closestIdx = leg.length - 1;
        double minDepotDist = double.infinity;
        for (int i = 0; i < leg.length; i++) {
          final s = leg[i];
          if (s.latitude != null && s.longitude != null) {
            final d = LocationHelper.calculateDistanceKm(
              startLat: driverCoords.latitude,
              startLng: driverCoords.longitude,
              endLat: s.latitude!,
              endLng: s.longitude!,
            );
            if (d < minDepotDist) {
              minDepotDist = d;
              closestIdx = i;
            }
          }
        }
        final copy = List<DeliveryOrder>.from(leg);
        final anchorLast = copy.removeAt(closestIdx);
        return [...sequenceSubset(copy, startLat, startLng), anchorLast];
      }

      if (sequencedLate.length >= 2) {
        sequencedLate = anchorTail(sequencedLate, leg3Start.$1, leg3Start.$2);
      } else if (sequencedLate.isEmpty && sequencedNormal.length >= 2) {
        sequencedNormal =
            anchorTail(sequencedNormal, leg2Start.$1, leg2Start.$2);
      }
    }

    final combined = [...sequencedEarly, ...sequencedNormal, ...sequencedLate];
    todayStops.assignAll(combined);

    final totalKm = _estimateRouteKm(
      combined,
      startLat: driverCoords.latitude,
      startLng: driverCoords.longitude,
    );
    final overdueCount = combined.where(isOverdue).length;
    Get.snackbar(
      'Smart Route Ready',
      '${combined.length} stops sequenced · ${totalKm.toStringAsFixed(1)} km est.${overdueCount > 0 ? " ($overdueCount overdue)" : ""}',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFE8F5E9),
      colorText: const Color(0xFF15803D),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
  }

  /// Or-Opt single-stop relocation pass to eliminate any remaining detours.
  List<DeliveryOrder> _polishRouteWithOrOpt(
    List<DeliveryOrder> route, {
    required double startLat,
    required double startLng,
  }) {
    if (route.length < 4) return route;
    var best = List<DeliveryOrder>.from(route);
    var bestDist = _estimateRouteKm(best, startLat: startLat, startLng: startLng);
    var improved = true;

    while (improved) {
      improved = false;
      for (int i = 0; i < best.length; i++) {
        for (int j = 0; j < best.length; j++) {
          if (i == j) continue;
          final candidate = List<DeliveryOrder>.from(best);
          final moved = candidate.removeAt(i);
          candidate.insert(j, moved);
          final dist =
              _estimateRouteKm(candidate, startLat: startLat, startLng: startLng);
          if (dist + 0.05 < bestDist) {
            best = candidate;
            bestDist = dist;
            improved = true;
            break;
          }
        }
        if (improved) break;
      }
    }
    return best;
  }

  double _estimateRouteKm(
    List<DeliveryOrder> route, {
    required double startLat,
    required double startLng,
  }) {
    double total = 0;
    double curLat = startLat;
    double curLng = startLng;
    for (final stop in route) {
      if (stop.latitude != null && stop.longitude != null) {
        total += LocationHelper.calculateDistanceKm(
          startLat: curLat,
          startLng: curLng,
          endLat: stop.latitude!,
          endLng: stop.longitude!,
        );
        curLat = stop.latitude!;
        curLng = stop.longitude!;
      }
    }
    return total;
  }

  /// Auto-sorts & sequences all weekly days using unloading dates + K-Means++ + 2-Opt.
  Future<void> autoOptimizeWeeklyPlan() async {
    final days = activeWeekDays;
    if (allUnlockedOrders.isEmpty || days.isEmpty) return;
    final driverCoords = await LocationHelper.getCurrentDriverLocation();
    final summary = RoutePlanGenerator.generateWeeklyPlan(
      orders: allUnlockedOrders.toList(),
      startLat: driverCoords.latitude,
      startLng: driverCoords.longitude,
      deliveryDays: days,
    );

    final Map<String, DeliveryOrder> byId = {
      for (final o in allUnlockedOrders) o.id: o,
    };
    final Map<String, List<DeliveryOrder>> newBuckets = {
      for (final d in days) toIsoDate(d): [],
    };

    for (final a in summary.assignments) {
      final order = byId[a.orderId];
      if (order != null && newBuckets.containsKey(a.plannedDateIso)) {
        newBuckets[a.plannedDateIso]!.add(
          order.copyWith(routeSequence: a.routeSequence),
        );
      }
    }
    weeklyDayBuckets.assignAll(newBuckets);
    final weeklyKm = newBuckets.values.fold<double>(
      0,
      (sum, list) =>
          sum +
          _estimateRouteKm(
            list,
            startLat: driverCoords.latitude,
            startLng: driverCoords.longitude,
          ),
    );
    Get.snackbar(
      'Smart Weekly Plan Ready',
      '${summary.assignments.length} stops balanced across ${days.length} days · ${weeklyKm.toStringAsFixed(1)} km est.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFE8F5E9),
      colorText: const Color(0xFF15803D),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
  }

  void reorderTodayStops(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex < 0 ||
        oldIndex >= todayStops.length ||
        newIndex < 0 ||
        newIndex >= todayStops.length ||
        oldIndex == newIndex) {
      return;
    }
    final list = todayStops.toList();
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    todayStops.assignAll(list);
  }

  void reorderWeeklyDayStops(String dayIso, int oldIndex, int newIndex) {
    final current = List<DeliveryOrder>.from(weeklyDayBuckets[dayIso] ?? []);
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex < 0 ||
        oldIndex >= current.length ||
        newIndex < 0 ||
        newIndex >= current.length ||
        oldIndex == newIndex) {
      return;
    }
    final moved = current.removeAt(oldIndex);
    current.insert(newIndex, moved);
    weeklyDayBuckets[dayIso] = current;
    weeklyDayBuckets.refresh();
  }

  /// Inserts an order from another day into Today's stop list.
  void insertOrderIntoToday(DeliveryOrder order) {
    if (todayStops.any((o) => o.id == order.id)) return;
    todayStops.add(order);
  }

  /// Inserts multiple orders into Today's stop list in one update.
  void insertOrdersIntoToday(List<DeliveryOrder> ordersToAdd) {
    if (ordersToAdd.isEmpty) return;
    final existingIds = todayStops.map((o) => o.id).toSet();
    final fresh = ordersToAdd.where((o) => !existingIds.contains(o.id)).toList();
    if (fresh.isEmpty) return;
    todayStops.addAll(fresh);
  }

  void removeOrderFromToday(String orderId) {
    todayStops.removeWhere((o) => o.id == orderId);
  }

  /// Moves or inserts an order into [targetDayIso] in Weekly mode.
  void moveOrderToDay(DeliveryOrder order, String targetDayIso) {
    moveOrdersToDay([order], targetDayIso);
  }

  /// Moves or inserts multiple orders into [targetDayIso] in Weekly mode.
  void moveOrdersToDay(List<DeliveryOrder> ordersToMove, String targetDayIso) {
    if (ordersToMove.isEmpty) return;
    final moveIds = ordersToMove.map((o) => o.id).toSet();
    final updated = Map<String, List<DeliveryOrder>>.from(weeklyDayBuckets);
    for (final key in updated.keys) {
      updated[key] =
          updated[key]!.where((o) => !moveIds.contains(o.id)).toList();
    }
    updated.putIfAbsent(targetDayIso, () => []).addAll(ordersToMove);
    weeklyDayBuckets.assignAll(updated);
  }

  List<DeliveryOrder> get ordersNotInToday {
    final candidates = allOutForDeliveryOrders
        .where((o) => !todayStops.any((t) => t.id == o.id))
        .toList();
    candidates.sort(_compareInsertCandidates);
    return candidates;
  }

  /// Returns the day ISO where [orderId] is currently placed in Weekly mode, or null.
  String? assignedDayIsoForOrder(String orderId) {
    for (final entry in weeklyDayBuckets.entries) {
      if (entry.value.any((o) => o.id == orderId)) {
        return entry.key;
      }
    }
    return null;
  }

  /// All stops for Weekly Insert Stops sheet: selectable stops from other days
  /// or unassigned first, followed by stops already on [dayIso].
  List<DeliveryOrder> weeklyInsertCandidates(String dayIso) {
    final inDay = (weeklyDayBuckets[dayIso] ?? []).map((o) => o.id).toSet();
    final candidates = allOutForDeliveryOrders.toList();
    candidates.sort((a, b) {
      final aInDay = inDay.contains(a.id);
      final bInDay = inDay.contains(b.id);
      if (aInDay != bInDay) {
        return aInDay ? 1 : -1;
      }
      return _compareInsertCandidates(a, b);
    });
    return candidates;
  }

  List<DeliveryOrder> ordersNotInDay(String dayIso) {
    final inDay = (weeklyDayBuckets[dayIso] ?? []).map((o) => o.id).toSet();
    final candidates =
        allOutForDeliveryOrders.where((o) => !inDay.contains(o.id)).toList();
    candidates.sort(_compareInsertCandidates);
    return candidates;
  }

  int _compareInsertCandidates(DeliveryOrder a, DeliveryOrder b) {
    if (a.isLocked != b.isLocked) {
      return a.isLocked ? -1 : 1; // Locked re-deliveries first
    }
    final dateCmp = a.deliveryDate.compareTo(b.deliveryDate);
    if (dateCmp != 0) return dateCmp;
    return (a.distanceKm ?? double.infinity)
        .compareTo(b.distanceKm ?? double.infinity);
  }

  Future<void> applyRoutePlan() async {
    final List<({String orderId, String deliveryDate, int routeSequence})>
        assignments = [];
    final List<({DeliveryOrder order, String plannedDateIso})>
        lockedAssignments = [];

    if (mode.value == 'today') {
      for (int i = 0; i < todayStops.length; i++) {
        final stop = todayStops[i];
        if (stop.isLocked) {
          lockedAssignments.add((order: stop, plannedDateIso: todayIso));
        }
        assignments.add((
          orderId: stop.id,
          deliveryDate: todayIso,
          routeSequence: i + 1,
        ));
      }
    } else {
      for (final entry in weeklyDayBuckets.entries) {
        final dayIso = entry.key;
        final list = entry.value;
        for (int i = 0; i < list.length; i++) {
          final stop = list[i];
          if (stop.isLocked) {
            lockedAssignments.add((order: stop, plannedDateIso: dayIso));
          }
          assignments.add((
            orderId: stop.id,
            deliveryDate: dayIso,
            routeSequence: i + 1,
          ));
        }
      }
    }

    if (assignments.isNotEmpty) {
      await DatabaseService.to.applyWeeklyRoutePlan(assignments);
    }

    for (final locked in lockedAssignments) {
      await DatabaseService.to.updateOrderLockState(
        orderId: locked.order.id,
        isLocked: true,
        scheduledDeliveryDate: locked.plannedDateIso,
        lockedAt: locked.order.lockedAt,
      );
    }
    if (lockedAssignments.isNotEmpty) {
      logImportant(
        'Preserved locked/re-delivery state for ${lockedAssignments.length} inserted stop(s) on Route Plan Apply',
        tag: 'ROUTE_PLAN',
      );
    }

    if (Get.isRegistered<HomeController>()) {
      final home = Get.find<HomeController>();
      await home.loadOrdersFromDb();
      home.setDateFilter(todayIso);
    }

    logImportant(
      'Applied ${mode.value} route plan: ${assignments.length} stops sequenced',
      tag: 'ROUTE_PLAN',
    );
    Get.back();
    Get.snackbar(
      'Route Plan Applied',
      '${assignments.length} stops sequenced for ${mode.value == 'today' ? "Today" : "this week"}.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFE8F5E9),
      colorText: const Color(0xFF15803D),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }
}
