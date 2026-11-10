import 'package:flutter/foundation.dart';
import 'package:p_sosyo_driver/app/data/providers/api_client.dart';

class ApiDriverDs {
  /// Fetch Advance Order headers for the driver
  /// Matches RavaMate `ApiDs.getAdvanceOrders`
  static Future<List<Map<dynamic, dynamic>>> getAdvanceOrders({
    required String distCode,
    required String mdCode,
    required String deliveryDate,
    String dynamicRouting = 'Y',
    int status = 8,
  }) async {
    final query = 'get/getAdvanceOrders/v2?distCode=$distCode&mdCode=$mdCode&deliveryDate=$deliveryDate&dynamicRouting=$dynamicRouting&status=$status';
    debugPrint('[ApiDriverDs] Fetching Advance Orders: $query');
    return await ApiClient.getList(query);
  }

  /// Fetch Advance Order items batch
  /// Matches RavaMate `ApiDs.getAdvanceOrderItems`
  static Future<List<Map<dynamic, dynamic>>> getAdvanceOrderItems({
    required String distCode,
    required String plateNo,
    String dynamicRouting = 'Y',
    int status = 8,
  }) async {
    final query = 'get/advanceOrderDetails/items/v2?distCode=$distCode&plateNo=$plateNo&dynamicRouting=$dynamicRouting&status=$status';
    debugPrint('[ApiDriverDs] Fetching Advance Order Items: $query');
    return await ApiClient.getList(query);
  }

  /// Fetch Dynamic Route customers (store names, coordinates, addresses)
  /// Matches RavaMate `ApiDs.getDynamicRouteCustomers`
  static Future<List<Map<dynamic, dynamic>>> getDynamicRouteCustomers({
    required String distCode,
    required String mdCode,
    int status = 8,
  }) async {
    final query = 'get/dynamicroute/customers?distCode=$distCode&mdCode=$mdCode&orderType=BTDT-S&plateNo=$mdCode&status=$status';
    debugPrint('[ApiDriverDs] Fetching Customers: $query');
    return await ApiClient.getList(query);
  }
}

