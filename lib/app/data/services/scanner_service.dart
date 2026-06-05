import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';

class ScannerService extends GetxService {
  static ScannerService get to => Get.find<ScannerService>();

  /// Launches the QR Scanner page and returns scanned data.
  Future<String?> scanReceipt() async {
    final result = await Get.toNamed(AppRoutes.qrScanner);
    if (result is String) {
      return result;
    }
    return null;
  }
}
