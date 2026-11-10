class OrderItem {
  final int? id;
  final String deliveryOrderId;
  final String stockCode;
  final String title;
  final double price;
  final String orderedQty;
  final double totalAmount;
  final String uom;
  final String createdAt;

  OrderItem({
    this.id,
    required this.deliveryOrderId,
    String? stockCode,
    required this.title,
    required this.price,
    required this.orderedQty,
    double? totalAmount,
    String? uom,
    String? createdAt,
  })  : stockCode = stockCode ?? '',
        uom = uom ?? 'PC',
        totalAmount = totalAmount ?? (price * _parseQty(orderedQty)),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  static int _parseQty(String qtyStr) {
    final match = RegExp(r'\d+').stringMatch(qtyStr);
    return match != null ? int.parse(match) : 0;
  }

  String get formattedPrice {
    final parts = price.toStringAsFixed(2).split('.');
    final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAllMapped(regExp, (Match m) => ',');
    return '₱ ${parts.join('.')}';
  }

  String get formattedTotalAmount {
    final parts = totalAmount.toStringAsFixed(2).split('.');
    final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAllMapped(regExp, (Match m) => ',');
    return '₱ ${parts.join('.')}';
  }

  /// Clean display string for quantity, preventing duplicated UOMs like "2 BG BG" or "2BG BG"
  String get displayQty {
    final qtyStr = orderedQty.trim();
    final uomStr = uom.trim();
    if (uomStr.isEmpty) return qtyStr;
    String cleanQty = qtyStr
        .replaceAll(RegExp(RegExp.escape(uomStr), caseSensitive: false), '')
        .trim();
    if (cleanQty.isEmpty) {
      final digits = RegExp(r'\d+(\.\d+)?').stringMatch(qtyStr);
      cleanQty = digits ?? '1';
    }
    return '$cleanQty $uomStr';
  }

  /// Create an OrderItem from a SQLite row map.
  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      deliveryOrderId: map['delivery_order_id']?.toString() ?? '',
      stockCode: map['stock_code']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      orderedQty: map['ordered_qty']?.toString() ?? '0',
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      uom: map['uom']?.toString() ?? 'PC',
      createdAt: map['created_at']?.toString() ?? '',
    );
  }

  /// Convert this OrderItem to a SQLite row map.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'delivery_order_id': deliveryOrderId,
      'stock_code': stockCode,
      'title': title,
      'price': price,
      'ordered_qty': orderedQty,
      'total_amount': totalAmount,
      'uom': uom,
      'created_at': createdAt,
    };
  }
}
