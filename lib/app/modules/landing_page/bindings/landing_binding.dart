import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/landing_page/controllers/landing_controller.dart';

class LandingBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(LandingController());
  }
}