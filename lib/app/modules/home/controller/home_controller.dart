import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';

class HomeController extends GetxController {
  final RxString activeTab = "Out for Delivery".obs;

  final RxList<DeliveryOrder> orders = <DeliveryOrder>[
    DeliveryOrder(
      id: '1',
      storeName: 'TINDAHAN NI ALING NENA',
      address: 'Fast Distribution Head Office H. Abellana Canduman, Mandaue City Cebu',
      distance: '12m away',
      sku: '32',
      totalAmount: '₱ 23,893.12',
      status: 'Out for Delivery',
    ),
  ].obs;

  final RxInt deliveredCount = 5.obs;
  final RxDouble totalSales = 23893.12.obs;

  void changeTab(String tabName) {
    activeTab.value = tabName;
  }

  void markOrderAsDelivered(String orderId) {
    final index = orders.indexWhere((order) => order.id == orderId);
    if (index != -1 && orders[index].status.value != 'Delivered') {
      orders[index].status.value = 'Delivered';
      deliveredCount.value += 1;

      // Parse totalAmount ('₱ 23,893.12' -> 23893.12) to add to totalSales
      final cleanAmountStr = orders[index].totalAmount
          .replaceAll('₱', '')
          .replaceAll(',', '')
          .trim();
      final amount = double.tryParse(cleanAmountStr) ?? 0.0;
      totalSales.value += amount;
    }
  }
}
