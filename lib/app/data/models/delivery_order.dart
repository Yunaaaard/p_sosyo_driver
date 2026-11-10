import 'package:get/get.dart';

class DeliveryOrder {
  final String id;
  final String transactionId;
  final String storeName;
  final String address;
  final String distance;
  final String sku;
  final String totalAmount;
  final RxString status;
  final String deliveryDate;
  final double? latitude;
  final double? longitude;

  DeliveryOrder({
    required this.id,
    String? transactionId,
    required this.storeName,
    required this.address,
    required this.distance,
    required this.sku,
    required this.totalAmount,
    required String status,
    String? deliveryDate,
    this.latitude,
    this.longitude,
  })  : transactionId = transactionId ?? id,
        deliveryDate = deliveryDate ?? '',
        status = status.obs;

  factory DeliveryOrder.fromMap(Map<String, dynamic> map) {
    return DeliveryOrder(
      id: map['id'].toString(),
      transactionId: map['transaction_id']?.toString() ?? map['id'].toString(),
      storeName: map['store_name']?.toString() ?? 'Store',
      address: map['address']?.toString() ?? '',
      distance: map['distance']?.toString() ?? '',
      sku: map['sku_count']?.toString() ?? '0',
      totalAmount: map['total_amount'] is num
          ? '₱ ${(map['total_amount'] as num).toStringAsFixed(2)}'
          : (map['total_amount']?.toString() ?? '₱ 0.00'),
      status: map['status']?.toString() ?? 'Out for Delivery',
      deliveryDate: map['delivery_date']?.toString() ?? '',
      latitude: map['latitude'] != null ? double.tryParse(map['latitude'].toString()) : null,
      longitude: map['longitude'] != null ? double.tryParse(map['longitude'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    final cleanAmountStr = totalAmount
        .replaceAll('₱', '')
        .replaceAll(',', '')
        .trim();
    final amountNum = double.tryParse(cleanAmountStr) ?? 0.0;
    final skuNum = int.tryParse(sku) ?? 0;

    return {
      'id': id,
      'transaction_id': transactionId,
      'store_name': storeName,
      'address': address,
      'distance': distance,
      'sku_count': skuNum,
      'total_amount': amountNum,
      'status': status.value,
      'delivery_date': deliveryDate,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
