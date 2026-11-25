import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:p_sosyo_driver/app/core/constants/carto_config.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/core/utils/location_helper.dart';

class RouteStep {
  final String instruction;
  final double distanceMeters;
  final String maneuverType;
  final String modifier;
  final LatLng location;

  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.maneuverType,
    required this.modifier,
    required this.location,
  });
}

class RouteLegResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final bool isRoadSnapped;
  final List<RouteStep> steps;

  const RouteLegResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    required this.isRoadSnapped,
    this.steps = const [],
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

    // 1. Primary: CARTO LDS Routing API (when CartoConfig.accessToken is configured)
    if (CartoConfig.accessToken.trim().isNotEmpty) {
      final cartoResult = await _fetchCartoLdsRoute(capped);
      if (cartoResult != null) {
        return cartoResult;
      }
    }

    // 2. Fallback: Public OSRM driving route API
    final coordString = capped
        .map((p) =>
            '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
        .join(';');

    final url =
        'https://router.project-osrm.org/route/v1/driving/$coordString?overview=full&geometries=geojson&steps=true';

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
            final steps = _parseOsrmSteps(route['legs'] as List?);

            logSync(
              'OSRM route ready: ${distKm.toStringAsFixed(1)} km (~$durMins min, ${polyPoints.length} pts, ${steps.length} steps)',
              tag: 'OSRM',
            );

            return RouteLegResult(
              points: polyPoints,
              distanceKm: distKm,
              durationMinutes: durMins,
              isRoadSnapped: true,
              steps: steps,
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

  /// Queries CARTO Location Data Services (`GET /v3/lds/routing`) per leg and
  /// stitches the road geometry, distance, and duration. Returns `null` on
  /// failure so the caller seamlessly falls back to OSRM / offline Haversine.
  Future<RouteLegResult?> _fetchCartoLdsRoute(List<LatLng> waypoints) async {
    final baseUrl = CartoConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final token = CartoConfig.accessToken.trim();
    final List<LatLng> stitchedPoints = [];
    double totalMeters = 0.0;
    double totalSeconds = 0.0;

    logSync(
      'Requesting CARTO LDS route for ${waypoints.length} waypoint(s)...',
      tag: 'CARTO_ROUTE',
    );

    try {
      for (int i = 0; i < waypoints.length - 1; i++) {
        final orig = waypoints[i];
        final dest = waypoints[i + 1];
        final uri = Uri.parse('$baseUrl/v3/lds/routing').replace(
          queryParameters: {
            'origin':
                '${orig.longitude.toStringAsFixed(6)},${orig.latitude.toStringAsFixed(6)}',
            'destination':
                '${dest.longitude.toStringAsFixed(6)},${dest.latitude.toStringAsFixed(6)}',
            'mode': CartoConfig.routingMode,
          },
        );

        final response = await _dio.get<dynamic>(
          uri.toString(),
          options: Options(
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            validateStatus: (status) => status != null,
          ),
        );

        if (response.statusCode != 200 || response.data == null) {
          logWarning(
            'CARTO LDS routing returned status ${response.statusCode}; falling back to OSRM.',
            tag: 'CARTO_ROUTE',
          );
          return null;
        }

        final dynamic raw = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;
        final Map<String, dynamic>? legMap = _unwrapCartoRouteObject(raw);
        if (legMap == null) return null;

        final legPoints = _parseCartoGeometry(legMap['geometry'] ?? legMap['geom']);
        if (legPoints.isEmpty) return null;

        if (stitchedPoints.isEmpty) {
          stitchedPoints.addAll(legPoints);
        } else {
          stitchedPoints.addAll(legPoints.skip(1));
        }

        totalMeters +=
            (legMap['distance'] ?? legMap['length'] ?? 0 as num) is num
                ? ((legMap['distance'] ?? legMap['length'] ?? 0) as num)
                    .toDouble()
                : (double.tryParse(
                        '${legMap['distance'] ?? legMap['length'] ?? 0}') ??
                    0.0);
        totalSeconds +=
            (legMap['duration'] ?? legMap['time'] ?? 0 as num) is num
                ? ((legMap['duration'] ?? legMap['time'] ?? 0) as num)
                    .toDouble()
                : (double.tryParse(
                        '${legMap['duration'] ?? legMap['time'] ?? 0}') ??
                    0.0);
      }

      if (stitchedPoints.length >= 2) {
        final distKm = totalMeters / 1000.0;
        final durMins = (totalSeconds / 60.0).ceil();
        logImportant(
          'CARTO LDS route ready: ${distKm.toStringAsFixed(1)} km (~$durMins min, ${stitchedPoints.length} pts)',
          tag: 'CARTO_ROUTE',
        );
        return RouteLegResult(
          points: stitchedPoints,
          distanceKm: distKm,
          durationMinutes: durMins,
          isRoadSnapped: true,
        );
      }
    } catch (e) {
      logWarning(
        'CARTO LDS routing failed ($e); falling back to OSRM.',
        tag: 'CARTO_ROUTE',
      );
    }
    return null;
  }

  Map<String, dynamic>? _unwrapCartoRouteObject(dynamic raw) {
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      if (map['routes'] is List && (map['routes'] as List).isNotEmpty) {
        return Map<String, dynamic>.from((map['routes'] as List).first as Map);
      }
      if (map['features'] is List && (map['features'] as List).isNotEmpty) {
        final feat =
            Map<String, dynamic>.from((map['features'] as List).first as Map);
        final props = feat['properties'] is Map
            ? Map<String, dynamic>.from(feat['properties'] as Map)
            : <String, dynamic>{};
        return {
          ...props,
          'geometry': feat['geometry'],
        };
      }
      if (map['result'] is List && (map['result'] as List).isNotEmpty) {
        return Map<String, dynamic>.from((map['result'] as List).first as Map);
      }
      return map;
    }
    return null;
  }

  List<LatLng> _parseCartoGeometry(dynamic geom) {
    if (geom == null) return const [];
    dynamic parsed = geom;
    if (geom is String) {
      final trimmed = geom.trim();
      if (trimmed.toUpperCase().startsWith('LINESTRING')) {
        final inner = trimmed.replaceFirst(
          RegExp(r'^LINESTRING\s*\(|\)$', caseSensitive: false),
          '',
        );
        final pts = <LatLng>[];
        for (final pair in inner.split(',')) {
          final nums = pair.trim().split(RegExp(r'\s+'));
          if (nums.length >= 2) {
            final lng = double.tryParse(nums[0]);
            final lat = double.tryParse(nums[1]);
            if (lat != null && lng != null) pts.add(LatLng(lat, lng));
          }
        }
        return pts;
      }
      try {
        parsed = jsonDecode(trimmed);
      } catch (_) {
        return const [];
      }
    }

    if (parsed is Map) {
      final type = parsed['type']?.toString();
      final coords = parsed['coordinates'];
      if (type == 'LineString' && coords is List) {
        return _coordsListToLatLng(coords);
      }
      if (type == 'MultiLineString' && coords is List) {
        return [
          for (final line in coords)
            if (line is List) ..._coordsListToLatLng(line),
        ];
      }
    } else if (parsed is List) {
      return _coordsListToLatLng(parsed);
    }
    return const [];
  }

  List<LatLng> _coordsListToLatLng(List<dynamic> coords) {
    final pts = <LatLng>[];
    for (final item in coords) {
      if (item is List && item.length >= 2) {
        final lng = (item[0] as num).toDouble();
        final lat = (item[1] as num).toDouble();
        pts.add(LatLng(lat, lng));
      }
    }
    return pts;
  }

  List<RouteStep> _parseOsrmSteps(List<dynamic>? legs) {
    if (legs == null || legs.isEmpty) return const [];
    final List<RouteStep> parsed = [];
    for (final leg in legs) {
      if (leg is! Map) continue;
      final rawSteps = leg['steps'];
      if (rawSteps is! List) continue;
      for (final rawStep in rawSteps) {
        if (rawStep is! Map) continue;
        final maneuver = rawStep['maneuver'] is Map
            ? Map<String, dynamic>.from(rawStep['maneuver'] as Map)
            : <String, dynamic>{};
        final loc = maneuver['location'];
        if (loc is! List || loc.length < 2) continue;
        final lng = (loc[0] as num).toDouble();
        final lat = (loc[1] as num).toDouble();
        final type = (maneuver['type'] ?? '').toString();
        final modifier = (maneuver['modifier'] ?? '').toString();
        final streetName = (rawStep['name'] ?? '').toString().trim();
        final dist = (rawStep['distance'] as num?)?.toDouble() ?? 0.0;
        final instruction = _formatStepInstruction(
          type: type,
          modifier: modifier,
          streetName: streetName,
        );
        parsed.add(
          RouteStep(
            instruction: instruction,
            distanceMeters: dist,
            maneuverType: type,
            modifier: modifier,
            location: LatLng(lat, lng),
          ),
        );
      }
    }
    return parsed;
  }

  String _formatStepInstruction({
    required String type,
    required String modifier,
    required String streetName,
  }) {
    final cleanMod = modifier.replaceAll('_', ' ').trim();
    final roadSuffix = streetName.isNotEmpty ? ' onto $streetName' : '';
    switch (type) {
      case 'depart':
        return streetName.isNotEmpty
            ? 'Head${cleanMod.isNotEmpty ? ' $cleanMod' : ''} on $streetName'
            : 'Start driving toward destination';
      case 'arrive':
        return 'Arrive at destination';
      case 'turn':
      case 'end of road':
      case 'fork':
      case 'off ramp':
      case 'on ramp':
        final verb = cleanMod.isNotEmpty ? 'Turn $cleanMod' : 'Turn';
        return '$verb$roadSuffix';
      case 'roundabout':
      case 'rotary':
        return 'Take roundabout$roadSuffix';
      case 'continue':
      case 'new name':
        return streetName.isNotEmpty
            ? 'Continue on $streetName'
            : 'Continue straight';
      default:
        return streetName.isNotEmpty
            ? 'Proceed on $streetName'
            : 'Continue straight';
    }
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
