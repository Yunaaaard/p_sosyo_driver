import 'package:get/get.dart';

class OrderItem {
  final String title;
  final String price;
  final String orderedQty;
  final String totalAmount;

  OrderItem({
    required this.title,
    required this.price,
    required this.orderedQty,
    required this.totalAmount,
  });
}

class OrderDetailsController extends GetxController {
  final RxList<OrderItem> items = <OrderItem>[
    OrderItem(
      title: 'NESCAFE CLASSIC COFFEE REFILL | 170G',
      price: '123.00',
      orderedQty: '23PC',
      totalAmount: '1,839.00',
    ),
    OrderItem(
      title: 'BEAR BRAND STERILIZED MILK 200ML',
      price: '123.00',
      orderedQty: '23PC',
      totalAmount: '1,839.00',
    ),
    OrderItem(
      title: 'READY-TO-DRINK CAPPUCCINO',
      price: '123.00',
      orderedQty: '23PC',
      totalAmount: '1,839.00',
    ),
    OrderItem(
      title: 'SUGARFREE CREAMY WHITE',
      price: '123.00',
      orderedQty: '23PC',
      totalAmount: '1,839.00',
    ),
    OrderItem(
      title: 'NESCAFÉ® ORIGINAL',
      price: '123.00',
      orderedQty: '23PC',
      totalAmount: '1,839.00',
    ),
  ].obs;
}
