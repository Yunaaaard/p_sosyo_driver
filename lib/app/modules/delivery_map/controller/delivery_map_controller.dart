import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:p_sosyo_driver/app/core/constants/carto_config.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/core/utils/location_helper.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/data/services/osrm_routing_service.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';
import 'package:p_sosyo_driver/app/widgets/app_date_picker.dart';

class DeliveryMapController extends GetxController {
  final MapController mapController = MapController();
  final OsrmRoutingService _routingService = OsrmRoutingService();

  final RxBool isLoading = true.obs;
  final RxBool isRouting = false.obs;
  final RxBool isRouteActive = false.obs;
  final Rx<LatLng> driverLatLng = const LatLng(
    LocationHelper.defaultDriverLat,
    LocationHelper.defaultDriverLng,
  ).obs;

  final RxList<DeliveryOrder> allOrders = <DeliveryOrder>[].obs;
  final RxnString selectedDateIso = RxnString();
  final RxString searchQuery = ''.obs;
  final RxBool isSearchDropdownOpen = false.obs;
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  final Rxn<DeliveryOrder> selectedOrder = Rxn<DeliveryOrder>();

  final RxList<LatLng> routePolyline = <LatLng>[].obs;
  final RxDouble routeDistanceKm = 0.0.obs;
  final RxInt routeDurationMinutes = 0.obs;
  final RxBool isRoadSnapped = true.obs;
  final RxBool isFollowMode = false.obs;
  final RxBool showTrafficOverlay = true.obs;
  final RxInt trafficRefreshTick = 0.obs;
  final RxDouble driverHeadingRad = 0.0.obs;
  final RxList<RouteStep> routeSteps = <RouteStep>[].obs;
  final Rxn<RouteStep> activeTurnStep = Rxn<RouteStep>();
  final RxDouble distanceToNextTurnMeters = 0.0.obs;
  final RxBool hasArrivedAtSelectedStore = false.obs;

  static const double arrivalThresholdKm = 0.08; // ~80m geofence
  final Set<String> _notifiedArrivalOrderIds = <String>{};

  late final String todayIso;
  late final DateTime todayPht;
  Timer? _gpsTicker;
  Timer? _trafficRefreshTicker;
  StreamSubscription<CompassEvent>? _compassSub;
  bool _mapReady = false;

  @override
  void onInit() {
    super.onInit();
    final nowPht = DateTime.now().toUtc().add(const Duration(hours: 8));
    todayPht = DateTime(nowPht.year, nowPht.month, nowPht.day);
    todayIso = _toIsoDate(todayPht);
    selectedDateIso.value = todayIso;

    LocationHelper.startLocationUpdates();
    _initData();
    _startCompassListener();

    searchFocusNode.addListener(() {
      if (searchFocusNode.hasFocus) {
        isSearchDropdownOpen.value = true;
      }
    });

    _gpsTicker = Timer.periodic(
      const Duration(seconds: 4),
      (_) => refreshDriverGps(recalculateRoute: false),
    );
    _trafficRefreshTicker = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (CartoConfig.hasTomTomTrafficKey && showTrafficOverlay.value) {
          trafficRefreshTick.value++;
          logSync(
            'Refreshed TomTom live traffic overlay (tick #${trafficRefreshTick.value})',
            tag: 'TOMTOM_TRAFFIC',
          );
        }
      },
    );
  }

  @override
  void onClose() {
    _gpsTicker?.cancel();
    _trafficRefreshTicker?.cancel();
    _compassSub?.cancel();
    searchFocusNode.dispose();
    searchController.dispose();
    mapController.dispose();
    super.onClose();
  }

  void _startCompassListener() {
    try {
      _compassSub = FlutterCompass.events?.listen(
        (event) {
          final headingDeg = event.heading;
          if (headingDeg == null || headingDeg.isNaN) return;
          final nextRad = headingDeg * math.pi / 180.0;
          if ((nextRad - driverHeadingRad.value).abs() >= 0.03) {
            driverHeadingRad.value = nextRad;
          }
        },
        onError: (_) {},
      );
    } catch (_) {
      // Simulators or devices without a magnetometer fall back to GPS bearing
    }
  }

  static String _toIsoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _initData() async {
    isLoading.value = true;
    try {
      final coords = await LocationHelper.getCurrentDriverLocation();
      driverLatLng.value = LatLng(coords.latitude, coords.longitude);

      final dbOrders = await DatabaseService.to.getAllDeliveryOrders();
      final resolved = dbOrders
          .map(
            (o) => o.withResolvedLocation(
              driverLat: coords.latitude,
              driverLng: coords.longitude,
            ),
          )
          .toList();
      allOrders.assignAll(resolved);

      if (_mapReady) {
        fitAllMarkers();
      }
    } catch (e, stack) {
      logError('Error initializing DeliveryMapController', e, stack);
    } finally {
      isLoading.value = false;
    }
  }

  void onMapReady() {
    _mapReady = true;
    fitAllMarkers();
  }

  Future<void> refreshDriverGps({bool recalculateRoute = false}) async {
    try {
      final coords = await LocationHelper.getCurrentDriverLocation();
      final movedKm = LocationHelper.calculateDistanceKm(
        startLat: driverLatLng.value.latitude,
        startLng: driverLatLng.value.longitude,
        endLat: coords.latitude,
        endLng: coords.longitude,
      );
      if (movedKm >= 0.005) {
        driverHeadingRad.value = _computeBearingRad(
          driverLatLng.value,
          LatLng(coords.latitude, coords.longitude),
        );
      }
      driverLatLng.value = LatLng(coords.latitude, coords.longitude);

      if (allOrders.isNotEmpty) {
        final updated = allOrders
            .map(
              (o) => o.withResolvedLocation(
                driverLat: coords.latitude,
                driverLng: coords.longitude,
              ),
            )
            .toList();
        allOrders.assignAll(updated);

        if (selectedOrder.value != null) {
          final match =
              updated.where((o) => o.id == selectedOrder.value!.id).toList();
          if (match.isNotEmpty) {
            selectedOrder.value = match.first;
          }
        }
      }

      if (isFollowMode.value && _mapReady) {
        try {
          final zoom = mapController.camera.zoom;
          mapController.move(
            driverLatLng.value,
            zoom < 15.0 ? 16.0 : zoom,
          );
        } catch (_) {}
      }

      _evaluateArrivalGeofence();
      _updateTurnGuidance();

      if (isRouteActive.value &&
          selectedOrder.value != null &&
          (recalculateRoute || movedKm >= 0.08)) {
        await rebuildRoute();
      }
    } catch (e, stack) {
      logError('GPS refresh error on DeliveryMapController', e, stack);
    }
  }

  List<String> get availableDateIsos {
    final Set<String> dates = {
      for (int i = 0; i < 7; i++) _toIsoDate(todayPht.add(Duration(days: i))),
    };
    for (final order in allOrders) {
      dates.add(HomeController.resolveEffectiveDateIso(order));
    }
    final list = dates.toList()..sort();
    return list;
  }

  int countForDate(String? iso) {
    if (iso == null || iso.isEmpty) return allOrders.length;
    return allOrders
        .where((o) => HomeController.resolveEffectiveDateIso(o) == iso)
        .length;
  }

  void openSearchDropdown() {
    isSearchDropdownOpen.value = true;
  }

  void closeSearchDropdown() {
    isSearchDropdownOpen.value = false;
    searchFocusNode.unfocus();
  }

  void updateSearchQuery(String value) {
    searchQuery.value = value;
    isSearchDropdownOpen.value = true;
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
    isSearchDropdownOpen.value = false;
    searchFocusNode.unfocus();
  }

  List<DeliveryOrder> get filteredOrders {
    final dateFilter = selectedDateIso.value;
    final query = searchQuery.value.trim().toLowerCase();
    final matched = allOrders.where((o) {
      final matchesDate = dateFilter == null ||
          dateFilter.isEmpty ||
          HomeController.resolveEffectiveDateIso(o) == dateFilter;
      if (!matchesDate) return false;
      if (query.isEmpty) return true;
      return o.storeName.toLowerCase().contains(query) ||
          o.address.toLowerCase().contains(query) ||
          o.id.toLowerCase().contains(query) ||
          o.custCode.toLowerCase().contains(query);
    }).toList();

    int statusRank(DeliveryOrder o) {
      final s = o.status.value.trim();
      if (s == 'Out for Delivery' && !o.isLocked) return 0;
      if (s == 'Out for Delivery' && o.isLocked) return 1;
      if (s == 'Delivered') return 2;
      return 3; // Cancelled
    }

    matched.sort((a, b) {
      final rankCmp = statusRank(a).compareTo(statusRank(b));
      if (rankCmp != 0) return rankCmp;
      final aSeq = a.routeSequence ?? 999999;
      final bSeq = b.routeSequence ?? 999999;
      if (aSeq != bSeq) return aSeq.compareTo(bSeq);
      return (a.distanceKm ?? double.infinity)
          .compareTo(b.distanceKm ?? double.infinity);
    });
    return matched;
  }

  Future<void> rebuildRoute() async {
    final selected = selectedOrder.value;
    if (selected == null ||
        !LocationHelper.isValidCoordinate(
            selected.latitude, selected.longitude)) {
      clearRoute();
      return;
    }

    final waypoints = <LatLng>[
      driverLatLng.value,
      LatLng(selected.latitude!, selected.longitude!),
    ];

    isRouting.value = true;
    try {
      final res = await _routingService.fetchDrivingRoute(waypoints);
      routePolyline.assignAll(res.points);
      routeDistanceKm.value = res.distanceKm;
      routeDurationMinutes.value = res.durationMinutes;
      isRoadSnapped.value = res.isRoadSnapped;
      routeSteps.assignAll(res.steps);
      isRouteActive.value = true;
      _updateTurnGuidance();
      _evaluateArrivalGeofence();
    } catch (e, stack) {
      logError('Failed rebuilding OSRM route', e, stack);
    } finally {
      isRouting.value = false;
    }
  }

  void clearRoute() {
    routePolyline.clear();
    routeSteps.clear();
    activeTurnStep.value = null;
    distanceToNextTurnMeters.value = 0.0;
    routeDistanceKm.value = 0.0;
    routeDurationMinutes.value = 0;
    isRoadSnapped.value = true;
    isRouteActive.value = false;
    isFollowMode.value = false;
  }

  void toggleFollowMode() {
    final next = !isFollowMode.value;
    isFollowMode.value = next;
    if (next && _mapReady) {
      try {
        mapController.move(driverLatLng.value, 16.0);
      } catch (_) {}
    }
  }

  void toggleTrafficOverlay() {
    showTrafficOverlay.value = !showTrafficOverlay.value;
  }

  void pauseFollowModeOnGesture() {
    if (isFollowMode.value) {
      isFollowMode.value = false;
    }
  }

  double _computeBearingRad(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;
    final dLng = (to.longitude - from.longitude) * math.pi / 180.0;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return math.atan2(y, x);
  }

  void _updateTurnGuidance() {
    if (!isRouteActive.value || routeSteps.isEmpty) {
      activeTurnStep.value = null;
      distanceToNextTurnMeters.value = 0.0;
      return;
    }

    // Pick the first meaningful upcoming step > 20m away (skipping 'depart' if already moving)
    final driver = driverLatLng.value;
    RouteStep? chosen;
    double chosenMeters = 0.0;

    for (final step in routeSteps) {
      final meters = LocationHelper.calculateDistanceKm(
            startLat: driver.latitude,
            startLng: driver.longitude,
            endLat: step.location.latitude,
            endLng: step.location.longitude,
          ) *
          1000.0;

      if (step.maneuverType == 'depart' &&
          routeSteps.length > 1 &&
          meters < 35) {
        continue;
      }
      if (meters > 18 || step.maneuverType == 'arrive') {
        chosen = step;
        chosenMeters = meters;
        break;
      }
    }

    chosen ??= routeSteps.last;
    activeTurnStep.value = chosen;
    distanceToNextTurnMeters.value = chosenMeters;
  }

  void _evaluateArrivalGeofence() {
    final order = selectedOrder.value;
    if (order == null ||
        !LocationHelper.isValidCoordinate(order.latitude, order.longitude)) {
      hasArrivedAtSelectedStore.value = false;
      return;
    }

    final distKm = LocationHelper.calculateDistanceKm(
      startLat: driverLatLng.value.latitude,
      startLng: driverLatLng.value.longitude,
      endLat: order.latitude!,
      endLng: order.longitude!,
    );
    final arrived = distKm <= arrivalThresholdKm;
    hasArrivedAtSelectedStore.value = arrived;

    if (arrived && !_notifiedArrivalOrderIds.contains(order.id)) {
      _notifiedArrivalOrderIds.add(order.id);
      HapticFeedback.mediumImpact();
      Get.snackbar(
        'Arrived at Store',
        'You are within ${(distKm * 1000).round()} m of ${order.storeName}.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFE8F5E9),
        colorText: const Color(0xFF15803D),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// Selects a store pin without auto-routing; driver taps "Route Here" manually.
  void selectOrderPin(DeliveryOrder? order) {
    if (order == null && selectedOrder.value == null) return;
    selectedOrder.value = order;
    clearRoute();
    _evaluateArrivalGeofence();

    if (!_mapReady || order == null) return;
    if (LocationHelper.isValidCoordinate(order.latitude, order.longitude)) {
      try {
        final target = LatLng(order.latitude!, order.longitude!);
        final currentZoom = mapController.camera.zoom;
        mapController.move(target, currentZoom < 14.0 ? 14.5 : currentZoom);
      } catch (_) {}
    }
  }

  /// Manually triggers road routing from live Driver GPS to [selectedOrder]
  /// and enables Follow Mode.
  Future<void> routeToSelectedOrder() async {
    final order = selectedOrder.value;
    if (order == null) return;
    await rebuildRoute();
    isFollowMode.value = true;

    if (!_mapReady) return;
    try {
      mapController.move(driverLatLng.value, 16.0);
    } catch (_) {}
  }

  Future<void> selectDate(String? dateIso) async {
    selectedDateIso.value = dateIso;
    selectedOrder.value = null;
    clearRoute();
    fitAllMarkers();
  }

  Future<void> pickCalendarDate(BuildContext context) async {
    final current = selectedDateIso.value != null
        ? (DateTime.tryParse(selectedDateIso.value!) ?? todayPht)
        : todayPht;

    final picked = await showAppDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'SELECT DELIVERY MAP DATE',
      confirmText: 'View Pins',
    );
    if (picked != null) {
      await selectDate(_toIsoDate(picked));
    }
  }

  void recenterOnDriver() {
    if (!_mapReady) return;
    try {
      mapController.move(driverLatLng.value, 14.5);
    } catch (_) {}
  }

  void fitAllMarkers() {
    if (!_mapReady) return;
    final pts = <LatLng>[driverLatLng.value];
    for (final order in filteredOrders) {
      if (LocationHelper.isValidCoordinate(order.latitude, order.longitude)) {
        pts.add(LatLng(order.latitude!, order.longitude!));
      }
    }
    try {
      if (pts.length == 1) {
        mapController.move(pts.first, 14.0);
        return;
      }
      final bounds = LatLngBounds.fromPoints(pts);
      mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(48, 165, 48, 220),
        ),
      );
    } catch (_) {}
  }
}
