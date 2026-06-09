import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/data/models/order_item.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';

class OrderDetailsController extends GetxController {
  final RxList<OrderItem> items = <OrderItem>[].obs;
  final RxBool isLoading = true.obs;

  final DatabaseService _dbService = DatabaseService.to;

  @override
  void onInit() {
    super.onInit();
    _loadOrderItems();
  }

  /// Load order items from the database.
  /// Currently loads items for delivery order '1' (hardcoded delivery order).
  /// Will be updated when delivery orders come from API.
  Future<void> _loadOrderItems() async {
    try {
      isLoading.value = true;
      final loadedItems = await _dbService.getOrderItems('1');
      items.assignAll(loadedItems);
    } catch (e) {
      debugPrint('Error loading order items: $e');
    } finally {
      isLoading.value = false;
    }
  }

  int get totalSku => items.length;

  double get totalAmount {
    return items.fold(0.0, (sum, item) => sum + item.totalAmount);
  }

  String get formattedTotalAmount {
    final parts = totalAmount.toStringAsFixed(2).split('.');
    final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAllMapped(regExp, (Match m) => ',');
    return '₱ ${parts.join('.')}';
  }
}
