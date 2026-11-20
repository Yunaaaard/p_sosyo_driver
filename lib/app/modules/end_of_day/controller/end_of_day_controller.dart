import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/services/bluetooth_printer_service.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';

class EndOfDayController extends GetxController {
  final RxBool isLoading = true.obs;
  final RxBool isEndOfDayDone = false.obs;
  final RxString completedAtLabel = ''.obs;
  final RxString driverName = 'Driver'.obs;
  final RxString dateLabel = ''.obs;

  final RxInt totalStops = 0.obs;
  final RxInt deliveredCount = 0.obs;
  final RxInt remainingUnlockedCount = 0.obs;
  final RxInt queuedLockedCount = 0.obs;
  final RxInt cancelledCount = 0.obs;

  final RxDouble targetAmount = 0.0.obs;
  final RxDouble collectedAmount = 0.0.obs;
  final RxDouble queuedAmount = 0.0.obs;
  final RxDouble cancelledAmount = 0.0.obs;
  final RxDouble pendingAmount = 0.0.obs;
  final RxDouble averageDropValue = 0.0.obs;

  final RxInt podCapturedCount = 0.obs;
  final RxInt totalAttemptsCount = 0.obs;
  final RxInt smsSentCount = 0.obs;
  final RxMap<String, int> cancellationReasonCounts = <String, int>{}.obs;

  DateTime get _philippineNow =>
      DateTime.now().toUtc().add(const Duration(hours: 8));

  String get _todayIso {
    final now = _philippineNow;
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String get _eodPrefKey => 'eod_completed_$_todayIso';

  double get completionRate =>
      totalStops.value > 0 ? (deliveredCount.value / totalStops.value) : 0.0;

  @override
  void onInit() {
    super.onInit();
    loadEndOfDayOverview();
  }

  Future<void> loadEndOfDayOverview() async {
    isLoading.value = true;
    try {
      final db = DatabaseService.to;
      final prefs = await SharedPreferences.getInstance();
      final driver = await db.getAuthenticatedDriver();
      driverName.value = (driver?.fullName.trim().isNotEmpty == true)
          ? driver!.fullName.trim()
          : (driver?.username ?? 'Driver');
      dateLabel.value = _formatPhilippineDateTime(_philippineNow);

      final completedTimestamp = prefs.getString(_eodPrefKey);
      if (completedTimestamp != null && completedTimestamp.isNotEmpty) {
        isEndOfDayDone.value = true;
        completedAtLabel.value = completedTimestamp;
      } else {
        isEndOfDayDone.value = false;
        completedAtLabel.value = '';
      }

      final List<DeliveryOrder> orders = await db.getAllDeliveryOrders();
      final attempts = await db.getAllDeliveryAttempts();

      int delivered = 0;
      int remainingUnlocked = 0;
      int queuedLocked = 0;
      int cancelled = 0;
      int podCount = 0;
      int smsNotifiedCount = 0;

      double target = 0.0;
      double collected = 0.0;
      double queued = 0.0;
      double cancelledAmt = 0.0;
      double pending = 0.0;

      final Map<String, int> cancelReasons = {};

      for (final o in orders) {
        final amt = o.numericTotalAmount;
        target += amt;
        final status = o.status.value.trim();

        if (o.outForDeliverySmsSentAt?.trim().isNotEmpty == true) {
          smsNotifiedCount++;
        }

        if (status == 'Delivered') {
          delivered++;
          collected += amt;
          if (o.proofOfDeliveryPath?.trim().isNotEmpty == true) {
            podCount++;
          }
        } else if (status == 'Cancelled') {
          cancelled++;
          cancelledAmt += amt;
          final reason = (o.cancellationReason?.trim().isNotEmpty == true)
              ? o.cancellationReason!.trim()
              : 'Unspecified';
          cancelReasons[reason] = (cancelReasons[reason] ?? 0) + 1;
        } else if (o.isLocked) {
          queuedLocked++;
          queued += amt;
          pending += amt;
        } else {
          remainingUnlocked++;
          pending += amt;
        }
      }

      for (final a in attempts) {
        if (a.smsSent) smsNotifiedCount++;
      }

      totalStops.value = orders.length;
      deliveredCount.value = delivered;
      remainingUnlockedCount.value = remainingUnlocked;
      queuedLockedCount.value = queuedLocked;
      cancelledCount.value = cancelled;

      targetAmount.value = target;
      collectedAmount.value = collected;
      queuedAmount.value = queued;
      cancelledAmount.value = cancelledAmt;
      pendingAmount.value = pending;
      averageDropValue.value = delivered > 0 ? (collected / delivered) : 0.0;

      podCapturedCount.value = podCount;
      totalAttemptsCount.value = attempts.length;
      smsSentCount.value = smsNotifiedCount;
      cancellationReasonCounts.assignAll(cancelReasons);

      logImportant(
        'Loaded EOD overview: $delivered/${orders.length} delivered | Collected ₱${collected.toStringAsFixed(2)}',
        tag: 'EOD',
      );
    } catch (e, stack) {
      logError('Error loading End of Day overview', e, stack);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> confirmEndOfDay() async {
    if (isEndOfDayDone.value) return;

    if (remainingUnlockedCount.value > 0) {
      final proceed = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Unfinished Stops Remaining'),
          content: Text(
            'You still have ${remainingUnlockedCount.value} unlocked "Out for Delivery" ${remainingUnlockedCount.value == 1 ? 'stop' : 'stops'}. Would you like to close your route anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Go Back'),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Confirm Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final nowPht = _philippineNow;
    final timeStr = _formatPhilippineTime(nowPht);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eodPrefKey, timeStr);

    isEndOfDayDone.value = true;
    completedAtLabel.value = timeStr;
    dateLabel.value = _formatPhilippineDateTime(nowPht);

    logImportant(
      'End of Day confirmed for $_todayIso at $timeStr (${deliveredCount.value}/${totalStops.value} stops)',
      tag: 'EOD',
    );

    Get.snackbar(
      'End of Day Completed',
      'Route summary for ${dateLabel.value} has been finalized.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFE8F5E9),
      colorText: const Color(0xFF15803D),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
    );
  }

  Future<bool> printEndOfDaySummary() async {
    if (!Get.isRegistered<BluetoothPrinterService>()) return false;
    final nowLabel = _formatPhilippineDateTime(_philippineNow);
    dateLabel.value = nowLabel;
    return await BluetoothPrinterService.to.printEndOfDaySummary(
      driverName: driverName.value,
      dateLabel: nowLabel,
      totalStops: totalStops.value,
      deliveredCount: deliveredCount.value,
      remainingCount: remainingUnlockedCount.value,
      queuedCount: queuedLockedCount.value,
      cancelledCount: cancelledCount.value,
      collectedAmount: collectedAmount.value,
      targetAmount: targetAmount.value,
      pendingAmount: pendingAmount.value,
      podCount: podCapturedCount.value,
      attemptCount: totalAttemptsCount.value,
    );
  }

  String _formatPhilippineTime(DateTime dt) {
    final hour24 = dt.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final min = dt.minute.toString().padLeft(2, '0');
    return '${hour12.toString().padLeft(2, '0')}:$min $period PHT';
  }

  String _formatPhilippineDateTime(DateTime dt) {
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · ${_formatPhilippineTime(dt)}';
  }
}
