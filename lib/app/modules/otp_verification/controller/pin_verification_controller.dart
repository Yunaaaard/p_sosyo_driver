import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';

class PinVerificationController extends GetxController {
  final RxString pin = "".obs;
  static const int pinLength = 6;

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

  void submitPin() {
    if (pin.value.length == pinLength) {
      // For now, redirect to Home on success
      Get.offAllNamed(AppRoutes.home);
    } else {
      Get.snackbar(
        'Invalid PIN',
        'Please enter a 6-digit PIN code.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
