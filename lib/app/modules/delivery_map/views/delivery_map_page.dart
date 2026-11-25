import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:p_sosyo_driver/app/core/constants/app_constants.dart';
import 'package:p_sosyo_driver/app/core/constants/carto_config.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/core/utils/location_helper.dart';
import 'package:p_sosyo_driver/app/core/utils/peso_formatter.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/modules/delivery_map/controller/delivery_map_controller.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';
import 'package:p_sosyo_driver/app/widgets/custom_appBar.dart';
import 'package:p_sosyo_driver/app/widgets/status_badge.dart';
import 'package:p_sosyo_driver/app/widgets/store_image_widget.dart';

class DeliveryMapPage extends StatelessWidget {
  const DeliveryMapPage({super.key});

  DeliveryMapController get controller =>
      Get.isRegistered<DeliveryMapController>()
          ? Get.find<DeliveryMapController>()
          : Get.put(DeliveryMapController());

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      resizeToAvoidBottomInset: false,
      appBar: CustomAppBar(
        title: 'Delivery Route Map',
        showBackButton: true,
        trailing: Tooltip(
          message: 'Map Legend & Guide',
          child: InkWell(
            onTap: () => _showMapGuideDialog(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.25),
                ),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final initialCenter = controller.driverLatLng.value;

        return Stack(
          children: [
            // ── 1. Interactive Map Canvas (Isolated from UI/search rebuilds) ──
            RepaintBoundary(
              child: FlutterMap(
                mapController: controller.mapController,
                options: MapOptions(
                  initialCenter: initialCenter,
                  initialZoom: 12.5,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: (_, __) {
                    controller.closeSearchDropdown();
                    controller.selectOrderPin(null);
                  },
                  onPositionChanged: (_, hasGesture) {
                    if (hasGesture) {
                      controller.pauseFollowModeOnGesture();
                    }
                  },
                  onMapReady: controller.onMapReady,
                ),
                children: [
                  Obx(() {
                    final showTraffic = CartoConfig.hasTomTomTrafficKey &&
                        controller.showTrafficOverlay.value;
                    return TileLayer(
                      key: ValueKey(showTraffic ? 'basemap_nolabels' : 'basemap_full'),
                      urlTemplate: showTraffic
                          ? CartoConfig.noLabelsTileUrlTemplate
                          : CartoConfig.tileUrlTemplate,
                      subdomains: const ['a', 'b', 'c', 'd'],
                      keepBuffer: 3,
                      panBuffer: 1,
                      userAgentPackageName: 'com.example.p_sosyo_driver',
                    );
                  }),
                  Obx(() {
                    if (!CartoConfig.hasTomTomTrafficKey ||
                        !controller.showTrafficOverlay.value) {
                      return const SizedBox.shrink();
                    }
                    final tick = controller.trafficRefreshTick.value;
                    return Opacity(
                      opacity: 0.82,
                      child: TileLayer(
                        key: ValueKey('traffic_layer_$tick'),
                        urlTemplate:
                            '${CartoConfig.tomtomTrafficTileUrlTemplate}&_t=$tick',
                        tileProvider: NetworkTileProvider(),
                        keepBuffer: 2,
                        panBuffer: 1,
                        userAgentPackageName: 'com.example.p_sosyo_driver',
                      ),
                    );
                  }),
                  Obx(() {
                    if (!CartoConfig.hasTomTomTrafficKey ||
                        !controller.showTrafficOverlay.value) {
                      return const SizedBox.shrink();
                    }
                    return IgnorePointer(
                      child: TileLayer(
                        key: const ValueKey('basemap_only_labels'),
                        urlTemplate: CartoConfig.onlyLabelsTileUrlTemplate,
                        subdomains: const ['a', 'b', 'c', 'd'],
                        keepBuffer: 3,
                        panBuffer: 1,
                        userAgentPackageName: 'com.example.p_sosyo_driver',
                      ),
                    );
                  }),
                  Obx(() {
                    final poly = controller.routePolyline.toList();
                    final isRoad = controller.isRoadSnapped.value;
                    if (poly.length < 2) return const SizedBox.shrink();
                    return PolylineLayer(
                      simplificationTolerance: 0.4,
                      polylines: [
                        Polyline(
                          points: poly,
                          strokeWidth: 7.5,
                          color: const Color(0xEBFFFFFF),
                        ),
                        Polyline(
                          points: poly,
                          strokeWidth: 4.5,
                          color: isRoad
                              ? const Color(0xFF2E6BFF)
                              : AppColors.warning,
                        ),
                      ],
                    );
                  }),
                  Obx(() {
                    final orders = controller.filteredOrders;
                    final selected = controller.selectedOrder.value;
                    final driverPos = controller.driverLatLng.value;
                    return MarkerLayer(
                      rotate: false,
                      markers: [
                        ..._buildStoreMarkers(orders, selected, reduceMotion),
                        Marker(
                          key: const ValueKey('driver_marker'),
                          point: driverPos,
                          width: 104,
                          height: 104,
                          child: RepaintBoundary(
                            child: Obx(() {
                              final headingRad =
                                  controller.driverHeadingRad.value;
                              final isFollow = controller.isFollowMode.value;
                              return Transform.rotate(
                                angle: headingRad,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 104,
                                      height: 104,
                                      child: CustomPaint(
                                        painter: _HeadingGlowConePainter(),
                                      ),
                                    ),
                                    Container(
                                      width: 50,
                                      height: 50,
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isFollow
                                              ? AppColors.primary
                                              : AppColors.surfaceDark,
                                          width: 2.5,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x590E1B4D),
                                            blurRadius: 8,
                                            offset: Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: SvgPicture.asset(
                                        AppConstants.truck3dAsset,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),

            // ── 2. Top Floating Telemetry & Date Picker Bar ──
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.md,
              right: AppSpacing.md,
              child: Obx(() {
                final orders = controller.filteredOrders;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTelemetryBanner(orders.length),
                    if (controller.isRouteActive.value &&
                        controller.activeTurnStep.value != null) ...[
                      const SizedBox(height: 6),
                      _buildTurnGuidanceBanner(),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    _buildDateFilterBar(context),
                    const SizedBox(height: AppSpacing.sm),
                    _buildCustomerSearchBar(context, orders),
                  ],
                );
              }),
            ),

            // ── 3. Floating Right Map Controls ──
            Obx(() {
              final hasSelected = controller.selectedOrder.value != null;
              final isFollowing = controller.isFollowMode.value;
              final trafficOn = controller.showTrafficOverlay.value;
              return Positioned(
                right: AppSpacing.md,
                bottom: hasSelected ? 225 : 138,
                child: Column(
                  children: [
                    if (CartoConfig.hasTomTomTrafficKey) ...[
                      _MapFloatingButton(
                        icon: Icons.traffic_rounded,
                        tooltip: trafficOn
                            ? 'Hide Live Traffic'
                            : 'Show Live Traffic',
                        isActive: trafficOn,
                        onTap: controller.toggleTrafficOverlay,
                      ),
                      const SizedBox(height: 8),
                    ],
                    _MapFloatingButton(
                      icon: isFollowing
                          ? Icons.navigation_rounded
                          : Icons.navigation_outlined,
                      tooltip: isFollowing
                          ? 'Following Truck (Tap to Pause)'
                          : 'Follow Truck',
                      isActive: isFollowing,
                      onTap: controller.toggleFollowMode,
                    ),
                    const SizedBox(height: 8),
                    _MapFloatingButton(
                      icon: Icons.fit_screen_rounded,
                      tooltip: 'Fit All Pins',
                      onTap: controller.fitAllMarkers,
                    ),
                    const SizedBox(height: 8),
                    _MapFloatingButton(
                      icon: Icons.my_location_rounded,
                      tooltip: 'Center on My GPS',
                      onTap: controller.recenterOnDriver,
                    ),
                  ],
                ),
              );
            }),

            // ── 4. Animated Bottom Stop Card ──
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: SafeArea(
                top: false,
                child: Obx(() {
                  final selected = controller.selectedOrder.value;
                  final orders = controller.filteredOrders;
                  return AnimatedSwitcher(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: _buildBottomCard(selected, orders),
                  );
                }),
              ),
            ),
          ],
        );
      }),
    );
  }

  static Color _weekdayColor(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return const Color(0xFF2563EB); // Cobalt Blue
      case DateTime.tuesday:
        return const Color(0xFF0D9488); // Teal
      case DateTime.wednesday:
        return const Color(0xFF7C3AED); // Violet
      case DateTime.thursday:
        return const Color(0xFF4F46E5); // Indigo
      case DateTime.friday:
        return const Color(0xFFDB2777); // Rose
      case DateTime.saturday:
        return const Color(0xFF0284C7); // Sky Blue
      case DateTime.sunday:
        return const Color(0xFFD97706); // Amber
      default:
        return AppColors.primary;
    }
  }

  static Color? _dayColorForIso(String? iso) {
    if (iso == null || iso.length < 10) return null;
    final dt = DateTime.tryParse(iso.substring(0, 10));
    if (dt == null) return null;
    return _weekdayColor(dt.weekday);
  }

  void _showMapGuideDialog(BuildContext context) {
    const days = [
      (DateTime.monday, 'Monday', 'Cobalt Blue'),
      (DateTime.tuesday, 'Tuesday', 'Teal'),
      (DateTime.wednesday, 'Wednesday', 'Violet'),
      (DateTime.thursday, 'Thursday', 'Indigo'),
      (DateTime.friday, 'Friday', 'Rose'),
      (DateTime.saturday, 'Saturday', 'Sky Blue'),
      (DateTime.sunday, 'Sunday', 'Amber'),
    ];

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x260F172A),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery Map Guide',
                            style: AppTypography.title.copyWith(fontSize: 17),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'FYI · Pin colors & quick map tips',
                            style: AppTypography.caption.copyWith(fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.inkMuted,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DELIVERY DAY PIN COLORS',
                        style: AppTypography.monoRef.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkMuted,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: days.map((entry) {
                          final color = _weekdayColor(entry.$1);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                              border: Border.all(
                                color: color.withOpacity(0.32),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${entry.$2} · ${entry.$3}',
                                  style: AppTypography.label.copyWith(
                                    fontSize: 12,
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'HOW TO USE THE MAP',
                  style: AppTypography.monoRef.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                const _MapTipRow(
                  step: '1',
                  icon: Icons.touch_app_rounded,
                  title: 'Tap a store pin',
                  description:
                      'Select any store marker to preview its address, total amount, and order reference.',
                ),
                const SizedBox(height: 8),
                const _MapTipRow(
                  step: '2',
                  icon: Icons.alt_route_rounded,
                  title: 'Tap "Route" when ready',
                  description:
                      'Routes are drawn manually on demand so you can browse pins without auto-routing.',
                ),
                const SizedBox(height: 8),
                const _MapTipRow(
                  step: '3',
                  icon: Icons.filter_alt_outlined,
                  title: 'Filter by day or search',
                  description:
                      'Use Today, All, Calendar, or the search bar to find customers on specific delivery days.',
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Marker> _buildStoreMarkers(
    List<DeliveryOrder> orders,
    DeliveryOrder? selected,
    bool reduceMotion,
  ) {
    final valid = orders
        .where((o) => LocationHelper.isValidCoordinate(o.latitude, o.longitude))
        .toList();

    // Group co-located coordinates (~10m bucket) so overlapping pins spread cleanly
    final Map<String, List<DeliveryOrder>> coordGroups = {};
    for (final o in valid) {
      final key =
          '${o.latitude!.toStringAsFixed(4)}_${o.longitude!.toStringAsFixed(4)}';
      coordGroups.putIfAbsent(key, () => []).add(o);
    }

    int activeSequenceCounter = 0;
    final List<({Marker marker, bool isSelected})> built = [];

    for (final order in valid) {
      final status = order.status.value.trim();
      final isDelivered = status == 'Delivered';
      final isCancelled = status == 'Cancelled';
      final isLocked = status == 'Out for Delivery' && order.isLocked;
      final isActive = status == 'Out for Delivery' && !order.isLocked;
      if (isActive) {
        activeSequenceCounter++;
      }
      final pinNum = order.routeSequence ?? activeSequenceCounter;
      final isSelected = selected?.id == order.id;

      final key =
          '${order.latitude!.toStringAsFixed(4)}_${order.longitude!.toStringAsFixed(4)}';
      final group = coordGroups[key] ?? [order];
      LatLng point = LatLng(order.latitude!, order.longitude!);
      if (group.length > 1) {
        final idxInGroup = group.indexWhere((g) => g.id == order.id);
        final angle = (2 * math.pi * idxInGroup) / group.length;
        const double radiusDeg = 0.00032; // ~32m visual spread
        point = LatLng(
          order.latitude! + radiusDeg * math.sin(angle),
          order.longitude! + radiusDeg * math.cos(angle),
        );
      }

      final dayColor =
          _dayColorForIso(HomeController.resolveEffectiveDateIso(order));

      built.add((
        isSelected: isSelected,
        marker: Marker(
          key: ValueKey('pin_${order.id}'),
          point: point,
          width: 52,
          height: 52,
          child: RepaintBoundary(
            child: GestureDetector(
              onTap: () => controller.selectOrderPin(order),
              child: AnimatedScale(
                scale: isSelected ? 1.22 : 1.0,
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: _StoreMapMarker(
                  isDelivered: isDelivered,
                  isCancelled: isCancelled,
                  isLocked: isLocked,
                  isSelected: isSelected,
                  sequenceNumber: pinNum,
                  activeColor: dayColor,
                ),
              ),
            ),
          ),
        ),
      ));
    }

    // Draw selected pin last so it always sits on top
    built.sort((a, b) => a.isSelected == b.isSelected ? 0 : (a.isSelected ? 1 : -1));
    return built.map((e) => e.marker).toList();
  }

  Widget _buildTelemetryBanner(int stopCount) {
    final km = controller.routeDistanceKm.value;
    final mins = controller.routeDurationMinutes.value;
    final isRoad = controller.isRoadSnapped.value;
    final isRouting = controller.isRouting.value;
    final hasRoute = controller.isRouteActive.value;
    final selected = controller.selectedOrder.value;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: [
          BoxShadow(
            color: AppColors.surfaceDark.withOpacity(0.24),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isRouting)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.alt_route_rounded,
                size: 16,
                color: Color(0xFF60A5FA),
              ),
            ),
          Expanded(
            child: Text(
              hasRoute
                  ? 'Driver → Pin · ${km.toStringAsFixed(1)} km · ~$mins min'
                  : selected != null
                      ? '${selected.storeName} · ${selected.formattedDistanceAway}'
                      : '$stopCount ${stopCount == 1 ? 'pin' : 'pins'} · Tap any pin to inspect',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(
                fontSize: 13.5,
                color: Colors.white,
              ),
            ),
          ),
          if (hasRoute) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isRoad ? AppColors.success : AppColors.warning,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                isRoad ? 'Road Route' : 'Offline Est.',
                style: AppTypography.monoRef.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTurnGuidanceBanner() {
    final step = controller.activeTurnStep.value;
    if (step == null) return const SizedBox.shrink();

    final meters = controller.distanceToNextTurnMeters.value;
    final distText = meters >= 1000
        ? '${(meters / 1000.0).toStringAsFixed(1)} km'
        : '${meters.round()} m';

    final IconData turnIcon = switch (step.maneuverType) {
      'arrive' => Icons.flag_rounded,
      'roundabout' || 'rotary' => Icons.roundabout_right_rounded,
      _ => step.modifier.contains('left')
          ? Icons.turn_left_rounded
          : step.modifier.contains('right')
              ? Icons.turn_right_rounded
              : Icons.straight_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331E3A8A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(turnIcon, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              step.instruction,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(
                fontSize: 13.5,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              distText,
              style: AppTypography.monoRef.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSearchBar(
    BuildContext context,
    List<DeliveryOrder> matchedOrders,
  ) {
    final query = controller.searchQuery.value.trim();
    final dateLabel = controller.selectedDateIso.value == null
        ? 'All Dates'
        : (controller.selectedDateIso.value == controller.todayIso
            ? 'Today'
            : HomeController.formatDateLabel(
                controller.selectedDateIso.value!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.surface,
          elevation: 2,
          shadowColor: AppColors.surfaceDark.withOpacity(0.14),
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: TextField(
            controller: controller.searchController,
            focusNode: controller.searchFocusNode,
            onTap: controller.openSearchDropdown,
            onChanged: controller.updateSearchQuery,
            textInputAction: TextInputAction.search,
            style: AppTypography.body.copyWith(
              fontSize: 13.5,
              color: AppColors.inkPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search customer on $dateLabel...',
              hintStyle: AppTypography.body.copyWith(
                fontSize: 13.5,
                color: AppColors.inkMuted,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 19,
                color: AppColors.primary,
              ),
              suffixIcon: (query.isNotEmpty ||
                      controller.isSearchDropdownOpen.value)
                  ? IconButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        controller.clearSearch();
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.inkMuted,
                      ),
                    )
                  : const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppColors.inkMuted,
                    ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
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
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        if (controller.isSearchDropdownOpen.value)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.surfaceDark.withOpacity(0.14),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: matchedOrders.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'No customers found on $dateLabel',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        fontSize: 13,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: matchedOrders.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (_, idx) {
                      final o = matchedOrders[idx];
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.storefront_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          o.storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(fontSize: 13.5),
                        ),
                        subtitle: Text(
                          'Ref #${o.id} · ${o.formattedDistanceAway}',
                          style: AppTypography.monoRef.copyWith(
                            fontSize: 11,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.near_me_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        onTap: () {
                          controller.closeSearchDropdown();
                          controller.selectOrderPin(o);
                        },
                      );
                    },
                  ),
          ),
      ],
    );
  }

  Widget _buildDateFilterBar(BuildContext context) {
    final activeIso = controller.selectedDateIso.value;
    final dateList = controller.availableDateIsos;

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Calendar Picker Pill Button
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            elevation: 2,
            shadowColor: AppColors.surfaceDark.withOpacity(0.14),
            child: InkWell(
              onTap: () => controller.pickCalendarDate(context),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Calendar',
                      style: AppTypography.label.copyWith(
                        fontSize: 12.5,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // All Dates Pill
          _DateChip(
            label: 'All (${controller.countForDate(null)})',
            selected: activeIso == null,
            onTap: () => controller.selectDate(null),
          ),
          const SizedBox(width: 6),

          // Individual Date Pills
          ...dateList.map((iso) {
            final isToday = iso == controller.todayIso;
            final labelText =
                isToday ? 'Today' : HomeController.formatDateLabel(iso);
            final count = controller.countForDate(iso);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _DateChip(
                label: '$labelText ($count)',
                selected: activeIso == iso,
                dotColor: _dayColorForIso(iso),
                onTap: () => controller.selectDate(iso),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomCard(
    DeliveryOrder? selected,
    List<DeliveryOrder> orders,
  ) {
    if (selected != null) {
      final hasArrived = controller.hasArrivedAtSelectedStore.value;
      return SurfaceCard(
        key: ValueKey('map_selected_${selected.id}'),
        padding: const EdgeInsets.all(AppSpacing.md),
        borderColor:
            hasArrived ? AppColors.successBorder : AppColors.primaryBorder,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                StoreImageWidget(
                  imageUrl: selected.storePhoto,
                  custCode: selected.custCode,
                  width: 44,
                  height: 44,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  fallback: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label.copyWith(fontSize: 15.5),
                      ),
                      Text(
                        selected.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          fontSize: 12.5,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text.rich(
                  PesoFormatter.buildPesoTextSpan(
                    amount: selected.totalAmount.replaceAll('₱', '').trim(),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (controller.hasArrivedAtSelectedStore.value) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.successTint,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 12,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Arrived',
                          style: AppTypography.monoRef.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    controller.isRouteActive.value
                        ? '${controller.routeDistanceKm.value.toStringAsFixed(1)} km · ~${controller.routeDurationMinutes.value} min'
                        : selected.formattedDistanceAway,
                    style: AppTypography.monoRef.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${HomeController.formatDateLabel(HomeController.resolveEffectiveDateIso(selected))} · Ref #${selected.id}',
                  style: AppTypography.monoRef.copyWith(
                    fontSize: 11.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: controller.isRouteActive.value
                      ? OutlinedButton(
                          onPressed: controller.clearRoute,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.inkSecondary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                          ),
                          child: Text(
                            'Clear Route',
                            style: AppTypography.label.copyWith(
                              fontSize: 12.5,
                              color: AppColors.inkSecondary,
                            ),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: controller.isRouting.value
                              ? null
                              : controller.routeToSelectedOrder,
                          icon: const Icon(Icons.alt_route_rounded, size: 16),
                          label: Text(
                            controller.isRouting.value
                                ? 'Routing...'
                                : 'Route Here',
                            style: AppTypography.label.copyWith(
                              fontSize: 12.5,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => LocationHelper.openGoogleMapsDirections(
                      destLat: selected.latitude ?? LocationHelper.defaultDriverLat,
                      destLng: selected.longitude ?? LocationHelper.defaultDriverLng,
                      originLat: controller.driverLatLng.value.latitude,
                      originLng: controller.driverLatLng.value.longitude,
                      storeName: selected.storeName,
                    ),
                    icon: const Icon(Icons.directions_rounded, size: 16),
                    label: Text(
                      'Navigate',
                      style: AppTypography.label.copyWith(
                        fontSize: 12.5,
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primaryBorder),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Get.toNamed(
                      AppRoutes.orderDetails,
                      arguments: selected,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: controller.hasArrivedAtSelectedStore.value
                          ? AppColors.success
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    child: Text(
                      controller.hasArrivedAtSelectedStore.value
                          ? 'Start Delivery'
                          : 'View Order',
                      style: AppTypography.label.copyWith(
                        fontSize: 12.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (orders.isEmpty) {
      return SurfaceCard(
        key: const ValueKey('map_empty_date'),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          'No deliveries scheduled for this date. Tap another date pill or Calendar above.',
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(
            fontSize: 13.5,
            color: AppColors.inkMuted,
          ),
        ),
      );
    }

    final firstStop = orders.first;
    return SurfaceCard(
      key: ValueKey('map_overview_${firstStop.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: const Icon(
              Icons.pin_drop_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Next Stop · ${firstStop.storeName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(fontSize: 14),
                ),
                Text(
                  'Tap any store pin to inspect or route',
                  style: AppTypography.caption.copyWith(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => controller.selectOrderPin(firstStop),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primaryBorder),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
            ),
            child: Text(
              'Select Pin',
              style: AppTypography.label.copyWith(
                fontSize: 12.5,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreMapMarker extends StatelessWidget {
  const _StoreMapMarker({
    required this.isDelivered,
    required this.isCancelled,
    required this.isLocked,
    required this.isSelected,
    required this.sequenceNumber,
    this.activeColor,
  });

  final bool isDelivered;
  final bool isCancelled;
  final bool isLocked;
  final bool isSelected;
  final int sequenceNumber;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = isDelivered
        ? AppColors.success
        : isCancelled
            ? AppColors.danger
            : isLocked
                ? AppColors.warning
                : (activeColor ?? AppColors.primary);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? AppColors.surfaceDark : badgeColor,
              width: isSelected ? 2.8 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.surfaceDark.withOpacity(0.28),
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: SvgPicture.asset(
              AppConstants.shopIconAsset,
              width: 34,
              height: 34,
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            alignment: Alignment.center,
            child: isDelivered
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 12)
                : isCancelled
                    ? const Icon(Icons.do_not_disturb_alt_rounded,
                        color: Colors.white, size: 11)
                    : isLocked
                        ? const Icon(Icons.lock_clock_outlined,
                            color: Colors.white, size: 11)
                        : Text(
                            '$sequenceNumber',
                            style: AppTypography.monoRef.copyWith(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
          ),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dotColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final activeBg = dotColor ?? AppColors.primary;
    return Material(
      color: selected ? activeBg : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      elevation: 2,
      shadowColor: AppColors.surfaceDark.withOpacity(0.14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: selected ? activeBg : AppColors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTypography.label.copyWith(
                  fontSize: 12.5,
                  color: selected ? Colors.white : AppColors.inkPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapFloatingButton extends StatelessWidget {
  const _MapFloatingButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive ? AppColors.primary : AppColors.surface,
        elevation: 3,
        shadowColor: AppColors.surfaceDark.withOpacity(0.18),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : AppColors.primary,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapTipRow extends StatelessWidget {
  const _MapTipRow({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
  });

  final String step;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$step. $title',
                style: AppTypography.label.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTypography.caption.copyWith(
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Google Maps–style directional heading cone glow pointing toward the
/// driver's current travel bearing.
class _HeadingGlowConePainter extends CustomPainter {
  const _HeadingGlowConePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Soft ambient blue halo around the truck
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primary.withOpacity(0.26),
          AppColors.primary.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.72));
    canvas.drawCircle(center, radius * 0.72, haloPaint);

    // Directional 76-degree cone pointing "up" (-pi/2); rotated by Transform.rotate
    const double sweepAngle = 76 * math.pi / 180;
    const double startAngle = -math.pi / 2 - sweepAngle / 2;
    final coneRect = Rect.fromCircle(center: center, radius: radius);

    final conePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF3B82F6).withOpacity(0.48),
          const Color(0xFF3B82F6).withOpacity(0.18),
          const Color(0xFF3B82F6).withOpacity(0.0),
        ],
        stops: const [0.18, 0.58, 1.0],
      ).createShader(coneRect);

    canvas.drawArc(coneRect, startAngle, sweepAngle, true, conePaint);
  }

  @override
  bool shouldRepaint(covariant _HeadingGlowConePainter oldDelegate) => false;
}
