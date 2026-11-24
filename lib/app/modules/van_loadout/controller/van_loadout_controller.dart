import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/models/order_item.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';

class ConsolidatedSkuItem {
  final String stockCode;
  final String title;
  final String uom;
  final int totalQty;

  const ConsolidatedSkuItem({
    required this.stockCode,
    required this.title,
    required this.uom,
    required this.totalQty,
  });
}

class VanLoadoutController extends GetxController {
  final RxBool isLoading = true.obs;
  final RxString activeTab = 'lifo'.obs;
  final RxList<DeliveryOrder> lifoStops = <DeliveryOrder>[].obs;
  final RxMap<String, List<OrderItem>> itemsByOrderId =
      <String, List<OrderItem>>{}.obs;
  final RxList<ConsolidatedSkuItem> consolidatedSkus =
      <ConsolidatedSkuItem>[].obs;
  final RxSet<String> checkedOrderIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadManifest();
  }

  void switchTab(String tab) {
    activeTab.value = tab;
  }

  void toggleStopLoaded(String orderId) {
    if (checkedOrderIds.contains(orderId)) {
      checkedOrderIds.remove(orderId);
    } else {
      checkedOrderIds.add(orderId);
    }
  }

  Future<void> loadManifest() async {
    isLoading.value = true;
    try {
      final orders = await DatabaseService.to.getAllDeliveryOrders();
      final items = await DatabaseService.to.getAllOrderItems();

      final active = orders
          .where((o) => o.status.value == 'Out for Delivery' && !o.isLocked)
          .toList()
        ..sort((a, b) {
          final aSeq = a.routeSequence ?? 999999;
          final bSeq = b.routeSequence ?? 999999;
          if (aSeq != bSeq) return aSeq.compareTo(bSeq);
          return a.storeName.compareTo(b.storeName);
        });

      // LIFO: Last stop loaded first (closest to cab), Stop #1 at tailgate
      lifoStops.assignAll(active.reversed.toList());

      final Map<String, List<OrderItem>> grouped = {};
      for (final item in items) {
        grouped.putIfAbsent(item.deliveryOrderId, () => []).add(item);
      }
      itemsByOrderId.assignAll(grouped);

      final Map<String, ({String stockCode, String title, String uom, int qty})>
          skuTotals = {};
      for (final order in active) {
        final orderItems =
            grouped[order.id] ?? grouped[order.transactionId] ?? [];
        for (final item in orderItems) {
          final key = '${item.stockCode}_${item.title}_${item.uom}';
          final prev = skuTotals[key];
          skuTotals[key] = (
            stockCode: item.stockCode,
            title: item.title,
            uom: item.uom,
            qty: (prev?.qty ?? 0) + item.numericQty,
          );
        }
      }

      final consolidated = skuTotals.values
          .map(
            (e) => ConsolidatedSkuItem(
              stockCode: e.stockCode,
              title: e.title,
              uom: e.uom,
              totalQty: e.qty,
            ),
          )
          .toList()
        ..sort((a, b) => b.totalQty.compareTo(a.totalQty));
      consolidatedSkus.assignAll(consolidated);

      logInfo(
        'Van loadout manifest ready: ${active.length} stops, ${consolidated.length} SKUs',
        tag: 'LOADOUT',
      );
    } catch (e, stack) {
      logError('Error loading van loadout manifest', e, stack);
    } finally {
      isLoading.value = false;
    }
  }
}
