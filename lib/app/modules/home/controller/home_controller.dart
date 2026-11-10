import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/data/services/driver_sync_service.dart';

class HomeController extends GetxController {
  final RxString activeTab = "Out for Delivery".obs;

  final RxList<DeliveryOrder> orders = <DeliveryOrder>[].obs;

  final RxInt deliveredCount = 0.obs;
  final RxDouble totalSales = 0.0.obs;

  // Syncing states
  final RxBool isSyncing = false.obs;
  final RxBool isSyncCompleted = false.obs;
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
      await DatabaseService.to.updateDeliveryOrderStatus(orderId, 'Delivered');
      _recalculateTotals();
    }
  }

  Future<void> syncDeliveries() async {
    isSyncing.value = true;
    syncStatusMessage.value = 'Connecting to server and fetching advance orders...';

    try {
      final result = await DriverSyncService.to.syncAdvanceOrders();
      await loadOrdersFromDb();

      if (result.success) {
        isSyncing.value = false;
        isSyncCompleted.value = true;
        syncStatusMessage.value = result.orderCount > 0
            ? '${result.orderCount} delivery orders synced successfully.'
            : 'Your delivery orders are now up to date.';
        await Future.delayed(const Duration(milliseconds: 1000));
        Get.back(); // Close dialog
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
        Get.back(); // Close dialog so driver can continue offline
      }
    } catch (e) {
      isSyncing.value = false;
      debugPrint('Sync error: $e');
      Get.back();
    }
  }

  void showSyncDialog() {
    isSyncing.value = false;
    isSyncCompleted.value = false;
    syncStatusMessage.value = '';

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Obx(() {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Icon / Illustration
                if (isSyncCompleted.value)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFFFEE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 60,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF2EFFF),
                      shape: BoxShape.circle,
                    ),
                    child: isSyncing.value
                        ? const SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              color: Color(0xFF6533E7),
                              strokeWidth: 5,
                            ),
                          )
                        : const Icon(
                            Icons.sync_rounded,
                            color: Color(0xFF6533E7),
                            size: 60,
                          ),
                  ),
                const SizedBox(height: 20),

                // Title
                Text(
                  isSyncCompleted.value
                      ? 'Sync Completed'
                      : isSyncing.value
                          ? 'Syncing Deliveries...'
                          : 'Mandatory Syncing',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2F333A),
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle
                Text(
                  isSyncCompleted.value
                      ? syncStatusMessage.value.isNotEmpty
                          ? syncStatusMessage.value
                          : 'Your delivery orders are now up to date.'
                      : isSyncing.value
                          ? syncStatusMessage.value.isNotEmpty
                              ? syncStatusMessage.value
                              : 'Please wait while we sync your order schedule and route information.'
                          : 'In order to get the new orders from the customer you need to sync first by clicking the Sync Now Button',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Color(0xFF8A8F99),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Button
                if (!isSyncing.value && !isSyncCompleted.value)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: syncDeliveries,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6533E7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Sync Now',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
      barrierDismissible: false,
    );
  }
}
