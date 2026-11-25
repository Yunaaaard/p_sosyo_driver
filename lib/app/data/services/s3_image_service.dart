import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart' as dio;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:p_sosyo_driver/app/core/constants/s3_config.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/data/providers/api_client.dart';

/// Result wrapper for S3 image upload operations (modeled after SFAplus).
class S3UploadResult {
  final bool isSuccess;
  final String? url;
  final String? message;

  const S3UploadResult({
    required this.isSuccess,
    this.url,
    this.message,
  });

  factory S3UploadResult.success(String url) => S3UploadResult(
        isSuccess: true,
        url: url,
      );

  factory S3UploadResult.failure(String message) => S3UploadResult(
        isSuccess: false,
        message: message,
      );
}

/// S3 Image Service modeled after SFAplus / RavaMate.
///
/// Ensures all uploaded images (PNG, WebP, HEIC, or large camera photos)
/// are converted to `.jpg` (JPEG) and resized/compressed under 5 MB before
/// uploading via `multipart/form-data`.
class S3ImageService extends GetxService {
  static S3ImageService get to => Get.isRegistered<S3ImageService>()
      ? Get.find<S3ImageService>()
      : Get.put(S3ImageService());

  static const int maxFileSizeBytes = 5 * 1024 * 1024;
  static const int maxWidth = 1205;
  static const int maxHeight = 1795;
  static const String _tokenKey = 's3_upload_token';
  static const String _tokenExpiryKey = 's3_token_expiration';

  /// Fetches and caches the S3 Bearer token from `GET /api/get-token`,
  /// matching SFAplus's `UserDbHelper.getS3Token`.
  Future<String> getS3Token({
    bool refresh = false,
    String? principal,
    String? overrideToken,
  }) async {
    final staticOverride = (overrideToken ?? S3Config.bearerToken).trim();
    if (staticOverride.isNotEmpty && !refresh) {
      return staticOverride;
    }

    final prefs = await SharedPreferences.getInstance();
    var cachedToken = prefs.getString(_tokenKey) ?? '';
    final expirationDate = prefs.getString(_tokenExpiryKey);

    if (expirationDate != null && expirationDate.isNotEmpty) {
      final parsedExpiry = DateTime.tryParse(expirationDate) ??
          _tryParseS3Expiry(expirationDate);
      if (parsedExpiry != null && parsedExpiry.isBefore(DateTime.now())) {
        await prefs.setString(_tokenKey, '');
        cachedToken = '';
      }
    }

    if (cachedToken.isNotEmpty && !refresh) {
      return cachedToken;
    }

    try {
      final host = S3Config.uploadHost.replaceAll(RegExp(r'/+$'), '');
      final url = Uri.parse('$host${S3Config.getTokenPath}').replace(
        queryParameters: {'principal': principal ?? S3Config.principal},
      );
      logSync('Fetching S3 upload token: $url', tag: 'S3_TOKEN');

      final dioClient = dio.Dio();
      final response = await dioClient.get<String>(
        url.toString(),
        options: dio.Options(
          responseType: dio.ResponseType.plain,
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) => status != null,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.data ?? '{}');
        final records = decoded is List
            ? decoded
            : decoded is Map<String, dynamic> && decoded['data'] is List
                ? decoded['data'] as List
                : [decoded];
        if (records.isNotEmpty && records.first is Map) {
          final first = records.first as Map;
          final token = first['token']?.toString().trim() ?? '';
          final tokenExpiry = first['tokenExpiry']?.toString().trim() ?? '';
          if (token.isNotEmpty && token != 'null') {
            await prefs.setString(_tokenKey, token);
            if (tokenExpiry.isNotEmpty && tokenExpiry != 'null') {
              await prefs.setString(_tokenExpiryKey, tokenExpiry);
            }
            logImportant('Fetched & cached S3 upload token', tag: 'S3_TOKEN');
            return token;
          }
        }
      }
      logWarning(
        'Failed to fetch S3 token (status: ${response.statusCode})',
        tag: 'S3_TOKEN',
      );
    } catch (e, stack) {
      logError('Error fetching S3 token', e, stack);
    }

    return cachedToken;
  }

  DateTime? _tryParseS3Expiry(String raw) {
    return DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
  }

  /// Ensures [bytes] are encoded as JPEG (`.jpg`), converting PNG/other formats
  /// and resizing images larger than 1205x1795.
  Future<Uint8List> ensureJpegBytes(Uint8List bytes) async {
    final bool isJpeg = bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      final originalImage = frameInfo.image;
      final bool needsResize =
          originalImage.width > maxWidth || originalImage.height > maxHeight;

      if (isJpeg && !needsResize) {
        return bytes;
      }

      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: needsResize ? maxWidth : originalImage.width,
        minHeight: needsResize ? maxHeight : originalImage.height,
        quality: needsResize ? 75 : 90,
        format: CompressFormat.jpeg,
      );

      if (compressed.isNotEmpty) {
        logSync(
          'S3 image ${!isJpeg ? 'converted to JPG' : 'resized'}: '
          '${(bytes.lengthInBytes / 1024).toStringAsFixed(1)}KB -> '
          '${(compressed.lengthInBytes / 1024).toStringAsFixed(1)}KB',
          tag: 'S3_UPLOAD',
        );
        return compressed;
      }
    } catch (e, stack) {
      logError('S3 JPEG conversion/resize failed', e, stack);
    }
    return bytes;
  }

  /// Reads an image file from disk, ensures it is `.jpg`, and uploads it to S3.
  Future<S3UploadResult> uploadFilePath({
    required String filePath,
    required String baseFolder,
    String? customFilename,
    String? principal,
    String? bearerToken,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return S3UploadResult.failure('Local image file not found: $filePath');
    }
    final bytes = await file.readAsBytes();
    return uploadImage(
      imageBytes: bytes,
      baseFolder: baseFolder,
      customFilename: customFilename,
      principal: principal,
      bearerToken: bearerToken,
    );
  }

  /// Uploads raw [imageBytes] to S3 as `.jpg`.
  Future<S3UploadResult> uploadImage({
    required Uint8List? imageBytes,
    required String baseFolder,
    String? customFilename,
    String? principal,
    String? bearerToken,
  }) async {
    if (imageBytes == null || imageBytes.isEmpty) {
      return S3UploadResult.failure('No image selected.');
    }

    final jpegBytes = await ensureJpegBytes(imageBytes);
    if (jpegBytes.lengthInBytes > maxFileSizeBytes) {
      final sizeInMb =
          (jpegBytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(2);
      return S3UploadResult.failure(
        'Image is too large (${sizeInMb}MB). Maximum allowed size is 5MB.',
      );
    }

    final result = await _attemptUpload(
      imageBytes: jpegBytes,
      baseFolder: baseFolder,
      customFilename: customFilename,
      principal: principal ?? S3Config.principal,
      bearerToken: bearerToken,
      forceRefreshToken: false,
    );

    if (!result.isSuccess &&
        result.message != null &&
        result.message!.contains('Status: 401')) {
      logWarning('S3 upload got 401 — refreshing token and retrying...',
          tag: 'S3_UPLOAD');
      return _attemptUpload(
        imageBytes: jpegBytes,
        baseFolder: baseFolder,
        customFilename: customFilename,
        principal: principal ?? S3Config.principal,
        bearerToken: bearerToken,
        forceRefreshToken: true,
      );
    }

    return result;
  }

  Future<S3UploadResult> _attemptUpload({
    required Uint8List imageBytes,
    required String baseFolder,
    String? customFilename,
    required String principal,
    String? bearerToken,
    bool forceRefreshToken = false,
  }) async {
    try {
      final distCode = await ApiClient.getDistCode();
      final token = await getS3Token(
        refresh: forceRefreshToken,
        principal: principal,
        overrideToken: bearerToken,
      );
      if (token.isEmpty) {
        logWarning(
          'S3 bearerToken unavailable from get-token / S3Config.',
          tag: 'S3_UPLOAD',
        );
        return S3UploadResult.failure(
          'S3 upload token unavailable.',
        );
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = (customFilename ?? 'pod-$distCode-$timestamp')
          .replaceAll(RegExp(r'\.(png|jpe?g|webp)$', caseSensitive: false), '');

      final host = S3Config.uploadHost.replaceAll(RegExp(r'/+$'), '');
      final url = Uri.parse('$host${S3Config.uploadApiPath}').replace(
        queryParameters: {'principal': principal},
      );
      final fetchHost = S3Config.publicFetchHost.replaceAll(RegExp(r'/+$'), '');
      final fullPublicUrl =
          '$fetchHost/$baseFolder/$principal/$distCode/$filename.jpg';

      final sizeKb = (imageBytes.lengthInBytes / 1024).toStringAsFixed(1);
      logSync(
        'Uploading JPG to S3: $url (baseFolder: $baseFolder, filename: $filename.jpg, size: ${sizeKb}KB)',
        tag: 'S3_UPLOAD',
      );
      logInfo(fullPublicUrl, tag: 'S3_FULL_PATH');

      final formData = dio.FormData.fromMap({
        'image': dio.MultipartFile.fromBytes(
          imageBytes,
          filename: '$filename.jpg',
          contentType: dio.DioMediaType.parse('image/jpeg'),
        ),
        'filename': filename,
        'base_folder': baseFolder,
        'principal': principal,
        'distcode': distCode,
      });

      final dioClient = dio.Dio();
      final response = await dioClient.post(
        url.toString(),
        data: formData,
        options: dio.Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
          validateStatus: (status) => status != null,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> json = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : jsonDecode(response.data.toString()) as Map<String, dynamic>;

        if (json['success'] == true &&
            json['data'] != null &&
            json['data']['url'] != null) {
          final uploadedUrl = json['data']['url'].toString();
          logImportant('S3 POD upload success! Copy-paste URL(s):', tag: 'S3_UPLOAD');
          logInfo(fullPublicUrl, tag: 'S3_PUBLIC_URL');
          logInfo(uploadedUrl, tag: 'S3_API_URL');
          return S3UploadResult.success(uploadedUrl);
        }

        return S3UploadResult.failure(
          json['message']?.toString() ?? 'S3 upload failed.',
        );
      }

      return S3UploadResult.failure(
        'S3 upload failed (Status: ${response.statusCode})',
      );
    } on dio.DioException catch (e, stack) {
      logError('S3 DioException during upload', e, stack);
      if (e.type == dio.DioExceptionType.connectionTimeout ||
          e.type == dio.DioExceptionType.sendTimeout ||
          e.type == dio.DioExceptionType.receiveTimeout) {
        return S3UploadResult.failure('S3 upload timed out.');
      }
      if (e.type == dio.DioExceptionType.connectionError) {
        return S3UploadResult.failure('No network connection for S3 upload.');
      }
      return S3UploadResult.failure('S3 upload error: ${e.message}');
    } catch (e, stack) {
      logError('Unexpected error during S3 upload', e, stack);
      return S3UploadResult.failure('Unexpected S3 upload error: $e');
    }
  }
}
