import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/constants/app_constants.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/data/models/pending_transaction.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/data/services/driver_sync_service.dart';

/// Centralized transaction storage & offline queue manager modeled after
/// Ravamate / SFAplus `TransactionServices`.
///
/// Tracks every driver transaction with `TranStat`:
/// - `TranStat.success` (`0`)
/// - `TranStat.failed` (`1`)
/// - `TranStat.pending` (`2`)
class TransactionServices extends GetxService {
  static TransactionServices get to => Get.isRegistered<TransactionServices>()
      ? Get.find<TransactionServices>()
      : Get.put(TransactionServices());

  static const int maxRetryAttempts = 5;

  final RxList<PendingTransaction> transactions = <PendingTransaction>[].obs;
  final RxList<PendingTransaction> pendingTransactions =
      <PendingTransaction>[].obs;
  final RxInt pendingCount = 0.obs;
  final RxBool isProcessing = false.obs;

  bool _isInitialized = false;
  Future<void>? _initializing;

  @override
  void onInit() {
    super.onInit();
    init();
  }

  /// Main initializer matching Ravamate's `TransactionServices.init()`.
  Future<void> init() async {
    if (_initializing != null) return _initializing!;
    if (_isInitialized) {
      logInfo('TransactionServices already initialized.', tag: 'TXN_SERVICE');
      return;
    }
    _isInitialized = true;
    _initializing = _initializeInternal();
    await _initializing;
    _initializing = null;
  }

  Future<void> _initializeInternal() async {
    try {
      logSync('TransactionServices initialization started...', tag: 'TXN_SERVICE');
      await refreshTransactions();
      logImportant(
        'TransactionServices ready (${transactions.length} total, ${pendingCount.value} pending)',
        tag: 'TXN_SERVICE',
      );
    } catch (e, stack) {
      logError('TransactionServices init error', e, stack);
    }
  }

  /// Reloads all stored transactions and pending counts from SQLite.
  Future<void> refreshTransactions() async {
    try {
      final all = await DatabaseService.to.getAllTransactions();
      final pending = await DatabaseService.to.getPendingTransactions();
      transactions.assignAll(all);
      pendingTransactions.assignAll(pending);
      pendingCount.value = pending.length;
    } catch (e, stack) {
      logError('Failed to refresh transactions', e, stack);
    }
  }

  /// Stores a transaction locally and queues it as `TranStat.pending` (`2`)
  /// when offline, or `TranStat.success` (`0`) when online.
  ///
  /// Returns `true` if queued offline (`TranStat.pending`), `false` if online.
  Future<bool> recordTransaction({
    required String orderId,
    required String storeName,
    required String actionType,
    required String amount,
    required String summary,
    Map<String, dynamic>? payload,
  }) async {
    final queuedOffline =
        await DatabaseService.to.queueOfflineTransactionIfDisconnected(
      orderId: orderId,
      storeName: storeName,
      actionType: actionType,
      amount: amount,
      summary: summary,
      payload: payload,
    );

    if (queuedOffline) {
      logWarning(
        'Stored offline transaction #$orderId ($actionType) with transtat=${TranStat.pending} (${TranStat.label(TranStat.pending)})',
        tag: 'TXN_SERVICE',
      );
    } else {
      logImportant(
        'Stored online transaction #$orderId ($actionType) with transtat=${TranStat.success} (${TranStat.label(TranStat.success)})',
        tag: 'TXN_SERVICE',
      );
    }

    await refreshTransactions();
    return queuedOffline;
  }

  /// Directly stores a transaction record with an explicit `TranStat` value.
  Future<int> storeTransaction({
    required String orderId,
    required String storeName,
    required String actionType,
    required String amount,
    required String summary,
    int transtat = TranStat.pending,
    Map<String, dynamic>? payload,
    String? lastError,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final statusStr = transtat == TranStat.success
        ? 'synced'
        : transtat == TranStat.failed
            ? 'failed'
            : 'pending';

    final id = await DatabaseService.to.insertTransaction(
      PendingTransaction(
        orderId: orderId,
        storeName: storeName,
        actionType: actionType,
        amount: amount,
        summary: summary,
        payloadJson: jsonEncode(payload ?? <String, dynamic>{}),
        status: statusStr,
        transtat: transtat,
        createdAt: nowIso,
        syncedAt: transtat == TranStat.success ? nowIso : null,
        lastError: lastError,
      ),
    );
    await refreshTransactions();
    return id;
  }

  /// Processes all pending transactions (`TranStat.pending` == 2), matching
  /// Ravamate's `getPendings()` queue processor.
  Future<({bool success, int syncedCount, String message})> getPendings() async {
    if (isProcessing.value) {
      return (
        success: false,
        syncedCount: 0,
        message: 'Transaction sync already in progress.',
      );
    }

    isProcessing.value = true;
    try {
      await refreshTransactions();
      if (pendingTransactions.isEmpty) {
        logInfo('No pending transactions to send.', tag: 'TXN_SERVICE');
        return (
          success: true,
          syncedCount: 0,
          message: 'No pending transactions.',
        );
      }

      final online = await DatabaseService.to.hasInternetConnectivity();
      if (!online) {
        logWarning(
          'Offline: ${pendingTransactions.length} pending transaction(s) remain queued.',
          tag: 'TXN_SERVICE',
        );
        return (
          success: false,
          syncedCount: 0,
          message:
              'No internet connection detected. Transactions remain safely queued.',
        );
      }

      logSync(
        'Processing ${pendingTransactions.length} pending transaction(s)...',
        tag: 'TXN_SERVICE',
      );
      final result = await DriverSyncService.to.syncAdvanceOrders();
      if (result.success) {
        final count = pendingTransactions.length;
        await DatabaseService.to.markAllPendingTransactionsSynced();
        await refreshTransactions();
        logImportant(
          'TransactionServices synced $count pending transaction(s) (transtat=${TranStat.success})',
          tag: 'TXN_SERVICE',
        );
        return (
          success: true,
          syncedCount: count,
          message: '$count offline transaction(s) synced with dispatch.',
        );
      }

      for (final txn in pendingTransactions) {
        if (txn.id != null) {
          final nextRetry = txn.retryCount + 1;
          final nextTranStat = nextRetry >= maxRetryAttempts
              ? TranStat.failed
              : TranStat.pending;
          final nextStatus =
              nextTranStat == TranStat.failed ? 'failed' : 'pending';
          await DatabaseService.to.updateTransactionStatus(
            txn.id!,
            transtat: nextTranStat,
            status: nextStatus,
            lastError: result.message,
            incrementRetry: true,
          );
        }
      }
      await refreshTransactions();
      logWarning(
        'Pending transaction processing paused: ${result.message}',
        tag: 'TXN_SERVICE',
      );
      return (
        success: false,
        syncedCount: 0,
        message: result.message,
      );
    } catch (e, stack) {
      logError('Error during TransactionServices.getPendings', e, stack);
      return (
        success: false,
        syncedCount: 0,
        message: 'Failed to process pending transactions: $e',
      );
    } finally {
      isProcessing.value = false;
    }
  }
}
