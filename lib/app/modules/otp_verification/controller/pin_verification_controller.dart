import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/modules/login/controller/login_controller.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';

class PinVerificationController extends GetxController {
  final RxString pin = "".obs;
  final RxString confirmPin = "".obs;
  final RxBool isConfirming = false.obs;
  final RxBool isSaving = false.obs;
  static const int pinLength = 6;

  final DatabaseService _dbService = DatabaseService.to;

  String get driverUsername {
    if (Get.isRegistered<LoginController>()) {
      return Get.find<LoginController>().currentDriver?.username ?? '';
    }
    return '';
  }

  /// Appends a digit to pin (Step 1) or confirmPin (Step 2)
  void addDigit(String digit) {
    if (isSaving.value) return;

    if (!isConfirming.value && pin.value.length < pinLength) {
      pin.value += digit;
      if (pin.value.length == pinLength) {
        // First 6 digits entered -> smoothly transition to confirm mode
        Future.delayed(const Duration(milliseconds: 180), () {
          isConfirming.value = true;
        });
      }
    } else if (isConfirming.value && confirmPin.value.length < pinLength) {
      confirmPin.value += digit;
      if (confirmPin.value.length == pinLength) {
        // Confirmation 6 digits entered -> automatically validate
        Future.delayed(const Duration(milliseconds: 180), submitPin);
      }
    }
  }

  /// Deletes the last entered digit
  void deleteDigit() {
    if (isSaving.value) return;

    if (isConfirming.value && confirmPin.value.isNotEmpty) {
      confirmPin.value =
          confirmPin.value.substring(0, confirmPin.value.length - 1);
    } else if (isConfirming.value && confirmPin.value.isEmpty) {
      // Revert back to Step 1 if backspace on empty confirm
      isConfirming.value = false;
    } else if (!isConfirming.value && pin.value.isNotEmpty) {
      pin.value = pin.value.substring(0, pin.value.length - 1);
    }
  }

  /// Reset both PIN values and return to Step 1
  void reset() {
    pin.value = '';
    confirmPin.value = '';
    isConfirming.value = false;
  }

  /// Validate both PINs, update database, and unlock Home
  Future<void> submitPin() async {
    if (isSaving.value) return;

    if (pin.value.length != pinLength ||
        (isConfirming.value && confirmPin.value.length != pinLength)) {
      Get.snackbar(
        'Invalid',
        'Please enter a 6-digit passcode.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFFFEBEB),
        colorText: const Color(0xFFD32F2F),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    if (pin.value != confirmPin.value) {
      Get.snackbar(
        'Mismatch',
        'PINs do not match. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFFFEBEB),
        colorText: const Color(0xFFD32F2F),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2),
      );
      reset();
      return;
    }

    isSaving.value = true;

    try {
      final loginController = Get.find<LoginController>();
      final driver = loginController.currentDriver;
      final username = driver?.username ?? 'SMB0012';

      // 1. Update PIN in SQLite Database
      await _dbService.updateDriverPin(username, pin.value);

      // 2. Resolve Driver ID and authenticate session
      int driverId = driver?.id ?? 1;
      if (driver?.id == null) {
        final found = await _dbService.getDriverByUsername(username);
        if (found?.id != null) driverId = found!.id!;
      }
      await _dbService.setAuthenticatedDriver(driverId);

      // 3. Show success notification
      Get.snackbar(
        'Success',
        'Your passcode has been set!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEFFFEE),
        colorText: const Color(0xFF10B981),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2),
      );

      reset();
      Get.offAllNamed(AppRoutes.home);
    } catch (e) {
      debugPrint('PIN setup error: $e');
      Get.snackbar(
        'Error',
        'An unexpected error occurred. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFFFEBEB),
        colorText: const Color(0xFFD32F2F),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      isSaving.value = false;
    }
  }
}
