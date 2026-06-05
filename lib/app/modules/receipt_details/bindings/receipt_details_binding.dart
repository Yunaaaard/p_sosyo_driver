import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/receipt_details/controller/receipt_details_controller.dart';

class ReceiptDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReceiptDetailsController>(
      () => ReceiptDetailsController(),
    );
  }
}
