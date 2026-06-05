import 'package:get/get.dart';

class DeliveryOrder {
  final String id;
  final String storeName;
  final String address;
  final String distance;
  final String sku;
  final String totalAmount;
  final RxString status;

  DeliveryOrder({
    required this.id,
    required this.storeName,
    required this.address,
    required this.distance,
    required this.sku,
    required this.totalAmount,
    required String status,
  }) : status = status.obs;
}
