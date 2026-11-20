import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String defaultHost = 'api.ravamate.com/RAVAMATE_SANDBOX';
  static const String defaultDistCode = 'SANDBOX01';
  static const String defaultDriverCode = 'SBRM007';
  static const String defaultSalesmanCode = 'DRP1';
  static const String defaultCompanyName = 'PD8 SANDBOX';

  static const String keyHost = 'server_host';
  static const String keyDistCode = 'server_dist_code';
  static const String keyDriverCode = 'driver_md_code';
  static const String keySalesmanCode = 'driver_salesman_code';
  static const String keyCompanyName = 'server_company_name';

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
    return prefs.getString(keyDriverCode) ?? defaultDriverCode;
  }

  static Future<void> setDriverCode(String driverCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyDriverCode, driverCode);
  }

  static Future<String> getSalesmanCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keySalesmanCode) ?? defaultSalesmanCode;
  }

  static Future<void> setSalesmanCode(String salesmanCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keySalesmanCode, salesmanCode);
  }

  static Future<String> getCompanyName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyCompanyName) ?? defaultCompanyName;
  }

  static Future<void> setCompanyName(String companyName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyCompanyName, companyName);
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
      logSync('[GET] ${dio.options.baseUrl}$endpointWithQuery', tag: 'API HTTP');
      final response = await dio.get<String>(
        endpointWithQuery,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = (response.data ?? '').replaceFirst('\uFEFF', '').trim();
        if (raw.isEmpty) return [];

        dynamic decoded = _tryDecodeJson(raw);
        if (decoded == null) {
          final preview = raw.length > 250 ? '${raw.substring(0, 250)}...' : raw;
          logWarning(
            '[ApiClient Non-JSON Response] on $endpointWithQuery -> $preview',
            tag: 'API HTTP',
          );
          return [];
        }

        if (decoded is List) {
          return List<Map<dynamic, dynamic>>.from(decoded);
        } else if (decoded is Map &&
            decoded.containsKey('data') &&
            decoded['data'] is List) {
          return List<Map<dynamic, dynamic>>.from(decoded['data'] as List);
        }
      }
      logWarning('[ApiClient Response] Status: ${response.statusCode}, Data: ${response.data}');
      return [];
    } catch (e) {
      logError('ApiClient HTTP Error on $endpointWithQuery', e);
      return [];
    }
  }

  static dynamic _tryDecodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      // Recover if backend prepended a PHP notice/warning before JSON array/object
      final listStart = raw.indexOf('[');
      final mapStart = raw.indexOf('{');
      int start = -1;
      String endChar = ']';
      if (listStart != -1 && (mapStart == -1 || listStart < mapStart)) {
        start = listStart;
        endChar = ']';
      } else if (mapStart != -1) {
        start = mapStart;
        endChar = '}';
      }
      if (start != -1) {
        final end = raw.lastIndexOf(endChar);
        if (end > start) {
          try {
            return jsonDecode(raw.substring(start, end + 1));
          } catch (_) {}
        }
      }
      return null;
    }
  }

  static Future<Map<String, dynamic>?> verifyDriver(
    String username,
    String password,
  ) async {
    final distCode = await getDistCode();

    // 1. Direct query with entered password
    var results = await getList(
      'login?distCode=$distCode&mdCode=$username&mdpassword=$password',
    );

    // 2. Fallback for hardcoded developer password '123' -> checks 'k1m123'
    if (results.isEmpty && (password == '123' || password == 'k1m123')) {
      final altPassword = password == '123' ? 'k1m123' : '123';
      results = await getList(
        'login?distCode=$distCode&mdCode=$username&mdpassword=$altPassword',
      );
    }

    if (results.isNotEmpty) {
      final first = Map<String, dynamic>.from(results.first);
      final sc = (first['mdSalesmancode'] ?? first['salesmanCode'] ?? '').toString().trim();
      if (sc.isNotEmpty) {
        await setSalesmanCode(sc);
      }
      final company = (first['companyName'] ?? first['company'] ?? '').toString().trim();
      if (company.isNotEmpty) {
        await setCompanyName(company);
      }
      return first;
    }
    return null;
  }
}
