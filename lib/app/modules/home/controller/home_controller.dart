import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/data/services/driver_sync_service.dart';
import 'package:p_sosyo_driver/app/widgets/sync_progress_dialog.dart';

class HomeController extends GetxController {
  final RxString activeTab = "Out for Delivery".obs;

  final RxList<DeliveryOrder> orders = <DeliveryOrder>[].obs;

  final RxInt deliveredCount = 0.obs;
  final RxDouble totalSales = 0.0.obs;

  // Syncing states
  final RxBool isSyncing = false.obs;
  final RxBool isSyncCompleted = false.obs;
  final RxDouble syncProgress = 0.0.obs;
  final RxString syncStatusMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadOrdersFromDb();
  }

  Future<void> loadOrdersFromDb() async {
    try {
      final dbService = DatabaseService.to;
      final dbOrders = await dbService.getAllDeliveryOrders();
      if (dbOrders.isNotEmpty) {
        orders.assignAll(dbOrders);
        _recalculateTotals();
      }
    } catch (e) {
      debugPrint('Error loading orders from DB in HomeController: $e');
    }
  }

  void _recalculateTotals() {
    int delivered = 0;
    double sales = 0.0;

    for (final order in orders) {
      if (order.status.value == 'Delivered') {
        delivered++;
        final cleanAmountStr = order.totalAmount
            .replaceAll('₱', '')
            .replaceAll(',', '')
            .trim();
        final amount = double.tryParse(cleanAmountStr) ?? 0.0;
        sales += amount;
      }
    }

    deliveredCount.value = delivered;
    totalSales.value = sales;
  }

  @override
  void onReady() {
    super.onReady();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showSyncDialog();
    });
  }

  void changeTab(String tabName) {
    activeTab.value = tabName;
  }

  Future<void> markOrderAsDelivered(String orderId) async {
    final index = orders.indexWhere(
        (order) => order.id == orderId || order.transactionId == orderId);
    if (index != -1 && orders[index].status.value != 'Delivered') {
      orders[index].status.value = 'Delivered';
      await DatabaseService.to.updateDeliveryOrderStatus(orders[index].id, 'Delivered');
      await DatabaseService.to.updateDeliveryOrderStatus(orders[index].transactionId, 'Delivered');
      _recalculateTotals();
    }
  }

  Future<void> syncDeliveries() async {
    isSyncing.value = true;
    isSyncCompleted.value = false;
    syncProgress.value = 0.08;
    syncStatusMessage.value = 'Connecting to dispatch server...';

    try {
      final result = await DriverSyncService.to.syncAdvanceOrders(
        onProgress: (progress, message) {
          syncProgress.value = progress;
          syncStatusMessage.value = message;
        },
      );
      await loadOrdersFromDb();

      if (result.success) {
        syncProgress.value = 1.0;
        isSyncing.value = false;
        isSyncCompleted.value = true;
        final count = result.orderCount > 0 ? result.orderCount : orders.length;
        syncStatusMessage.value = count > 0
            ? '$count delivery orders synced & ready!'
            : 'Your delivery orders are now up to date.';
        await Future.delayed(const Duration(milliseconds: 1400));
        if (Get.isDialogOpen ?? false) {
          Get.back(); // Close dialog
        }
      } else {
        isSyncing.value = false;
        syncStatusMessage.value = result.message;
        Get.snackbar(
          'Sync Notice',
          result.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFFFF3CD),
          colorText: const Color(0xFF856404),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 3),
        );
        await Future.delayed(const Duration(milliseconds: 1200));
        if (Get.isDialogOpen ?? false) {
          Get.back(); // Close dialog so driver can continue offline
        }
      }
    } catch (e) {
      isSyncing.value = false;
      debugPrint('Sync error: $e');
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
    }
  }

  void showSyncDialog() {
    isSyncing.value = false;
    isSyncCompleted.value = false;
    syncProgress.value = 0.0;
    syncStatusMessage.value = '';

    Get.dialog(
      SyncProgressDialog(controller: this),
      barrierDismissible: false,
    );
  }
}
