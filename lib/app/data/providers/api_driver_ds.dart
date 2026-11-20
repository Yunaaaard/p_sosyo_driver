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
}

