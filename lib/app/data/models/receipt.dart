class Receipt {
  final int? id;
  final String deliveryOrderId;
  final String referenceNumber;
  final double totalAmount;
  final String sender;
  final String receiver;
  final String date;
  final String scannedAt;

  Receipt({
    this.id,
    required this.deliveryOrderId,
    required this.referenceNumber,
    required this.totalAmount,
    required this.sender,
    required this.receiver,
    required this.date,
    String? scannedAt,
  }) : scannedAt = scannedAt ?? DateTime.now().toIso8601String();

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
