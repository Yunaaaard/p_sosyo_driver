import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/sync_queue/controller/sync_queue_controller.dart';

class SyncQueueBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SyncQueueController>(() => SyncQueueController());
  }
}
