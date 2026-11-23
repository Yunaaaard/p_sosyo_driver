import 'dart:math' as math;
import 'package:p_sosyo_driver/app/core/utils/location_helper.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';

class PlannedStopAssignment {
  final String orderId;
  final String plannedDateIso;
  final int routeSequence;

  const PlannedStopAssignment({
    required this.orderId,
    required this.plannedDateIso,
    required this.routeSequence,
  });
}

class PlannedDaySummary {
  final String dateIso;
  final int stopCount;
  final double totalAmount;
  final double estimatedKm;
  final int estimatedMinutes;

  const PlannedDaySummary({
    required this.dateIso,
    required this.stopCount,
    required this.totalAmount,
    required this.estimatedKm,
    required this.estimatedMinutes,
  });
}

class WeeklyPlanSummary {
  final List<PlannedStopAssignment> assignments;
  final List<PlannedDaySummary> daySummaries;
  final int daysUsed;
  final double totalEstimatedKm;
  final int totalEstimatedMinutes;

  const WeeklyPlanSummary({
    required this.assignments,
    this.daySummaries = const [],
    required this.daysUsed,
    required this.totalEstimatedKm,
    this.totalEstimatedMinutes = 0,
  });
}

/// Smart local Vehicle Routing Problem (VRP) planner using:
/// 1. Same-customer (`custCode`) transaction consolidation
/// 2. Locked-order geographic anchoring (pairs nearby stops with already-queued days)
/// 3. K-Means++ spatial clustering + capacity balancing across days
/// 4. Priority scheduling (retried/overdue orders assigned to earlier days)
/// 5. Nearest-Neighbor + 2-Opt daily stop sequencing with distance & ETA estimates
class RoutePlanGenerator {
  RoutePlanGenerator._();

  static String _toIsoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static WeeklyPlanSummary generateWeeklyPlan({
    required List<DeliveryOrder> orders,
    required double startLat,
    required double startLng,
    required List<DateTime> deliveryDays,
    int? maxStopsPerDay,
  }) {
    final phtNow = DateTime.now().toUtc().add(const Duration(hours: 8));
    final todayPht = DateTime(phtNow.year, phtNow.month, phtNow.day);
    final todayIso = _toIsoDate(todayPht);

    final validDays = deliveryDays
        .map((d) => DateTime(d.year, d.month, d.day))
        .where((d) => !d.isBefore(todayPht))
        .toList()
      ..sort((a, b) => a.compareTo(b));

    final activeOrders = orders
        .where((o) => o.status.value == 'Out for Delivery' && !o.isLocked)
        .toList();

    if (activeOrders.isEmpty || validDays.isEmpty) {
      return const WeeklyPlanSummary(
        assignments: [],
        daysUsed: 0,
        totalEstimatedKm: 0.0,
      );
    }

    // Map locked/queued orders by their scheduled date so we can anchor nearby
    // unlocked stops to the same day and avoid visiting the same zone twice.
    final Map<String, List<({double lat, double lng})>> lockedAnchorsByDate = {};
    for (final o in orders) {
      if (o.status.value == 'Out for Delivery' &&
          o.isLocked &&
          o.scheduledDeliveryDate != null &&
          o.scheduledDeliveryDate!.trim().isNotEmpty) {
        final coords = LocationHelper.resolveOrderCoordinates(
          seedKey: o.custCode.isNotEmpty ? o.custCode : o.id,
          rawLat: o.latitude,
          rawLng: o.longitude,
        );
        lockedAnchorsByDate
            .putIfAbsent(o.scheduledDeliveryDate!.trim(), () => [])
            .add((lat: coords.latitude, lng: coords.longitude));
      }
    }

    // 1. Consolidate multiple orders/transactions for the same customer (custCode).
    final Map<String, List<DeliveryOrder>> storeGroups = {};
    for (final order in activeOrders) {
      final key = order.custCode.trim().isNotEmpty
          ? order.custCode.trim().toUpperCase()
          : order.id;
      storeGroups.putIfAbsent(key, () => []).add(order);
    }

    final List<_StoreCluster> clusters = storeGroups.entries.map((entry) {
      final list = entry.value;
      final first = list.first;
      final coords = LocationHelper.resolveOrderCoordinates(
        seedKey: first.custCode.isNotEmpty ? first.custCode : first.id,
        rawLat: first.latitude,
        rawLng: first.longitude,
      );
      final depotDist = LocationHelper.calculateDistanceKm(
        startLat: startLat,
        startLng: startLng,
        endLat: coords.latitude,
        endLng: coords.longitude,
      );
      final totalAmt = list.fold<double>(
        0.0,
        (sum, o) => sum + o.numericTotalAmount,
      );
      final maxAttempts = list.fold<int>(
        0,
        (m, o) => o.attemptCount > m ? o.attemptCount : m,
      );
      final isOverdue = list.any((o) {
        final d = o.deliveryDate.trim();
        return d.length >= 10 && d.substring(0, 10).compareTo(todayIso) < 0;
      });
      // Higher priority score = should be delivered earlier in the week
      final priorityScore = (maxAttempts * 100.0) +
          (isOverdue ? 50.0 : 0.0) +
          (totalAmt / 1000.0).clamp(0.0, 20.0);

      return _StoreCluster(
        orders: list,
        lat: coords.latitude,
        lng: coords.longitude,
        depotDistanceKm: depotDist,
        totalAmount: totalAmt,
        priorityScore: priorityScore,
      );
    }).toList();

    final int dayCount = validDays.length;
    final int effectiveCap = (maxStopsPerDay != null && maxStopsPerDay > 0)
        ? maxStopsPerDay
        : (clusters.length / dayCount).ceil().clamp(1, clusters.length);

    // 2. Spatial K-Means++ Clustering into K = min(dayCount, clusters.length) zones
    final int k = math.min(dayCount, clusters.length);
    final List<List<_StoreCluster>> zones = _kMeansSpatialCluster(
      clusters: clusters,
      k: k,
      capacityPerZone: effectiveCap,
    );

    // 3. Assign each spatial zone to the best delivery day:
    //    - If a day has locked anchors close to a zone centroid, prefer pairing them
    //    - Otherwise assign higher-priority / closer zones to earlier days
    final List<List<_StoreCluster>> dayBuckets =
        List.generate(dayCount, (_) => []);
    final Set<int> usedDayIndices = {};

    // Sort zones by average priority descending, then closest to depot
    zones.sort((a, b) {
      final aPri = a.fold<double>(0.0, (s, c) => s + c.priorityScore) / a.length;
      final bPri = b.fold<double>(0.0, (s, c) => s + c.priorityScore) / b.length;
      final priCmp = bPri.compareTo(aPri);
      if (priCmp.abs() > 0.5) return priCmp;
      final aDist = a.fold<double>(0.0, (s, c) => s + c.depotDistanceKm) / a.length;
      final bDist = b.fold<double>(0.0, (s, c) => s + c.depotDistanceKm) / b.length;
      return aDist.compareTo(bDist);
    });

    for (final zone in zones) {
      final zLat = zone.fold<double>(0.0, (s, c) => s + c.lat) / zone.length;
      final zLng = zone.fold<double>(0.0, (s, c) => s + c.lng) / zone.length;

      int? bestDayIdx;
      double bestAnchorDist = 3.0; // Pair within 3km of an already-locked stop
      for (int d = 0; d < dayCount; d++) {
        if (usedDayIndices.contains(d)) continue;
        final iso = _toIsoDate(validDays[d]);
        final anchors = lockedAnchorsByDate[iso];
        if (anchors == null || anchors.isEmpty) continue;
        for (final anchor in anchors) {
          final dist = LocationHelper.calculateDistanceKm(
            startLat: zLat,
            startLng: zLng,
            endLat: anchor.lat,
            endLng: anchor.lng,
          );
          if (dist < bestAnchorDist) {
            bestAnchorDist = dist;
            bestDayIdx = d;
          }
        }
      }

      if (bestDayIdx == null) {
        for (int d = 0; d < dayCount; d++) {
          if (!usedDayIndices.contains(d)) {
            bestDayIdx = d;
            break;
          }
        }
      }
      bestDayIdx ??= 0;
      usedDayIndices.add(bestDayIdx);
      dayBuckets[bestDayIdx].addAll(zone);
    }

    // 4. Sequence each day's stops via Nearest-Neighbor + 2-opt optimization.
    final List<PlannedStopAssignment> assignments = [];
    final List<PlannedDaySummary> daySummaries = [];
    double totalKm = 0.0;
    int totalMinutes = 0;
    int daysUsed = 0;

    for (int d = 0; d < dayCount; d++) {
      final dayClusters = dayBuckets[d];
      if (dayClusters.isEmpty) continue;
      daysUsed++;

      final ordered = _optimizeDailyRoute(
        clusters: dayClusters,
        startLat: startLat,
        startLng: startLng,
      );

      final dateIso = _toIsoDate(validDays[d]);
      double prevLat = startLat;
      double prevLng = startLng;
      double dayKm = 0.0;
      double dayAmount = 0.0;
      int seq = 1;

      for (final cluster in ordered) {
        dayKm += LocationHelper.calculateDistanceKm(
          startLat: prevLat,
          startLng: prevLng,
          endLat: cluster.lat,
          endLng: cluster.lng,
        );
        prevLat = cluster.lat;
        prevLng = cluster.lng;
        dayAmount += cluster.totalAmount;

        for (final order in cluster.orders) {
          assignments.add(
            PlannedStopAssignment(
              orderId: order.id,
              plannedDateIso: dateIso,
              routeSequence: seq++,
            ),
          );
        }
      }

      // Estimate ~25 km/h urban truck speed + 8 mins service time per stop
      final driveMinutes = ((dayKm / 25.0) * 60).round();
      final serviceMinutes = ordered.length * 8;
      final dayMinutes = driveMinutes + serviceMinutes;

      totalKm += dayKm;
      totalMinutes += dayMinutes;

      daySummaries.add(
        PlannedDaySummary(
          dateIso: dateIso,
          stopCount: seq - 1,
          totalAmount: dayAmount,
          estimatedKm: dayKm,
          estimatedMinutes: dayMinutes,
        ),
      );
    }

    return WeeklyPlanSummary(
      assignments: assignments,
      daySummaries: daySummaries,
      daysUsed: daysUsed,
      totalEstimatedKm: totalKm,
      totalEstimatedMinutes: totalMinutes,
    );
  }

  /// Capacity-aware K-Means++ spatial clustering to group nearby stores into
  /// compact daily delivery zones.
  static List<List<_StoreCluster>> _kMeansSpatialCluster({
    required List<_StoreCluster> clusters,
    required int k,
    required int capacityPerZone,
  }) {
    if (k <= 1 || clusters.length <= 1) {
      return [List<_StoreCluster>.from(clusters)];
    }

    // Deterministic K-Means++ initialization (pick highest-priority first, then
    // iteratively pick the farthest point from existing centroids).
    final sortedByPri = List<_StoreCluster>.from(clusters)
      ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    final List<({double lat, double lng})> centroids = [
      (lat: sortedByPri.first.lat, lng: sortedByPri.first.lng),
    ];

    while (centroids.length < k) {
      _StoreCluster? farthest;
      double maxMinDist = -1.0;
      for (final c in clusters) {
        double minDist = double.infinity;
        for (final cent in centroids) {
          final d = LocationHelper.calculateDistanceKm(
            startLat: c.lat,
            startLng: c.lng,
            endLat: cent.lat,
            endLng: cent.lng,
          );
          if (d < minDist) minDist = d;
        }
        if (minDist > maxMinDist) {
          maxMinDist = minDist;
          farthest = c;
        }
      }
      if (farthest == null) break;
      centroids.add((lat: farthest.lat, lng: farthest.lng));
    }

    List<List<_StoreCluster>> buckets = List.generate(k, (_) => []);

    // Run 8 K-Means refinement iterations with capacity enforcement
    for (int iter = 0; iter < 8; iter++) {
      buckets = List.generate(k, (_) => []);

      // Sort clusters by distance to their nearest centroid (closest claims first)
      final ordered = List<_StoreCluster>.from(clusters)
        ..sort((a, b) {
          final aBest = centroids
              .map((cent) => LocationHelper.calculateDistanceKm(
                    startLat: a.lat,
                    startLng: a.lng,
                    endLat: cent.lat,
                    endLng: cent.lng,
                  ))
              .reduce(math.min);
          final bBest = centroids
              .map((cent) => LocationHelper.calculateDistanceKm(
                    startLat: b.lat,
                    startLng: b.lng,
                    endLat: cent.lat,
                    endLng: cent.lng,
                  ))
              .reduce(math.min);
          return aBest.compareTo(bBest);
        });

      for (final c in ordered) {
        int bestZone = 0;
        double bestDist = double.infinity;
        for (int z = 0; z < k; z++) {
          if (buckets[z].length >= capacityPerZone) continue;
          final d = LocationHelper.calculateDistanceKm(
            startLat: c.lat,
            startLng: c.lng,
            endLat: centroids[z].lat,
            endLng: centroids[z].lng,
          );
          if (d < bestDist) {
            bestDist = d;
            bestZone = z;
          }
        }
        // Fallback if all zones hit cap: pick least-loaded closest zone
        if (bestDist == double.infinity) {
          for (int z = 0; z < k; z++) {
            final d = LocationHelper.calculateDistanceKm(
                  startLat: c.lat,
                  startLng: c.lng,
                  endLat: centroids[z].lat,
                  endLng: centroids[z].lng,
                ) +
                (buckets[z].length * 2.0);
            if (d < bestDist) {
              bestDist = d;
              bestZone = z;
            }
          }
        }
        buckets[bestZone].add(c);
      }

      // Recompute centroids
      for (int z = 0; z < k; z++) {
        if (buckets[z].isEmpty) continue;
        final avgLat =
            buckets[z].fold<double>(0.0, (s, c) => s + c.lat) / buckets[z].length;
        final avgLng =
            buckets[z].fold<double>(0.0, (s, c) => s + c.lng) / buckets[z].length;
        centroids[z] = (lat: avgLat, lng: avgLng);
      }
    }

    return buckets.where((b) => b.isNotEmpty).toList();
  }

  static List<_StoreCluster> _optimizeDailyRoute({
    required List<_StoreCluster> clusters,
    required double startLat,
    required double startLng,
  }) {
    if (clusters.length <= 1) return List<_StoreCluster>.from(clusters);

    final remaining = List<_StoreCluster>.from(clusters);
    final route = <_StoreCluster>[];
    double curLat = startLat;
    double curLng = startLng;

    while (remaining.isNotEmpty) {
      int bestIdx = 0;
      double bestDist = double.infinity;
      for (int i = 0; i < remaining.length; i++) {
        final d = LocationHelper.calculateDistanceKm(
          startLat: curLat,
          startLng: curLng,
          endLat: remaining[i].lat,
          endLng: remaining[i].lng,
        );
        if (d < bestDist) {
          bestDist = d;
          bestIdx = i;
        }
      }
      final next = remaining.removeAt(bestIdx);
      route.add(next);
      curLat = next.lat;
      curLng = next.lng;
    }

    bool improved = true;
    int guard = 0;
    while (improved && guard < 50) {
      improved = false;
      guard++;
      for (int i = 0; i < route.length - 1; i++) {
        for (int j = i + 1; j < route.length; j++) {
          final beforeCost = _routeDistance(route, startLat, startLng);
          final candidate = List<_StoreCluster>.from(route);
          final reversedSlice = candidate.sublist(i, j + 1).reversed.toList();
          candidate.replaceRange(i, j + 1, reversedSlice);
          final afterCost = _routeDistance(candidate, startLat, startLng);
          if (afterCost + 0.01 < beforeCost) {
            route
              ..clear()
              ..addAll(candidate);
            improved = true;
          }
        }
      }
    }

    return route;
  }

  static double _routeDistance(
    List<_StoreCluster> route,
    double startLat,
    double startLng,
  ) {
    double total = 0.0;
    double prevLat = startLat;
    double prevLng = startLng;
    for (final c in route) {
      total += LocationHelper.calculateDistanceKm(
        startLat: prevLat,
        startLng: prevLng,
        endLat: c.lat,
        endLng: c.lng,
      );
      prevLat = c.lat;
      prevLng = c.lng;
    }
    return total;
  }
}

class _StoreCluster {
  final List<DeliveryOrder> orders;
  final double lat;
  final double lng;
  final double depotDistanceKm;
  final double totalAmount;
  final double priorityScore;

  const _StoreCluster({
    required this.orders,
    required this.lat,
    required this.lng,
    required this.depotDistanceKm,
    required this.totalAmount,
    required this.priorityScore,
  });
}
