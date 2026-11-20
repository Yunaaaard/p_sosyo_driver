import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/core/utils/location_helper.dart';
import 'package:p_sosyo_driver/app/core/utils/paqner_qr_codec.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_attempt.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/data/services/driver_sync_service.dart';
import 'package:p_sosyo_driver/app/data/services/scanner_service.dart';
import 'package:p_sosyo_driver/app/data/services/sms_service.dart';
import 'package:p_sosyo_driver/app/widgets/sync_progress_dialog.dart';

class HomeController extends GetxController {
  final RxString activeTab = "Out for Delivery".obs;
  final RxnString selectedDateFilter = RxnString();

  final RxList<DeliveryOrder> orders = <DeliveryOrder>[].obs;

  final RxInt deliveredCount = 0.obs;
  final RxDouble totalSales = 0.0.obs;
  final RxBool sortNearestFirst = true.obs;
  final RxDouble driverLatitude = LocationHelper.defaultDriverLat.obs;
  final RxDouble driverLongitude = LocationHelper.defaultDriverLng.obs;
  final Rx<DateTime> currentTime = DateTime.now().toUtc().obs;
  Timer? _cancelWindowTicker;

  // Syncing states
  final RxBool isSyncing = false.obs;
  final RxBool isSyncCompleted = false.obs;
  final RxDouble syncProgress = 0.0.obs;
  final RxString syncStatusMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _cancelWindowTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      currentTime.value = DateTime.now().toUtc();
    });
    loadOrdersFromDb();
  }

  @override
  void onClose() {
    _cancelWindowTicker?.cancel();
    super.onClose();
  }

  Future<void> loadOrdersFromDb() async {
    try {
      final dbService = DatabaseService.to;
      final dbOrders = await dbService.getAllDeliveryOrders();
      if (dbOrders.isNotEmpty) {
        final driverCoords = await LocationHelper.getCurrentDriverLocation();
        driverLatitude.value = driverCoords.latitude;
        driverLongitude.value = driverCoords.longitude;

        final nowLocal = DateTime.now();
        final todayIso =
            '${nowLocal.year.toString().padLeft(4, '0')}-${nowLocal.month.toString().padLeft(2, '0')}-${nowLocal.day.toString().padLeft(2, '0')}';

        final List<DeliveryOrder> resolvedOrders = [];
        for (final order in dbOrders) {
          var current = order.withResolvedLocation(
            driverLat: driverCoords.latitude,
            driverLng: driverCoords.longitude,
          );
          if (current.isLocked &&
              current.scheduledDeliveryDate != null &&
              current.scheduledDeliveryDate!.trim().isNotEmpty &&
              current.scheduledDeliveryDate!.trim().compareTo(todayIso) <= 0) {
            await dbService.updateOrderLockState(
              orderId: current.id,
              isLocked: false,
            );
            current = current.copyWith(
              isLocked: false,
              clearScheduledDeliveryDate: true,
              clearLockedAt: true,
            );
            logImportant(
              'Auto-unlocked order #${current.id} (${current.storeName}) on scheduled date $todayIso',
            );
          }
          resolvedOrders.add(current);
        }

        _sortOrdersList(resolvedOrders);
        orders.assignAll(resolvedOrders);
        _recalculateTotals();
        logImportant(
          'Loaded & sorted ${orders.length} deliveries by distance (${sortNearestFirst.value ? "Nearest → Farthest" : "Farthest → Nearest"})',
        );
      }
    } catch (e) {
      logError('Error loading orders from DB in HomeController', e);
    }
  }

  void toggleDistanceSort() {
    sortNearestFirst.value = !sortNearestFirst.value;
    final list = orders.toList();
    _sortOrdersList(list);
    orders.assignAll(list);
    logImportant(
      'Re-sorted deliveries: ${sortNearestFirst.value ? "Nearest → Farthest" : "Farthest → Nearest"}',
    );
  }

  void _sortOrdersList(List<DeliveryOrder> list) {
    list.sort((a, b) {
      if (a.isLocked != b.isLocked) {
        return a.isLocked ? 1 : -1;
      }
      if (a.isLocked && b.isLocked) {
        final aDate = a.scheduledDeliveryDate ?? '';
        final bDate = b.scheduledDeliveryDate ?? '';
        final dateCmp = aDate.compareTo(bDate);
        if (dateCmp != 0) return dateCmp;
      }
      final aKm = a.distanceKm ?? double.infinity;
      final bKm = b.distanceKm ?? double.infinity;
      return sortNearestFirst.value ? aKm.compareTo(bKm) : bKm.compareTo(aKm);
    });
  }

  /// Open Google Maps directions from the driver's current location to [order].
  Future<void> openOrderNavigation(DeliveryOrder order) async {
    final resolved = order.withResolvedLocation(
      driverLat: driverLatitude.value,
      driverLng: driverLongitude.value,
    );
    final destLat = resolved.latitude;
    final destLng = resolved.longitude;
    if (destLat == null || destLng == null) return;

    final success = await LocationHelper.openGoogleMapsDirections(
      originLat: driverLatitude.value,
      originLng: driverLongitude.value,
      destLat: destLat,
      destLng: destLng,
      storeName: order.storeName,
    );

    if (!success) {
      Get.snackbar(
        'Map Navigation',
        'Rebuild the app (flutter run) to activate native Google Maps launching for ${order.storeName} ($destLat, $destLng).',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 3),
      );
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

  /// Resolves an order's effective YYYY-MM-DD date in Philippine Time (UTC+8).
  static String resolveEffectiveDateIso(DeliveryOrder order) {
    if (order.isLocked &&
        order.scheduledDeliveryDate != null &&
        order.scheduledDeliveryDate!.trim().length >= 10) {
      return order.scheduledDeliveryDate!.trim().substring(0, 10);
    }
    if (order.deliveredAt != null && order.deliveredAt!.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(order.deliveredAt!.trim());
      if (parsed != null) {
        final pht = parsed.toUtc().add(const Duration(hours: 8));
        return '${pht.year.toString().padLeft(4, '0')}-${pht.month.toString().padLeft(2, '0')}-${pht.day.toString().padLeft(2, '0')}';
      }
    }
    final raw = order.deliveryDate.trim();
    if (raw.length >= 10) {
      return raw.substring(0, 10);
    }
    final nowPht = DateTime.now().toUtc().add(const Duration(hours: 8));
    return '${nowPht.year.toString().padLeft(4, '0')}-${nowPht.month.toString().padLeft(2, '0')}-${nowPht.day.toString().padLeft(2, '0')}';
  }

  void setDateFilter(String? isoDate) {
    final clean = isoDate?.trim();
    selectedDateFilter.value =
        (clean != null && clean.isNotEmpty) ? clean : null;
    logImportant(
      'Active Home date filter set to: ${selectedDateFilter.value ?? "ALL"}',
    );
  }

  void clearDateFilter() => setDateFilter(null);

  bool matchesDateFilter(DeliveryOrder order) {
    final filter = selectedDateFilter.value;
    if (filter == null || filter.isEmpty) return true;
    return resolveEffectiveDateIso(order) == filter;
  }

  Future<void> markOrderAsDelivered(
    String orderId, {
    String? paymentReference,
    String? proofOfDeliveryPath,
  }) async {
    final index = orders.indexWhere(
        (order) => order.id == orderId || order.transactionId == orderId);
    if (index != -1 && orders[index].status.value != 'Delivered') {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final existing = orders[index];
      final cleanRef = (paymentReference?.trim().isNotEmpty == true)
          ? paymentReference!.trim()
          : existing.paymentReference;
      final cleanPod = (proofOfDeliveryPath?.trim().isNotEmpty == true)
          ? proofOfDeliveryPath!.trim()
          : existing.proofOfDeliveryPath;

      final updated = existing.copyWith(
        status: 'Delivered',
        deliveredAt: nowIso,
        paymentReference: cleanRef,
        proofOfDeliveryPath: cleanPod,
      );
      orders[index] = updated;

      await DatabaseService.to.updateDeliveryOrderStatus(
        existing.id,
        'Delivered',
        deliveredAt: nowIso,
        paymentReference: cleanRef,
        proofOfDeliveryPath: cleanPod,
      );
      await DatabaseService.to.updateDeliveryOrderStatus(
        existing.transactionId,
        'Delivered',
        deliveredAt: nowIso,
        paymentReference: cleanRef,
        proofOfDeliveryPath: cleanPod,
      );
      _recalculateTotals();
      logImportant(
        'Order #$orderId marked as DELIVERED! (1h cancel window started, Ref: ${cleanRef ?? "-"}, Sales: ₱${totalSales.value.toStringAsFixed(2)})',
      );
    }
  }

  /// Resolve the `paymentReference` (`r`) for a delivered order's 2-way Paqner cancellation.
  Future<String> resolveCancelPaymentReference(DeliveryOrder order) async {
    final direct = order.paymentReference?.trim() ?? '';
    if (direct.isNotEmpty) return direct;

    try {
      final receipts = await DatabaseService.to.getReceipts(order.id);
      if (receipts.isNotEmpty &&
          receipts.last.referenceNumber.trim().isNotEmpty) {
        return receipts.last.referenceNumber.trim();
      }
      final txnReceipts =
          await DatabaseService.to.getReceipts(order.transactionId);
      if (txnReceipts.isNotEmpty &&
          txnReceipts.last.referenceNumber.trim().isNotEmpty) {
        return txnReceipts.last.referenceNumber.trim();
      }
    } catch (e, stack) {
      logError('Error resolving receipt reference for cancellation', e, stack);
    }

    return order.id;
  }

  /// Scan and verify the Paqner user's cancellation confirmation QR (`r` + `s == 'cancelled'`).
  /// Returns `null` on verified cancellation, or an error string if aborted/invalid.
  Future<String?> verifyAndCompletePaqnerCancellation(
    DeliveryOrder order,
    String expectedReference, {
    String? reason,
  }) async {
    final rawScanned = await ScannerService.to.scanReceipt();
    if (rawScanned == null || rawScanned.trim().isEmpty) {
      return 'Scan cancelled';
    }

    Map<String, dynamic> decoded;
    try {
      decoded = PaqnerQrCodec.decode(rawScanned);
    } catch (e, stack) {
      logError('Failed to decode Paqner cancellation QR', e, stack);
      return 'Parsing Failure: Failed to decode scanned cancellation QR.';
    }

    final error = PaqnerQrCodec.verifyCancelScan(
      scanned: decoded,
      expectedReference: expectedReference,
    );
    if (error != null) {
      logWarning('Paqner cancel verification failed: $error', tag: 'CANCEL_QR');
      return error;
    }

    await markOrderAsCancelled(order.id, reason: reason);
    return null;
  }

  Future<void> markOrderAsCancelled(
    String orderId, {
    String? reason,
  }) async {
    final index = orders.indexWhere(
        (order) => order.id == orderId || order.transactionId == orderId);
    if (index != -1 && orders[index].status.value != 'Cancelled') {
      final existing = orders[index];
      final cleanReason = reason?.trim().isNotEmpty == true
          ? reason!.trim()
          : existing.cancellationReason;
      orders[index] = existing.copyWith(
        status: 'Cancelled',
        cancellationReason: cleanReason,
      );
      await DatabaseService.to.updateDeliveryOrderStatus(
        existing.id,
        'Cancelled',
        cancellationReason: cleanReason,
      );
      await DatabaseService.to.updateDeliveryOrderStatus(
        existing.transactionId,
        'Cancelled',
        cancellationReason: cleanReason,
      );
      _recalculateTotals();
      logImportant(
        'Order #$orderId marked as CANCELLED! Reason: ${cleanReason ?? "N/A"}',
      );
    }
  }

  static String formatDateLabel(String isoDate) {
    final parsed = DateTime.tryParse(isoDate.trim());
    if (parsed == null) return isoDate;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }

  /// Records a delivery attempt with a reason (no auto-cancel).
  /// When [lockAndQueue] is true, locks the card, moves it to the bottom of the
  /// list, queues it for [scheduledDateIso], and sends a reschedule SMS.
  Future<int> recordDeliveryAttempt({
    required String orderId,
    required String reason,
    String remarks = '',
    bool lockAndQueue = false,
    String? scheduledDateIso,
  }) async {
    final index = orders.indexWhere(
        (o) => o.id == orderId || o.transactionId == orderId);
    if (index == -1) return 0;

    final existing = orders[index];
    final nextAttempt = existing.attemptCount + 1;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final combinedReason = remarks.trim().isNotEmpty
        ? '$reason - ${remarks.trim()}'
        : reason.trim();

    bool smsSent = false;
    if (Get.isRegistered<SmsService>()) {
      if (lockAndQueue && scheduledDateIso != null && scheduledDateIso.isNotEmpty) {
        smsSent = await SmsService.to.sendRescheduleNotification(
          existing,
          scheduledDateLabel: formatDateLabel(scheduledDateIso),
          reason: combinedReason,
          showToast: true,
        );
      } else {
        smsSent = await SmsService.to.sendAttemptNotification(
          existing,
          attemptNumber: nextAttempt,
          reason: combinedReason,
          showToast: true,
        );
      }
    }

    await DatabaseService.to.insertDeliveryAttempt(
      DeliveryAttempt(
        deliveryOrderId: existing.id,
        attemptNumber: nextAttempt,
        reason: reason.trim(),
        remarks: remarks.trim(),
        smsSent: smsSent,
        attemptedAt: nowIso,
        rescheduledDate: lockAndQueue ? scheduledDateIso : null,
      ),
    );

    await DatabaseService.to.updateOrderAttemptState(
      orderId: existing.id,
      attemptCount: nextAttempt,
      lastAttemptReason: combinedReason,
      lastAttemptAt: nowIso,
      isLocked: lockAndQueue ? true : null,
      scheduledDeliveryDate: lockAndQueue ? scheduledDateIso : null,
      lockedAt: lockAndQueue ? nowIso : null,
    );

    orders[index] = existing.copyWith(
      attemptCount: nextAttempt,
      lastAttemptReason: combinedReason,
      lastAttemptAt: nowIso,
      isLocked: lockAndQueue ? true : existing.isLocked,
      scheduledDeliveryDate:
          lockAndQueue ? scheduledDateIso : existing.scheduledDeliveryDate,
      lockedAt: lockAndQueue ? nowIso : existing.lockedAt,
    );
    final sorted = orders.toList();
    _sortOrdersList(sorted);
    orders.assignAll(sorted);
    _recalculateTotals();

    logImportant(
      'Recorded Delivery Attempt #$nextAttempt for #${existing.id} ($combinedReason)${lockAndQueue ? " -> LOCKED & QUEUED for $scheduledDateIso" : ""}',
    );
    return nextAttempt;
  }

  /// Unlocks a deferred/locked order and returns it to normal distance sorting.
  Future<void> unlockOrder(String orderId) async {
    await DatabaseService.to.updateOrderLockState(
      orderId: orderId,
      isLocked: false,
    );
    final index = orders.indexWhere(
        (o) => o.id == orderId || o.transactionId == orderId);
    if (index != -1) {
      orders[index] = orders[index].copyWith(
        isLocked: false,
        clearScheduledDeliveryDate: true,
        clearLockedAt: true,
      );
      final sorted = orders.toList();
      _sortOrdersList(sorted);
      orders.assignAll(sorted);
    }
    logImportant('Unlocked order #$orderId for delivery today');
  }

  /// Updates the rescheduled delivery date on a locked order and notifies customer via SMS.
  Future<void> rescheduleLockedOrder(String orderId, String newDateIso) async {
    final index = orders.indexWhere(
        (o) => o.id == orderId || o.transactionId == orderId);
    if (index == -1) return;
    final existing = orders[index];
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final reason = existing.lastAttemptReason?.trim().isNotEmpty == true
        ? existing.lastAttemptReason!.trim()
        : 'Rescheduled delivery';

    await DatabaseService.to.updateOrderLockState(
      orderId: existing.id,
      isLocked: true,
      scheduledDeliveryDate: newDateIso,
      lockedAt: existing.lockedAt ?? nowIso,
    );

    if (Get.isRegistered<SmsService>()) {
      await SmsService.to.sendRescheduleNotification(
        existing,
        scheduledDateLabel: formatDateLabel(newDateIso),
        reason: reason,
        showToast: true,
      );
    }

    orders[index] = existing.copyWith(
      isLocked: true,
      scheduledDeliveryDate: newDateIso,
      lockedAt: existing.lockedAt ?? nowIso,
    );
    final sorted = orders.toList();
    _sortOrdersList(sorted);
    orders.assignAll(sorted);
    logImportant('Rescheduled locked order #${existing.id} to $newDateIso');
  }

  /// Updates the customer's phone number locally for an order.
  Future<void> updateOrderCustomerPhone(String orderId, String phone) async {
    final cleanPhone = phone.trim();
    await DatabaseService.to.updateOrderCustomerPhone(orderId, cleanPhone);
    final index = orders.indexWhere(
        (o) => o.id == orderId || o.transactionId == orderId);
    if (index != -1) {
      orders[index] = orders[index].copyWith(customerPhone: cleanPhone);
    }
    logImportant('Updated phone for order #$orderId: $cleanPhone');
  }

  /// Persists the generated Paqner payment reference ID on an order so
  /// navigating away and back to the same order preserves the same QR reference.
  Future<void> updateOrderPaymentReference(
    String orderId,
    String paymentReference,
  ) async {
    final cleanRef = paymentReference.trim();
    if (cleanRef.isEmpty) return;
    await DatabaseService.to.updateOrderPaymentReference(orderId, cleanRef);
    final index = orders.indexWhere(
        (o) => o.id == orderId || o.transactionId == orderId);
    if (index != -1) {
      orders[index] = orders[index].copyWith(paymentReference: cleanRef);
    }
  }

  /// Out-for-Delivery orders that have no valid phone number assigned,
  /// so they did not receive the mandatory SMS notification.
  List<DeliveryOrder> get ordersMissingPhone {
    final sms = Get.isRegistered<SmsService>() ? SmsService.to : null;
    return orders.where((o) {
      if (o.status.value != 'Out for Delivery') return false;
      final phone = o.customerPhone.trim();
      if (phone.isEmpty) return true;
      return sms != null && !sms.isValidPhoneNumber(phone);
    }).toList();
  }

  /// Out-for-Delivery orders that have already received the mandatory SMS.
  List<DeliveryOrder> get ordersSmsNotified {
    return orders
        .where((o) =>
            o.status.value == 'Out for Delivery' &&
            o.outForDeliverySmsSentAt?.trim().isNotEmpty == true)
        .toList();
  }

  /// Out-for-Delivery orders that have a valid phone number but have not been
  /// notified yet.
  List<DeliveryOrder> get ordersPendingSmsWithPhone {
    final sms = Get.isRegistered<SmsService>() ? SmsService.to : null;
    return orders.where((o) {
      if (o.status.value != 'Out for Delivery') return false;
      if (o.outForDeliverySmsSentAt?.trim().isNotEmpty == true) return false;
      final phone = o.customerPhone.trim();
      if (phone.isEmpty) return false;
      return sms == null || sms.isValidPhoneNumber(phone);
    }).toList();
  }

  /// Manually sends or re-sends the "Out for Delivery" SMS for an order.
  Future<bool> notifyCustomerOutForDelivery(DeliveryOrder order) async {
    if (!Get.isRegistered<SmsService>()) return false;
    final sent = await SmsService.to.sendOutForDeliveryNotification(
      order,
      showToast: true,
      forceResend: true,
    );
    if (sent) {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final index = orders.indexWhere(
          (o) => o.id == order.id || o.transactionId == order.transactionId);
      if (index != -1) {
        orders[index] =
            orders[index].copyWith(outForDeliverySmsSentAt: nowIso);
      }
    }
    return sent;
  }

  Future<void> syncDeliveries() async {
    isSyncing.value = true;
    isSyncCompleted.value = false;
    syncProgress.value = 0.08;
    syncStatusMessage.value = 'Connecting to dispatch server...';
    logSync('Dashboard triggered route synchronization...');

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
        logImportant('Sync completed: $count delivery orders synced and ready on dashboard!');
        await Future.delayed(const Duration(milliseconds: 1400));
        if (Get.isDialogOpen ?? false) {
          Get.back(); // Close dialog
        }
      } else {
        isSyncing.value = false;
        syncStatusMessage.value = result.message;
        logWarning('Sync finished with notice: ${result.message}');
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
    } catch (e, stack) {
      isSyncing.value = false;
      logError('Sync error in HomeController', e, stack);
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
