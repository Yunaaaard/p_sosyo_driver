import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/landing/controller/landing_controller.dart';

class LandingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LandingController>(() => LandingController());
  }
}
