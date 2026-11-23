import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';

class DriverCoordinates {
  final double latitude;
  final double longitude;

  const DriverCoordinates({
    required this.latitude,
    required this.longitude,
  });
}

class LocationHelper {
  LocationHelper._();

  static const MethodChannel _channel =
      MethodChannel('com.example.p_sosyo_driver/location');

  /// Default hub coordinates (Mandaue / Cebu dispatch hub) used when
  /// device GPS is unavailable or before native channel initialization.
  static const double defaultDriverLat = 10.369075;
  static const double defaultDriverLng = 123.925618;

  /// Starts real-time GPS location updates on the native Android layer.
  static Future<bool> startLocationUpdates() async {
    try {
      final started = await _channel
          .invokeMethod<bool>('startLocationUpdates')
          .timeout(const Duration(seconds: 2));
      return started ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Query the device GPS location via native channel, falling back cleanly
  /// to [defaultDriverLat] / [defaultDriverLng].
  static Future<DriverCoordinates> getCurrentDriverLocation() async {
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('getCurrentLocation')
          .timeout(const Duration(seconds: 2));
      if (result != null) {
        final lat = (result['latitude'] as num?)?.toDouble();
        final lng = (result['longitude'] as num?)?.toDouble();
        if (isValidCoordinate(lat, lng)) {
          return DriverCoordinates(latitude: lat!, longitude: lng!);
        }
      }
    } catch (_) {
      // Fallback to default dispatch coordinates when channel is unavailable
    }
    return const DriverCoordinates(
      latitude: defaultDriverLat,
      longitude: defaultDriverLng,
    );
  }

  /// Check whether a latitude/longitude pair represents a real terrestrial coordinate.
  static bool isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lng.isNaN) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    if (lat.abs() > 90.0 || lng.abs() > 180.0) return false;
    return true;
  }

  /// Haversine distance in kilometers between two (lat, lng) coordinates.
  static double calculateDistanceKm({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _degToRad(endLat - startLat);
    final double dLng = _degToRad(endLng - startLng);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(startLat)) *
            math.cos(_degToRad(endLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final double distance = earthRadiusKm * c;
    return distance < 0 ? 0.0 : distance;
  }

  /// Format a kilometer value as e.g. `"12.6KM away"`.
  static String formatDistanceKmAway(double km) {
    return '${km.toStringAsFixed(1)}KM away';
  }

  /// Format latitude and longitude for display on delivery cards.
  static String formatLatLong(double? lat, double? lng) {
    if (!isValidCoordinate(lat, lng)) return '';
    return '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}';
  }

  /// If a sandbox customer record is missing valid GPS coordinates (`null`, `0`, or `9999`),
  /// derive a deterministic store coordinate around the dispatch area so distance
  /// calculation and nearest-to-farthest sorting work consistently for every order.
  static DriverCoordinates resolveOrderCoordinates({
    required String seedKey,
    double? rawLat,
    double? rawLng,
  }) {
    if (isValidCoordinate(rawLat, rawLng)) {
      return DriverCoordinates(latitude: rawLat!, longitude: rawLng!);
    }

    int hash = 0;
    for (int i = 0; i < seedKey.length; i++) {
      hash = ((hash * 31) + seedKey.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    if (hash == 0) hash = 137;

    // Spread deterministic fallback offsets between ~1.2 KM and ~18.5 KM
    final double angle = (hash % 360) * (math.pi / 180.0);
    final double radiusKm = 1.2 + ((hash % 173) / 10.0); // 1.2 .. 18.5 km
    final double latOffset = (radiusKm / 111.0) * math.cos(angle);
    final double lngOffset = (radiusKm / 109.0) * math.sin(angle);

    return DriverCoordinates(
      latitude:
          double.parse((defaultDriverLat + latOffset).toStringAsFixed(6)),
      longitude:
          double.parse((defaultDriverLng + lngOffset).toStringAsFixed(6)),
    );
  }

  /// Launch Google Maps turn-by-turn directions from the driver's current
  /// location to the target delivery coordinates.
  static Future<bool> openGoogleMapsDirections({
    required double destLat,
    required double destLng,
    double? originLat,
    double? originLng,
    String? storeName,
  }) async {
    double startLat = originLat ?? defaultDriverLat;
    double startLng = originLng ?? defaultDriverLng;

    if (!isValidCoordinate(originLat, originLng)) {
      final current = await getCurrentDriverLocation();
      startLat = current.latitude;
      startLng = current.longitude;
    }

    logImportant(
      'Opening Google Maps navigation to ${storeName ?? "Store"}: ($startLat, $startLng) -> ($destLat, $destLng)',
      tag: 'MAPS',
    );

    try {
      final launched = await _channel.invokeMethod<bool>(
        'openMapsDirections',
        <String, dynamic>{
          'originLat': startLat,
          'originLng': startLng,
          'destLat': destLat,
          'destLng': destLng,
          'storeName': storeName ?? '',
        },
      );
      return launched ?? false;
    } on MissingPluginException {
      logWarning(
        'Native location channel not registered yet — stop the app and run a full "flutter run" so MainActivity.kt is compiled.',
        tag: 'MAPS',
      );
      return false;
    } catch (e, stack) {
      logError('Failed to launch Google Maps directions', e, stack);
      return false;
    }
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}
