import 'dart:convert';

import 'package:p_sosyo_driver/app/core/constants/app_constants.dart';

class PendingTransaction {
  final int? id;
  final String orderId;
  final String storeName;
  final String actionType;
  final String amount;
  final String summary;
  final String payloadJson;
  final String status; // 'pending' | 'synced' | 'failed'
  final int transtat; // TranStat: 0 = success, 1 = failed, 2 = pending
  final String createdAt;
  final String? syncedAt;
  final int retryCount;
  final String? lastError;

  const PendingTransaction({
    this.id,
    required this.orderId,
    required this.storeName,
    required this.actionType,
    required this.amount,
    required this.summary,
    this.payloadJson = '{}',
    this.status = 'pending',
    this.transtat = TranStat.pending,
    required this.createdAt,
    this.syncedAt,
    this.retryCount = 0,
    this.lastError,
  });

  factory PendingTransaction.fromMap(Map<String, dynamic> map) {
    final rawStatus = map['status']?.toString() ?? 'pending';
    final rawTranstat = (map['transtat'] as num?)?.toInt() ??
        (rawStatus == 'synced'
            ? TranStat.success
            : rawStatus == 'failed'
                ? TranStat.failed
                : TranStat.pending);
    return PendingTransaction(
      id: (map['id'] as num?)?.toInt(),
      orderId: map['order_id']?.toString() ?? '',
      storeName: map['store_name']?.toString() ?? '',
      actionType: map['action_type']?.toString() ?? 'TRANSACTION',
      amount: map['amount']?.toString() ?? '₱ 0.00',
      summary: map['summary']?.toString() ?? '',
      payloadJson: map['payload_json']?.toString() ?? '{}',
      status: rawStatus,
      transtat: rawTranstat,
      createdAt: map['created_at']?.toString() ?? '',
      syncedAt: map['synced_at']?.toString(),
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
      lastError: map['last_error']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'order_id': orderId,
      'store_name': storeName,
      'action_type': actionType,
      'amount': amount,
      'summary': summary,
      'payload_json': payloadJson,
      'status': status,
      'transtat': transtat,
      'created_at': createdAt,
      'synced_at': syncedAt,
      'retry_count': retryCount,
      'last_error': lastError,
    };
  }

  Map<String, dynamic> get decodedPayload {
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return <String, dynamic>{};
  }
}
