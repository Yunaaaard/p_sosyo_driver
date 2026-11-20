import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/route_calendar/controller/route_calendar_controller.dart';

class RouteCalendarBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RouteCalendarController>(() => RouteCalendarController());
  }
}
