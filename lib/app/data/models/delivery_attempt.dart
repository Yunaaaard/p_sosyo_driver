/// Represents a single failed or recorded delivery attempt for an order.
class DeliveryAttempt {
  final int? id;
  final String deliveryOrderId;
  final int attemptNumber;
  final String reason;
  final String remarks;
  final bool smsSent;
  final String attemptedAt;
  final String? rescheduledDate;

  DeliveryAttempt({
    this.id,
    required this.deliveryOrderId,
    required this.attemptNumber,
    required this.reason,
    this.remarks = '',
    this.smsSent = false,
    required this.attemptedAt,
    this.rescheduledDate,
  });

  factory DeliveryAttempt.fromMap(Map<String, dynamic> map) {
    return DeliveryAttempt(
      id: map['id'] as int?,
      deliveryOrderId: map['delivery_order_id']?.toString() ?? '',
      attemptNumber: (map['attempt_number'] as num?)?.toInt() ?? 1,
      reason: map['reason']?.toString() ?? '',
      remarks: map['remarks']?.toString() ?? '',
      smsSent: (map['sms_sent'] as num?)?.toInt() == 1,
      attemptedAt: map['attempted_at']?.toString() ?? '',
      rescheduledDate: map['rescheduled_date']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'delivery_order_id': deliveryOrderId,
      'attempt_number': attemptNumber,
      'reason': reason,
      'remarks': remarks,
      'sms_sent': smsSent ? 1 : 0,
      'attempted_at': attemptedAt,
      'rescheduled_date': rescheduledDate,
    };
  }
}
