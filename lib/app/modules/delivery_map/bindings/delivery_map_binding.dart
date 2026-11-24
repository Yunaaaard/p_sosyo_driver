import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/delivery_map/controller/delivery_map_controller.dart';

class DeliveryMapBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DeliveryMapController>(() => DeliveryMapController());
  }
}
