import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/route_planner/controller/route_planner_controller.dart';

class RoutePlannerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RoutePlannerController>(() => RoutePlannerController());
  }
}
