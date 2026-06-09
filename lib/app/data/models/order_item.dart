class OrderItem {
  final int? id;
  final String deliveryOrderId;
  final String title;
  final double price;
  final String orderedQty;
  final double totalAmount;
  final String createdAt;

  OrderItem({
    this.id,
    required this.deliveryOrderId,
    required this.title,
    required this.price,
    required this.orderedQty,
    double? totalAmount,
    String? createdAt,
  })  : totalAmount = price * _parseQty(orderedQty),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  static int _parseQty(String qtyStr) {
    final match = RegExp(r'\d+').stringMatch(qtyStr);
    return match != null ? int.parse(match) : 0;
  }

  /// Create an OrderItem from a SQLite row map.
  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      deliveryOrderId: map['delivery_order_id'] as String,
      title: map['title'] as String,
      price: (map['price'] as num).toDouble(),
      orderedQty: map['ordered_qty'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      createdAt: map['created_at'] as String,
    );
  }

  /// Convert this OrderItem to a SQLite row map.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'delivery_order_id': deliveryOrderId,
      'title': title,
      'price': price,
      'ordered_qty': orderedQty,
      'total_amount': totalAmount,
      'created_at': createdAt,
    };
  }

  /// Formatted price string (e.g. "123.00").
  String get formattedPrice => price.toStringAsFixed(2);

  /// Formatted total amount string (e.g. "1,839.00").
  String get formattedTotalAmount {
    final parts = totalAmount.toStringAsFixed(2).split('.');
    final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAllMapped(regExp, (Match m) => ',');
    return parts.join('.');
  }
}
