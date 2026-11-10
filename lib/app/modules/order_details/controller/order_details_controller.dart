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

  String get storeName => order?.storeName ?? 'Store';

  String get address => order?.address ?? '';

  String get orderId => order?.id ?? order?.transactionId ?? '';

  String get custCode => order?.custCode ?? '';

  String get storePhoto => order?.storePhoto ?? '';

  /// Load order items from the database for the active order.
  Future<void> _loadOrderItems() async {
    try {
      isLoading.value = true;
      final targetId = orderId;
      final Set<String> targetIds = {
        if (targetId.isNotEmpty) targetId,
        if (order != null && order!.transactionId.isNotEmpty) order!.transactionId,
        if (order != null && order!.id.isNotEmpty) order!.id,
      };

      final List<OrderItem> allLoaded = [];
      for (final id in targetIds) {
        final queryResults = await _dbService.getOrderItems(id);
        allLoaded.addAll(queryResults);
      }

      // Deduplicate items by stockCode or title to prevent duplicate cards
      final Map<String, OrderItem> uniqueItems = {};
      for (final item in allLoaded) {
        final key = item.stockCode.isNotEmpty ? item.stockCode : item.title;
        uniqueItems[key] = item;
      }

      items.assignAll(uniqueItems.values.toList());
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
