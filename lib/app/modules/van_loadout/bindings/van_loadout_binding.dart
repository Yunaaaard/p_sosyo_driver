import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/van_loadout/controller/van_loadout_controller.dart';

class VanLoadoutBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VanLoadoutController>(() => VanLoadoutController());
  }
}
