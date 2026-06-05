import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/otp_verification/controller/pin_verification_controller.dart';

class PinVerificationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PinVerificationController>(
      () => PinVerificationController(),
    );
  }
}
