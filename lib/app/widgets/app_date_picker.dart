import 'package:flutter/material.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';

/// Displays a branded, Poppins-styled Material date picker aligned with
/// the app's design tokens (`AppColors`, `AppRadii`, `AppTypography`).
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  String? confirmText,
}) {
  final safeInitial = initialDate.isBefore(firstDate)
      ? firstDate
      : (initialDate.isAfter(lastDate) ? lastDate : initialDate);

  return showDatePicker(
    context: context,
    initialDate: safeInitial,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText ?? 'SELECT RESCHEDULE DATE',
    confirmText: confirmText ?? 'Confirm Date',
    cancelText: 'Cancel',
    builder: (ctx, child) {
      final base = Theme.of(ctx);
      return Theme(
        data: base.copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.inkPrimary,
            secondary: AppColors.primaryTint,
            onSecondary: AppColors.primary,
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              side: const BorderSide(color: AppColors.border),
            ),
            headerBackgroundColor: AppColors.surfaceDark,
            headerForegroundColor: Colors.white,
            headerHelpStyle: AppTypography.monoRef.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Colors.white70,
            ),
            headerHeadlineStyle: AppTypography.title.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            weekdayStyle: AppTypography.monoRef.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.inkMuted,
            ),
            dayStyle: AppTypography.body.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            yearStyle: AppTypography.label.copyWith(fontSize: 15),
            todayBorder: const BorderSide(
              color: AppColors.primary,
              width: 1.5,
            ),
            todayForegroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return Colors.white;
              return AppColors.primary;
            }),
            dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.primary;
              }
              return null;
            }),
            dayForegroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return Colors.white;
              if (states.contains(WidgetState.disabled)) {
                return AppColors.inkMuted.withOpacity(0.45);
              }
              return AppColors.inkPrimary;
            }),
            dividerColor: AppColors.border,
            confirmButtonStyle: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              textStyle: AppTypography.label.copyWith(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            cancelButtonStyle: TextButton.styleFrom(
              foregroundColor: AppColors.inkSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: AppTypography.label.copyWith(
                fontSize: 14,
                color: AppColors.inkSecondary,
              ),
            ),
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}
