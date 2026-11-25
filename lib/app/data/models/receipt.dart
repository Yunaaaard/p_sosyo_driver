class Receipt {
  final int? id;
  final String deliveryOrderId;
  final String referenceNumber;
  final double totalAmount;
  final String sender;
  final String receiver;
  final String date;
  final String scannedAt;
  final String? customerName;
  final String? proofOfDeliveryPath;
  final String createdAt;

  Receipt({
    this.id,
    required this.deliveryOrderId,
    required this.referenceNumber,
    required this.totalAmount,
    required this.sender,
    required this.receiver,
    required this.date,
    String? scannedAt,
    this.customerName,
    this.proofOfDeliveryPath,
    String? createdAt,
  }) : scannedAt = scannedAt ?? DateTime.now().toIso8601String(),
       createdAt = (createdAt != null && createdAt.trim().isNotEmpty)
           ? createdAt.trim()
           : DateTime.now().toUtc().toIso8601String();

  /// Create a Receipt from a SQLite row map.
  factory Receipt.fromMap(Map<String, dynamic> map) {
    return Receipt(
      id: map['id'] as int?,
      deliveryOrderId: map['delivery_order_id'] as String,
      referenceNumber: map['reference_number'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      sender: map['sender'] as String,
      receiver: map['receiver'] as String,
      date: map['date'] as String,
      scannedAt: map['scanned_at'] as String,
      customerName: map['customer_name']?.toString(),
      proofOfDeliveryPath: (map['s3_proof_of_delivery_path'] ??
              map['proof_of_delivery_path'])
          ?.toString(),
      createdAt: map['created_at']?.toString(),
    );
  }

  /// Convert this Receipt to a SQLite row map.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'delivery_order_id': deliveryOrderId,
      'reference_number': referenceNumber,
      'total_amount': totalAmount,
      'sender': sender,
      'receiver': receiver,
      'date': date,
      'scanned_at': scannedAt,
      'customer_name': customerName,
      's3_proof_of_delivery_path': proofOfDeliveryPath,
      'created_at': createdAt,
    };
  }

  /// Formatted total amount string (e.g. "1,839.00").
  String get formattedTotalAmount {
    final parts = totalAmount.toStringAsFixed(2).split('.');
    final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAllMapped(regExp, (Match m) => ',');
    return parts.join('.');
  }
}
