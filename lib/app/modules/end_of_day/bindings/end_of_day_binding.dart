import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/end_of_day/controller/end_of_day_controller.dart';

class EndOfDayBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EndOfDayController>(() => EndOfDayController());
  }
}
