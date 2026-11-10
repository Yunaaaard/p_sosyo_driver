import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/models/order_item.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';

class OrderDetailsController extends GetxController {
  DeliveryOrder? order;
  final RxList<OrderItem> items = <OrderItem>[].obs;
  final RxBool isLoading = true.obs;

  final DatabaseService _dbService = DatabaseService.to;

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments is DeliveryOrder) {
      order = Get.arguments as DeliveryOrder;
    }
    _loadOrderItems();
  }

  String get storeName => order?.storeName ?? 'TINDAHAN NI ALING NENA';

  String get address =>
      order?.address ??
      'Fast Distribution Head Office H. Abellana Canduman, Mandaue City Cebu';

  String get orderId => order?.transactionId ?? order?.id ?? '1';

  /// Load order items from the database for the active order.
  Future<void> _loadOrderItems() async {
    try {
      isLoading.value = true;
      final targetId = orderId;
      var loadedItems = await _dbService.getOrderItems(targetId);

      // Fallback: If not found by transactionId, try by order.id
      if (loadedItems.isEmpty && order != null && order!.id != targetId) {
        loadedItems = await _dbService.getOrderItems(order!.id);
      }

      // Fallback: If still empty and in offline demo mode, load seeded items '1'
      if (loadedItems.isEmpty && targetId == '1') {
        loadedItems = await _dbService.getOrderItems('1');
      }

      items.assignAll(loadedItems);
    } catch (e) {
      debugPrint('Error loading order items: $e');
    } finally {
      isLoading.value = false;
    }
  }

  int get totalSku => items.isNotEmpty
      ? items.length
      : (int.tryParse(order?.sku ?? '0') ?? 0);

  double get totalAmount {
    if (items.isNotEmpty) {
      return items.fold(0.0, (sum, item) => sum + item.totalAmount);
    }
    if (order != null) {
      final clean = order!.totalAmount
          .replaceAll('₱', '')
          .replaceAll(',', '')
          .trim();
      return double.tryParse(clean) ?? 0.0;
    }
    return 0.0;
  }

  String get formattedTotalAmount {
    if (items.isEmpty && order != null && order!.totalAmount.isNotEmpty) {
      return order!.totalAmount;
    }
    final parts = totalAmount.toStringAsFixed(2).split('.');
    final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAllMapped(regExp, (Match m) => ',');
    return '₱ ${parts.join('.')}';
  }
}
