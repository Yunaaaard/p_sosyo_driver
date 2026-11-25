import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/data/providers/api_client.dart';

class ApiDriverDs {
  static Future<List<Map<dynamic, dynamic>>> getAdvanceOrders({
    required String distCode,
    required String mdCode,
    String? deliveryDate,
    String dynamicRouting = 'Y',
    int status = 8,
  }) async {
    String query = 'get/getAdvanceOrders/v2?distCode=$distCode&mdCode=$mdCode&dynamicRouting=$dynamicRouting&status=$status';
    if (deliveryDate != null && deliveryDate.isNotEmpty) {
      query += '&deliveryDate=$deliveryDate';
    }
    logSync('Fetching Advance Orders: $query', tag: 'API SYNC');
    return await ApiClient.getList(query);
  }

  static Future<List<Map<dynamic, dynamic>>> getAdvanceOrderItems({
    required String distCode,
    required String plateNo,
    String dynamicRouting = 'Y',
    int status = 8,
  }) async {
    final query = 'get/advanceOrderDetails/items/v2?distCode=$distCode&plateNo=$plateNo&dynamicRouting=$dynamicRouting&status=$status';
    logSync('Fetching Advance Order Items: $query', tag: 'API SYNC');
    return await ApiClient.getList(query);
  }

  static Future<List<Map<dynamic, dynamic>>> getDynamicRouteCustomers({
    required String distCode,
    required String mdCode,
    int status = 8,
  }) async {
    final query = 'get/dynamicroute/customers?distCode=$distCode&mdCode=$mdCode&orderType=BTDT-S&plateNo=$mdCode&status=$status';
    logSync('Fetching Customers: $query', tag: 'API SYNC');
    return await ApiClient.getList(query);
  }

  static Future<({bool success, String message, dynamic data})>
      postDeliveryOrders({
    required String distCode,
    required String mdCode,
    required String salesmanCode,
    required String actionType,
    required int transtat,
    required Map<String, dynamic> deliveryOrder,
    required List<Map<String, dynamic>> orderItems,
    required List<Map<String, dynamic>> receipts,
    required List<Map<String, dynamic>> deliveryAttempts,
    Map<String, dynamic>? transactionPayload,
  }) async {
    final body = <String, dynamic>{
      'distCode': distCode,
      'mdCode': mdCode,
      'salesmanCode': salesmanCode,
      'action_type': actionType,
      'transtat': transtat,
      'delivery_order': deliveryOrder,
      'order_items': orderItems,
      'receipts': receipts,
      'delivery_attempts': deliveryAttempts,
      if (transactionPayload != null) 'transaction_payload': transactionPayload,
    };

    logSync(
      'Posting delivery_order #${deliveryOrder['id']} ($actionType) to post_delivery_orders...',
      tag: 'API SYNC',
    );
    return await ApiClient.postJson('post_delivery_orders', body);
  }
}

