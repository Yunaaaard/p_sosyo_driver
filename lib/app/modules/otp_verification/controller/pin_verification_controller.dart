import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/data/models/driver.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/modules/login/controller/login_controller.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';

class PinVerificationController extends GetxController {
  final RxString pin = "".obs;
  final RxString confirmPin = "".obs;
  final RxBool isConfirming = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isInputLocked = false.obs;
  final RxBool isVerifyMode = false.obs;
  static const int pinLength = 6;

  final DatabaseService _dbService = DatabaseService.to;
  Driver? _authenticatedDriver;

  @override
  void onInit() {
    super.onInit();
    _initMode();
  }

  Future<void> _initMode() async {
    final hasLoginDriver = Get.isRegistered<LoginController>() &&
        Get.find<LoginController>().currentDriver != null;
    if (hasLoginDriver) {
      isVerifyMode.value = false;
      return;
    }

    final authDriver = await _dbService.getAuthenticatedDriver();
    _authenticatedDriver = authDriver;
    if (authDriver != null && authDriver.pin.trim().isNotEmpty) {
      isVerifyMode.value = true;
    }
  }

  String get driverUsername {
    if (Get.isRegistered<LoginController>()) {
      final loginUser = Get.find<LoginController>().currentDriver?.username;
      if (loginUser != null && loginUser.isNotEmpty) return loginUser;
    }
    return _authenticatedDriver?.username ?? '';
  }

  /// Appends a digit to pin (Step 1 / Verify) or confirmPin (Step 2)
  void addDigit(String digit) {
    if (isSaving.value || isInputLocked.value) return;

    if (isVerifyMode.value) {
      if (pin.value.length < pinLength) {
        pin.value += digit;
        if (pin.value.length == pinLength) {
          isInputLocked.value = true;
          Future.delayed(const Duration(milliseconds: 150), verifyExistingPin);
        }
      }
      return;
    }

    if (!isConfirming.value && pin.value.length < pinLength) {
      pin.value += digit;
      if (pin.value.length == pinLength) {
        isInputLocked.value = true;
        // First 6 digits entered -> smoothly transition to confirm mode
        Future.delayed(const Duration(milliseconds: 180), () {
          isConfirming.value = true;
          isInputLocked.value = false;
        });
      }
    } else if (isConfirming.value && confirmPin.value.length < pinLength) {
      confirmPin.value += digit;
      if (confirmPin.value.length == pinLength) {
        isInputLocked.value = true;
        // Confirmation 6 digits entered -> automatically validate
        Future.delayed(const Duration(milliseconds: 180), submitPin);
      }
    }
  }

  /// Verifies the entered 6-digit passcode against the authenticated driver's PIN.
  Future<void> verifyExistingPin() async {
    if (isSaving.value) return;
    isSaving.value = true;
    try {
      final driver =
          _authenticatedDriver ?? await _dbService.getAuthenticatedDriver();
      if (driver != null && pin.value == driver.pin.trim()) {
        logImportant('Driver ${driver.username} unlocked session via passcode');
        pin.value = '';
        Get.offAllNamed(AppRoutes.landing);
      } else {
        pin.value = '';
        isInputLocked.value = false;
        Get.snackbar(
          'Incorrect Passcode',
          'The passcode you entered is incorrect. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFFFEBEB),
          colorText: const Color(0xFFD32F2F),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e, stack) {
      isInputLocked.value = false;
      logError('Passcode verification error', e, stack);
    } finally {
      isSaving.value = false;
    }
  }

  /// Logs out of the locked session so another driver can sign in.
  Future<void> switchAccount() async {
    await _dbService.clearAuthenticatedDrivers();
    Get.offAllNamed(AppRoutes.login);
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
      isInputLocked.value = false;
      return;
    }

    isSaving.value = true;

    try {
      final driver = Get.isRegistered<LoginController>()
          ? Get.find<LoginController>().currentDriver
          : _authenticatedDriver;
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
      Get.offAllNamed(AppRoutes.landing);
    } catch (e, stack) {
      logError('PIN setup error', e, stack);
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
