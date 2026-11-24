import 'package:flutter/material.dart';

/// Application-wide design, brand, asset, and UI constants.
class AppConstants {
  AppConstants._();

  // App Identity
  static const String appName = 'PAQNER';
  static const double globalTextScale = 0.7;

  // Brand Colors
  static const Color primaryColor = Color(0xFF5C95FE);
  static const Color secondaryColor = Color(0xFF1839DD);
  static const Color mintAccentColor = Color(0xFF74E1AE);

  // Asset Paths
  static const String appBarLogoAsset = 'assets/icons/appbar_logo.svg';
  static const String paqnerLogoAsset = 'assets/icons/paqner_logo.svg';
  static const String resyncIconAsset = 'assets/icons/resync-icon.svg';
  static const String endOfDayIconAsset = 'assets/icons/endofday_icon.svg';
  static const String dateIconAsset = 'assets/icons/date-icon.svg';
  static const String skuIconAsset = 'assets/icons/sku-icon.svg';

  static const String loginLogoAsset = 'assets/images/psosyo_login_logo.png';
  static const String driverLogoAsset = 'assets/images/psosyo_driver_logo.png';
  static const String backgroundAsset = 'assets/images/psosyo_background.png';
  static const String shopThumbnailAsset = 'assets/images/shop_thumbnail.png';
  static const String truck3dAsset = 'assets/images/truck_3d.png';

  // Durations
  static const Duration adminHoldDuration = Duration(milliseconds: 1500);
}

/// Global transaction status constants (`transtat`).
///
/// Matches the Ravamate / SFAplus transaction status convention:
/// - `0` = success
/// - `1` = failed
/// - `2` = pending
class TranStat {
  TranStat._();

  static const int success = 0;
  static const int failed = 1;
  static const int pending = 2;

  static String label(int status) {
    switch (status) {
      case success:
        return 'Success';
      case failed:
        return 'Failed';
      case pending:
      default:
        return 'Pending';
    }
  }
}
