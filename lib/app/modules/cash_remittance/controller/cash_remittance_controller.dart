import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';

class CashRemittanceController extends GetxController {
  static const List<int> denominations = [
    1000,
    500,
    200,
    100,
    50,
    20,
    10,
    5,
    1,
  ];

  final RxBool isLoading = true.obs;
  final RxList<DeliveryOrder> deliveredOrders = <DeliveryOrder>[].obs;
  final RxMap<int, int> denominationCounts = <int, int>{
    for (final d in denominations) d: 0,
  }.obs;

  @override
  void onInit() {
    super.onInit();
    loadDeliveredOrders();
  }

  Future<void> loadDeliveredOrders() async {
    isLoading.value = true;
    try {
      final all = await DatabaseService.to.getAllDeliveryOrders();
      final delivered = all
          .where((o) => o.status.value == 'Delivered')
          .toList()
        ..sort((a, b) => (b.deliveredAt ?? '').compareTo(a.deliveredAt ?? ''));
      deliveredOrders.assignAll(delivered);
    } catch (e, stack) {
      logError('Error loading cash remittance orders', e, stack);
    } finally {
      isLoading.value = false;
    }
  }

  double get expectedCashTotal {
    double sum = 0;
    for (final o in deliveredOrders) {
      if (o.paymentMethod != 'Digital/QR') {
        sum += o.numericTotalAmount;
      }
    }
    return sum;
  }

  double get digitalQrTotal {
    double sum = 0;
    for (final o in deliveredOrders) {
      if (o.paymentMethod == 'Digital/QR') {
        sum += o.numericTotalAmount;
      }
    }
    return sum;
  }

  double get countedCashTotal {
    double sum = 0;
    for (final d in denominations) {
      sum += d * (denominationCounts[d] ?? 0);
    }
    return sum;
  }

  double get variance => countedCashTotal - expectedCashTotal;

  void incrementDenomination(int denom) {
    denominationCounts[denom] = (denominationCounts[denom] ?? 0) + 1;
    denominationCounts.refresh();
  }

  void decrementDenomination(int denom) {
    final current = denominationCounts[denom] ?? 0;
    if (current <= 0) return;
    denominationCounts[denom] = current - 1;
    denominationCounts.refresh();
  }

  void resetCounts() {
    for (final d in denominations) {
      denominationCounts[d] = 0;
    }
    denominationCounts.refresh();
  }

  Future<void> toggleOrderPaymentMethod(DeliveryOrder order) async {
    final nextMethod =
        order.paymentMethod == 'Digital/QR' ? 'Cash' : 'Digital/QR';
    await DatabaseService.to.updateOrderPaymentMethod(order.id, nextMethod);
    final idx = deliveredOrders.indexWhere((o) => o.id == order.id);
    if (idx != -1) {
      deliveredOrders[idx] =
          deliveredOrders[idx].copyWith(paymentMethod: nextMethod);
      deliveredOrders.refresh();
    }
    if (Get.isRegistered<HomeController>()) {
      await Get.find<HomeController>().loadOrdersFromDb();
    }
    logImportant(
      'Updated payment method for #${order.id} -> $nextMethod',
      tag: 'REMITTANCE',
    );
  }
}
