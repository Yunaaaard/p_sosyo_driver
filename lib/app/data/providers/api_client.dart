import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String defaultHost = 'fastdevs-api.com';
  static const String defaultDistCode = 'PDB';

  static const String keyHost = 'server_host';
  static const String keyDistCode = 'server_dist_code';
  static const String keyDriverCode = 'driver_md_code';

  static Dio? _dio;

  static Future<String> getHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyHost) ?? defaultHost;
  }

  static Future<void> setHost(String host) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyHost, host);
    _dio = null; // Re-create on host change
  }

  static Future<String> getDistCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyDistCode) ?? defaultDistCode;
  }

  static Future<void> setDistCode(String distCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyDistCode, distCode);
  }

  static Future<String> getDriverCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyDriverCode) ?? 'SMB0012';
  }

  static Future<void> setDriverCode(String driverCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyDriverCode, driverCode);
  }

  static Future<Dio> getDio({
    Duration receiveTimeout = const Duration(minutes: 2),
    Duration sendTimeout = const Duration(seconds: 15),
  }) async {
    if (_dio != null) return _dio!;

    final host = await getHost();
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://$host/MYBUDDY_FTR/api/index.php/',
        connectTimeout: receiveTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
        validateStatus: (_) => true,
      ),
    );

    // Support self-signed or internal certificates (matching RavaMate setup)
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
        return client;
      },
    );

    _dio = dio;
    return dio;
  }

  static Future<List<Map<dynamic, dynamic>>> getList(String endpointWithQuery) async {
    try {
      final dio = await getDio();
      debugPrint('[ApiClient GET] ${dio.options.baseUrl}$endpointWithQuery');
      final response = await dio.get(endpointWithQuery);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is List) {
          return List<Map<dynamic, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('data') && data['data'] is List) {
          return List<Map<dynamic, dynamic>>.from(data['data']);
        }
      }
      debugPrint('[ApiClient Response] Status: ${response.statusCode}, Data: ${response.data}');
      return [];
    } catch (e) {
      debugPrint('[ApiClient Error] $e');
      return [];
    }
  }
}

