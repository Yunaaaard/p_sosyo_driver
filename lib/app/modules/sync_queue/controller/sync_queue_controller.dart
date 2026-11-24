import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/data/models/pending_transaction.dart';
import 'package:p_sosyo_driver/app/data/services/transaction_services.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';

class SyncQueueController extends GetxController {
  final RxBool isLoading = true.obs;
  final RxBool isFlushing = false.obs;
  final RxList<PendingTransaction> pendingTransactions =
      <PendingTransaction>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadPending();
  }

  Future<void> loadPending() async {
    isLoading.value = true;
    try {
      await TransactionServices.to.refreshTransactions();
      pendingTransactions.assignAll(TransactionServices.to.pendingTransactions);
      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().refreshPendingOfflineCount();
      }
    } catch (e, stack) {
      logError('Error loading offline sync queue', e, stack);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> flushQueueNow() async {
    if (isFlushing.value || pendingTransactions.isEmpty) return;
    isFlushing.value = true;
    try {
      final result = await TransactionServices.to.getPendings();
      await loadPending();
      if (result.success) {
        if (Get.isRegistered<HomeController>()) {
          await Get.find<HomeController>().loadOrdersFromDb();
        }
        Get.snackbar(
          'Sync Complete',
          result.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFE8F5E9),
          colorText: const Color(0xFF15803D),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      } else {
        final isOffline = result.message.contains('No internet connection');
        Get.snackbar(
          isOffline ? 'Still Offline' : 'Sync Notice',
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
