import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/cash_remittance/controller/cash_remittance_controller.dart';

class CashRemittanceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CashRemittanceController>(() => CashRemittanceController());
  }
}
