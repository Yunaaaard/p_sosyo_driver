/// S3 Image Service configuration placeholders.
///
/// TODO: Replace the placeholder values below with your production/staging
/// S3 host, folder names, principal, and Bearer token (or token provider).
class S3Config {
  S3Config._();

  /// TODO: Provide your S3 image upload host (no trailing slash).
  static const String uploadHost =
      'https://s3.image.fastdistributiongroup.biz';

  /// Public Vultr/S3 fetch base URL for constructed object paths.
  static const String publicFetchHost =
      'https://filezsystem.sgp1.vultrobjects.com';

  /// TODO: Provide your S3 image upload API path.
  static const String uploadApiPath = '/api/s3-image';

  /// S3 token endpoint path (matches SFAplus `UserDbHelper.getS3Token`).
  static const String getTokenPath = '/api/get-token';

  /// TODO: Provide your S3 base folder for Proof of Delivery (POD) photos.
  static const String podBaseFolder = 'PODIMAGEIMAGE';

  /// TODO: Provide your S3 principal query parameter.
  static const String principal = 'NPI';

  /// Optional static Bearer token override. When empty, `S3ImageService.getS3Token()`
  /// automatically fetches and caches a token from `GET <uploadHost>/api/get-token`.
  static const String bearerToken = '';
}
