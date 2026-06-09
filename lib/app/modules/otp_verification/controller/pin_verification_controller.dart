import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/modules/login/controller/login_controller.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';

class PinVerificationController extends GetxController {
  final RxString pin = "".obs;
  final RxBool isVerifying = false.obs;
  static const int pinLength = 6;

  final DatabaseService _dbService = DatabaseService.to;

  void addDigit(String digit) {
    if (pin.value.length < pinLength) {
      pin.value += digit;
    }
  }

  void deleteDigit() {
    if (pin.value.isNotEmpty) {
      pin.value = pin.value.substring(0, pin.value.length - 1);
    }
  }

  /// Verify the entered PIN against the database.
  Future<void> submitPin() async {
    if (pin.value.length != pinLength) {
      Get.snackbar(
        'Invalid PIN',
        'Please enter a 6-digit PIN code.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFFFEBEB),
        colorText: const Color(0xFFD32F2F),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    isVerifying.value = true;

    try {
      // Get the currently logged-in driver's username from LoginController
      final loginController = Get.find<LoginController>();
      final driver = loginController.currentDriver;

      if (driver == null) {
        // Fallback: should not happen, but handle gracefully
        Get.snackbar(
          'Error',
          'Session expired. Please log in again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFFFEBEB),
          colorText: const Color(0xFFD32F2F),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return;
      }

      final isValid = await _dbService.verifyPin(driver.username, pin.value);

      if (isValid) {
        await _dbService.setAuthenticatedDriver(driver.id!);
        Get.offAllNamed(AppRoutes.home);
      } else {
        pin.value = ''; // Clear the PIN on failure
        Get.snackbar(
          'Incorrect PIN',
          'The PIN you entered is incorrect. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFFFEBEB),
          colorText: const Color(0xFFD32F2F),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      debugPrint('PIN verification error: $e');
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
      isVerifying.value = false;
    }
  }
}
