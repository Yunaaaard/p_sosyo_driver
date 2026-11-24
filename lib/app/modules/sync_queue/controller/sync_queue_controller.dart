import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/data/services/driver_sync_service.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';

class SyncQueueController extends GetxController {
  final RxBool isLoading = true.obs;
  final RxBool isFlushing = false.obs;
  final RxList<DeliveryOrder> pendingOrders = <DeliveryOrder>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadPending();
  }

  Future<void> loadPending() async {
    isLoading.value = true;
    try {
      final all = await DatabaseService.to.getAllDeliveryOrders();
      final pending = all
          .where((o) => o.syncStatus == 'pending')
          .toList()
        ..sort((a, b) => (b.deliveredAt ?? b.lastAttemptAt ?? '')
            .compareTo(a.deliveredAt ?? a.lastAttemptAt ?? ''));
      pendingOrders.assignAll(pending);
    } catch (e, stack) {
      logError('Error loading offline sync queue', e, stack);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> flushQueueNow() async {
    if (isFlushing.value || pendingOrders.isEmpty) return;
    isFlushing.value = true;
    logSync('Flushing ${pendingOrders.length} pending offline updates...');
    try {
      final result = await DriverSyncService.to.syncAdvanceOrders();
      if (result.success) {
        final flushedCount = pendingOrders.length;
        await DatabaseService.to.markAllPendingSynced();
        await loadPending();
        if (Get.isRegistered<HomeController>()) {
          await Get.find<HomeController>().loadOrdersFromDb();
        }
        logImportant(
          'Offline sync queue flushed: $flushedCount record(s) marked synced',
          tag: 'SYNC_QUEUE',
        );
        Get.snackbar(
          'Sync Complete',
          '$flushedCount pending update(s) synced with dispatch.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFE8F5E9),
          colorText: const Color(0xFF15803D),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      } else {
        logWarning('Offline queue flush paused: ${result.message}');
        Get.snackbar(
          'Offline Notice',
          result.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFFFF3CD),
          colorText: const Color(0xFF856404),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    } catch (e, stack) {
      logError('Error flushing offline sync queue', e, stack);
    } finally {
      isFlushing.value = false;
    }
  }
}
