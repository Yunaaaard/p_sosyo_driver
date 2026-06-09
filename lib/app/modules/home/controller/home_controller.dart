import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';

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

  final RxInt deliveredCount = 0.obs;
  final RxDouble totalSales = 0.0.obs;

  // Syncing states
  final RxBool isSyncing = false.obs;
  final RxBool isSyncCompleted = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadOrderTotals();
  }

  Future<void> _loadOrderTotals() async {
    try {
      final dbService = DatabaseService.to;
      for (var i = 0; i < orders.length; i++) {
        final order = orders[i];
        final items = await dbService.getOrderItems(order.id);
        if (items.isNotEmpty) {
          final totalSku = items.length;
          double totalAmount = 0.0;
          for (final item in items) {
            totalAmount += item.totalAmount;
          }
          final parts = totalAmount.toStringAsFixed(2).split('.');
          final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
          parts[0] = parts[0].replaceAllMapped(regExp, (Match m) => ',');
          final formattedAmount = '₱ ${parts.join('.')}';

          orders[i] = DeliveryOrder(
            id: order.id,
            storeName: order.storeName,
            address: order.address,
            distance: order.distance,
            sku: totalSku.toString(),
            totalAmount: formattedAmount,
            status: order.status.value,
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading order totals in HomeController: $e');
    }
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

  Future<void> syncDeliveries() async {
    isSyncing.value = true;
    await Future.delayed(const Duration(seconds: 2));
    isSyncing.value = false;
    isSyncCompleted.value = true;
    await Future.delayed(const Duration(milliseconds: 800));
    Get.back(); // Close dialog
  }

  void showSyncDialog() {
    isSyncing.value = false;
    isSyncCompleted.value = false;

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
                      ? 'Your delivery orders are now up to date.'
                      : isSyncing.value
                          ? 'Please wait while we sync your order schedule and route information.'
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
