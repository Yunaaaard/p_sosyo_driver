import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/constants/app_constants.dart';
import 'package:p_sosyo_driver/app/core/constants/s3_config.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/data/models/pending_transaction.dart';
import 'package:p_sosyo_driver/app/data/providers/api_client.dart';
import 'package:p_sosyo_driver/app/data/providers/api_driver_ds.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/data/services/driver_sync_service.dart';
import 'package:p_sosyo_driver/app/data/services/s3_image_service.dart';

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

  /// Stores a transaction locally and, when online, immediately posts the
  /// order bundle (`delivery_orders`, `order_items`, `receipts`,
  /// `delivery_attempts`) to `post_delivery_orders`.
  ///
  /// If offline or if the server POST fails, stores it with `TranStat.pending`
  /// (`2`) so `getPendings()` retries it later.
  /// Returns `true` if queued for later sync (`TranStat.pending`), `false` if synced.
  Future<bool> recordTransaction({
    required String orderId,
    required String storeName,
    required String actionType,
    required String amount,
    required String summary,
    Map<String, dynamic>? payload,
  }) async {
    final online = await DatabaseService.to.hasInternetConnectivity();
    if (online) {
      final postRes = await _postOrderBundleToServer(
        orderId: orderId,
        actionType: actionType,
        transtat: TranStat.success,
        transactionPayload: payload,
      );

      if (postRes.success) {
        await storeTransaction(
          orderId: orderId,
          storeName: storeName,
          actionType: actionType,
          amount: amount,
          summary: summary,
          transtat: TranStat.success,
          payload: payload,
        );
        await DatabaseService.to.markOrderSynced(orderId);
        logImportant(
          'Synced online transaction #$orderId ($actionType) to post_delivery_orders (transtat=${TranStat.success})',
          tag: 'TXN_SERVICE',
        );
        return false;
      }

      logWarning(
        'Online POST to post_delivery_orders failed for #$orderId (${postRes.message}); queuing as pending.',
        tag: 'TXN_SERVICE',
      );
      await storeTransaction(
        orderId: orderId,
        storeName: storeName,
        actionType: actionType,
        amount: amount,
        summary: summary,
        transtat: TranStat.pending,
        payload: payload,
        lastError: postRes.message,
      );
      return true;
    }

    await storeTransaction(
      orderId: orderId,
      storeName: storeName,
      actionType: actionType,
      amount: amount,
      summary: summary,
      transtat: TranStat.pending,
      payload: payload,
    );
    logWarning(
      'Offline: queued #$orderId ($actionType) with transtat=${TranStat.pending} (${TranStat.label(TranStat.pending)})',
      tag: 'TXN_SERVICE',
    );
    return true;
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
      await _uploadPendingS3Images(pendingTransactions);

      int syncedCount = 0;
      String? lastError;
      final queueSnapshot = pendingTransactions.toList();

      for (final txn in queueSnapshot) {
        final postRes = await _postOrderBundleToServer(
          orderId: txn.orderId,
          actionType: txn.actionType,
          transtat: TranStat.success,
          transactionPayload: txn.decodedPayload,
        );

        if (postRes.success) {
          syncedCount++;
          if (txn.id != null) {
            await DatabaseService.to.updateTransactionStatus(
              txn.id!,
              transtat: TranStat.success,
              status: 'synced',
            );
          }
          await DatabaseService.to.markOrderSynced(txn.orderId);
        } else {
          lastError = postRes.message;
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
              lastError: postRes.message,
              incrementRetry: true,
            );
          }
        }
      }

      if (syncedCount > 0) {
        await DriverSyncService.to.syncAdvanceOrders();
      }
      await refreshTransactions();

      if (syncedCount == queueSnapshot.length) {
        logImportant(
          'TransactionServices synced $syncedCount pending transaction(s) to post_delivery_orders (transtat=${TranStat.success})',
          tag: 'TXN_SERVICE',
        );
        return (
          success: true,
          syncedCount: syncedCount,
          message: '$syncedCount offline transaction(s) synced with server.',
        );
      }

      logWarning(
        'Pending transaction processing partial/paused ($syncedCount/${queueSnapshot.length} synced): ${lastError ?? "Unknown error"}',
        tag: 'TXN_SERVICE',
      );
      return (
        success: false,
        syncedCount: syncedCount,
        message: lastError ??
            'Synced $syncedCount of ${queueSnapshot.length} transaction(s).',
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

  /// Builds the full `delivery_orders` + `order_items` + `receipts` +
  /// `delivery_attempts` payload from SQLite and posts it to `post_delivery_orders`.
  Future<({bool success, String message, dynamic data})>
      _postOrderBundleToServer({
    required String orderId,
    required String actionType,
    required int transtat,
    Map<String, dynamic>? transactionPayload,
  }) async {
    final distCode = await ApiClient.getDistCode();
    final mdCode = await ApiClient.getDriverCode();
    final salesmanCode = await ApiClient.getSalesmanCode();

    final order = await DatabaseService.to.getDeliveryOrderById(orderId);
    final items = await DatabaseService.to.getOrderItems(orderId);
    final receipts = await DatabaseService.to.getReceipts(orderId);
    final attempts = await DatabaseService.to.getDeliveryAttempts(orderId);

    return ApiDriverDs.postDeliveryOrders(
      distCode: distCode,
      mdCode: mdCode,
      salesmanCode: salesmanCode,
      actionType: actionType,
      transtat: transtat,
      deliveryOrder: order?.toMap() ?? {'id': orderId},
      orderItems: items.map((e) => e.toMap()).toList(),
      receipts: receipts.map((r) => r.toMap()).toList(),
      deliveryAttempts: attempts.map((a) => a.toMap()).toList(),
      transactionPayload: transactionPayload,
    );
  }

  /// Uploads any pending local POD `.jpg` photos to S3 when reprocessing the
  /// offline queue.
  Future<void> _uploadPendingS3Images(List<PendingTransaction> txns) async {
    for (final txn in txns) {
      if (txn.actionType != 'DELIVERED') continue;
      final payload = txn.decodedPayload;
      final localPod =
          (payload['localPodPath'] ?? payload['proofOfDeliveryPath'] ?? '')
              .toString()
              .trim();
      final existingPodUrl = (payload['podS3Url'] ?? '').toString().trim();

      if (existingPodUrl.isEmpty &&
          localPod.isNotEmpty &&
          !localPod.startsWith('http') &&
          await File(localPod).exists()) {
        final res = await S3ImageService.to.uploadFilePath(
          filePath: localPod,
          baseFolder: S3Config.podBaseFolder,
          customFilename:
              'pod_${txn.orderId}_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (res.isSuccess && res.url != null) {
          await DatabaseService.to.updateDeliveryOrderStatus(
            txn.orderId,
            'Delivered',
            proofOfDeliveryPath: res.url,
          );
        }
      }
    }
  }
}
