import 'package:flutter/material.dart';
import 'package:p_sosyo_driver/app/core/constants/app_constants.dart';

/// Semantic theme extension for P-Sosyo Driver.
@immutable
class PsosyoThemeColors extends ThemeExtension<PsosyoThemeColors> {
  const PsosyoThemeColors({
    required this.primaryPurple,
    required this.lightPurple,
    required this.surface,
    required this.titleGrey,
    required this.bodyGrey,
    required this.darkText,
    required this.accentBlue,
  });

  final Color primaryPurple;
  final Color lightPurple;
  final Color surface;
  final Color titleGrey;
  final Color bodyGrey;
  final Color darkText;
  final Color accentBlue;

  @override
  PsosyoThemeColors copyWith({
    Color? primaryPurple,
    Color? lightPurple,
    Color? surface,
    Color? titleGrey,
    Color? bodyGrey,
    Color? darkText,
    Color? accentBlue,
  }) {
    return PsosyoThemeColors(
      primaryPurple: primaryPurple ?? this.primaryPurple,
      lightPurple: lightPurple ?? this.lightPurple,
      surface: surface ?? this.surface,
      titleGrey: titleGrey ?? this.titleGrey,
      bodyGrey: bodyGrey ?? this.bodyGrey,
      darkText: darkText ?? this.darkText,
      accentBlue: accentBlue ?? this.accentBlue,
    );
  }

  @override
  PsosyoThemeColors lerp(ThemeExtension<PsosyoThemeColors>? other, double t) {
    if (other is! PsosyoThemeColors) return this;

    return PsosyoThemeColors(
      primaryPurple:
          Color.lerp(primaryPurple, other.primaryPurple, t) ?? primaryPurple,
      lightPurple: Color.lerp(lightPurple, other.lightPurple, t) ?? lightPurple,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      titleGrey: Color.lerp(titleGrey, other.titleGrey, t) ?? titleGrey,
      bodyGrey: Color.lerp(bodyGrey, other.bodyGrey, t) ?? bodyGrey,
      darkText: Color.lerp(darkText, other.darkText, t) ?? darkText,
      accentBlue: Color.lerp(accentBlue, other.accentBlue, t) ?? accentBlue,
    );
  }
}

/// Core color tokens — Cobalt & Sky Logistics Palette.
class AppColors {
  static const Color primary = AppConstants.primaryColor;
  static const Color secondary = AppConstants.secondaryColor;
  static const Color primaryPressed = AppConstants.secondaryColor;
  static const Color primaryTint = Color(0xFFEEF4FF);
  static const Color primaryBorder = Color(0xFFCCDEFF);

  static const Color subPrimary = AppConstants.mintAccentColor;
  static const Color mint = AppConstants.mintAccentColor;
  static const Color mintDeep = Color(0xFF0A8754);

  // Canvas & structural surfaces
  static const Color canvas = Color(0xFFF5F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEAF0FA);
  static const Color surfaceDark = Color(0xFF0E1B4D);
  static const Color surfaceDarkElevated = Color(0xFF16286B);
  static const Color surfaceDarkBorder = Color(0xFF263E8F);

  // Ink hierarchy (high contrast for daylight field visibility)
  static const Color inkPrimary = Color(0xFF141824);
  static const Color inkSecondary = Color(0xFF474E63);
  static const Color inkMuted = Color(0xFF70778C);
  static const Color inkSubtle = Color(0xFF9EA4B8);

  // Hairlines & subtle card borders
  static const Color border = Color(0xFFE1E6F0);
  static const Color borderStrong = Color(0xFFC5CEE0);

  // Semantic statuses
  static const Color success = Color(0xFF0A8754);
  static const Color successTint = Color(0xFFE8F8F0);
  static const Color successBorder = Color(0xFFB5E6CD);

  static const Color warning = Color(0xFFB45309);
  static const Color warningTint = Color(0xFFFEF3C7);
  static const Color warningBorder = Color(0xFFFDE68A);

  static const Color danger = Color(0xFFC81E1E);
  static const Color dangerTint = Color(0xFFFEECEC);
  static const Color dangerBorder = Color(0xFFF7C4C4);

  static const PsosyoThemeColors psosyo = PsosyoThemeColors(
    primaryPurple: AppConstants.primaryColor,
    lightPurple: Color(0xFFEEF4FF),
    surface: Color(0xFFF5F7FB),
    titleGrey: Color(0xFF70778C),
    bodyGrey: Color(0xFF474E63),
    darkText: Color(0xFF141824),
    accentBlue: AppConstants.secondaryColor,
  );

  static const Color buttonBackground = primary;
  static const Color buttonText = Colors.white;
}

class ThemeColors {
  static const Color primary = AppColors.primary;
  static const Color subPrimary = AppColors.subPrimary;
}

/// Spacing & radius tokens for consistent composition across screens.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class AppRadii {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 22;
  static const double sheet = 28;
  static const double pill = 999;
}

/// Poppins typography tokens calibrated for the app's global 0.7 TextScaler.
class AppTypography {
  static const String fontFamily = 'Poppins';
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const TextStyle eyebrow = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.9,
    color: AppColors.inkMuted,
  );

  static const TextStyle micro = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: AppColors.inkMuted,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.inkMuted,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 19,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.inkSecondary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 19,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.inkPrimary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: AppColors.inkPrimary,
  );

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.2,
    color: AppColors.inkPrimary,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 25,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.3,
    color: AppColors.inkPrimary,
  );

  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 33,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.5,
    color: AppColors.inkPrimary,
  );

  static const TextStyle metric = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.4,
    fontFeatures: tabular,
    color: AppColors.inkPrimary,
  );

  static const TextStyle heroMetric = TextStyle(
    fontFamily: fontFamily,
    fontSize: 38,
    fontWeight: FontWeight.w700,
    height: 1.05,
    letterSpacing: -0.6,
    fontFeatures: tabular,
    color: AppColors.inkPrimary,
  );

  static const TextStyle monoRef = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.35,
    fontFeatures: tabular,
    color: AppColors.inkSecondary,
  );
}

class AppThemes {
  static final ThemeData lightTheme = ThemeData(
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: AppColors.canvas,
    dividerColor: AppColors.border,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.canvas,
    ).copyWith(
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),
    extensions: const <ThemeExtension<dynamic>>[
      AppColors.psosyo,
    ],
  );

  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.buttonBackground,
    foregroundColor: AppColors.buttonText,
    elevation: 0,
    shadowColor: Colors.transparent,
    textStyle: const TextStyle(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      fontFamily: 'Poppins',
      fontSize: 21,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
    ),
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
    minimumSize: const Size(0, 56),
  );

  static final ButtonStyle unaccessibleButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.surfaceMuted,
    foregroundColor: AppColors.inkSubtle,
    elevation: 0,
    shadowColor: Colors.transparent,
    textStyle: const TextStyle(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      fontFamily: 'Poppins',
      fontSize: 21,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
    ),
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
    minimumSize: const Size(0, 56),
  );
}
