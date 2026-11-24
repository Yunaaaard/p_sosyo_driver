import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/core/utils/location_helper.dart';

class RouteLegResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final bool isRoadSnapped;

  const RouteLegResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    required this.isRoadSnapped,
  });
}

/// Free OpenStreetMap driving route service powered by the public OSRM API,
/// with automatic Haversine straight-line fallback when offline.
class OsrmRoutingService {
  OsrmRoutingService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 6),
                headers: {'User-Agent': 'PSosyoDriver/1.0'},
              ),
            );

  final Dio _dio;
  static const int _maxWaypoints = 25;

  Future<RouteLegResult> fetchDrivingRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) {
      return RouteLegResult(
        points: waypoints,
        distanceKm: 0,
        durationMinutes: 0,
        isRoadSnapped: true,
      );
    }

    final capped = waypoints.length > _maxWaypoints
        ? waypoints.sublist(0, _maxWaypoints)
        : waypoints;

    final coordString = capped
        .map((p) =>
            '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
        .join(';');

    final url =
        'https://router.project-osrm.org/route/v1/driving/$coordString?overview=full&geometries=geojson';

    logSync('Requesting OSRM driving route for ${capped.length} waypoint(s)...',
        tag: 'OSRM');

    try {
      final response = await _dio.get<Map<String, dynamic>>(url);
      final data = response.data;
      if (response.statusCode == 200 &&
          data != null &&
          data['code'] == 'Ok' &&
          data['routes'] is List &&
          (data['routes'] as List).isNotEmpty) {
        final route = (data['routes'] as List).first as Map<String, dynamic>;
        final geometry = route['geometry'] as Map<String, dynamic>?;
        final rawCoords = geometry?['coordinates'] as List?;

        if (rawCoords != null && rawCoords.isNotEmpty) {
          final polyPoints = <LatLng>[];
          for (final item in rawCoords) {
            if (item is List && item.length >= 2) {
              final lng = (item[0] as num).toDouble();
              final lat = (item[1] as num).toDouble();
              polyPoints.add(LatLng(lat, lng));
            }
          }

          if (polyPoints.isNotEmpty) {
            final distMeters = (route['distance'] as num?)?.toDouble() ?? 0.0;
            final durSeconds = (route['duration'] as num?)?.toDouble() ?? 0.0;
            final distKm = distMeters / 1000.0;
            final durMins = (durSeconds / 60.0).ceil();

            logSync(
              'OSRM route ready: ${distKm.toStringAsFixed(1)} km (~$durMins min, ${polyPoints.length} pts)',
              tag: 'OSRM',
            );

            return RouteLegResult(
              points: polyPoints,
              distanceKm: distKm,
              durationMinutes: durMins,
              isRoadSnapped: true,
            );
          }
        }
      }

      logWarning(
        'OSRM returned non-Ok response (${data?['code'] ?? response.statusCode}); falling back to straight-line estimate',
        tag: 'OSRM',
      );
    } catch (e) {
      logWarning(
        'OSRM unreachable ($e); using offline straight-line route fallback',
        tag: 'OSRM',
      );
    }

    return _buildHaversineFallback(capped);
  }

  RouteLegResult _buildHaversineFallback(List<LatLng> waypoints) {
    double totalKm = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      totalKm += LocationHelper.calculateDistanceKm(
        startLat: waypoints[i].latitude,
        startLng: waypoints[i].longitude,
        endLat: waypoints[i + 1].latitude,
        endLng: waypoints[i + 1].longitude,
      );
    }
    final mins = (totalKm / 30.0 * 60.0).ceil();
    return RouteLegResult(
      points: waypoints,
      distanceKm: totalKm,
      durationMinutes: mins,
      isRoadSnapped: false,
    );
  }
}
