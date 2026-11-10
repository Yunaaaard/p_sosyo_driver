import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/models/order_item.dart';
import 'package:p_sosyo_driver/app/data/providers/api_client.dart';
import 'package:p_sosyo_driver/app/data/providers/api_driver_ds.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';

class SyncResult {
  final bool success;
  final String message;
  final int orderCount;
  final int itemCount;

  SyncResult({
    required this.success,
    required this.message,
    this.orderCount = 0,
    this.itemCount = 0,
  });
}

typedef SyncProgressCallback = void Function(double progress, String message);

class DriverSyncService extends GetxService {
  static DriverSyncService get to => Get.find<DriverSyncService>();

  final DatabaseService _dbService = DatabaseService.to;

  /// Sync advance orders and their items from backend API.
  Future<SyncResult> syncAdvanceOrders({SyncProgressCallback? onProgress}) async {
    try {
      debugPrint('[DriverSyncService] Starting sync...');
      onProgress?.call(0.12, 'Connecting to dispatch server...');

      // 1. Resolve Driver Credentials & Settings
      final authenticatedDriver = await _dbService.getAuthenticatedDriver();
      final driverCode = authenticatedDriver?.username ?? await ApiClient.getDriverCode();
      final distCode = await ApiClient.getDistCode();
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      debugPrint('[DriverSyncService] Driver: $driverCode, Dist: $distCode, Date: $todayStr');

      // 2. Fetch Customers for this driver (to enrich names, addresses, coordinates)
      onProgress?.call(0.28, 'Locating store destinations...');
      Map<String, Map<dynamic, dynamic>> customerMap = {};
      try {
        final customers = await ApiDriverDs.getDynamicRouteCustomers(
          distCode: distCode,
          mdCode: driverCode,
        );
        for (final cust in customers) {
          final code = cust['custCode']?.toString();
          if (code != null && code.isNotEmpty) {
            customerMap[code] = cust;
          }
        }
        debugPrint('[DriverSyncService] Fetched ${customerMap.length} customers');
      } catch (e) {
        debugPrint('[DriverSyncService] Note: Failed to fetch customers: $e');
      }

      // 3. Fetch Advance Order Headers
      onProgress?.call(0.55, 'Loading delivery orders & packages...');
      List<Map<dynamic, dynamic>> orderHeaders = [];
      try {
        orderHeaders = await ApiDriverDs.getAdvanceOrders(
          distCode: distCode,
          mdCode: driverCode,
        );
        debugPrint('[DriverSyncService] Fetched ${orderHeaders.length} advance order headers');
      } catch (e) {
        debugPrint('[DriverSyncService] Failed to fetch advance orders: $e');
        return SyncResult(
          success: false,
          message: 'Could not connect to server: $e',
        );
      }

      // 4. Fetch Advance Order Items
      onProgress?.call(0.75, 'Preparing items & product manifests...');
      List<Map<dynamic, dynamic>> orderItemsRaw = [];
      try {
        orderItemsRaw = await ApiDriverDs.getAdvanceOrderItems(
          distCode: distCode,
          plateNo: driverCode,
        );
        debugPrint('[DriverSyncService] Fetched ${orderItemsRaw.length} item lines');
      } catch (e) {
        debugPrint('[DriverSyncService] Note: Failed to fetch advance order items batch: $e');
      }

      // Group items by transactionID
      final Map<String, List<Map<dynamic, dynamic>>> itemsByTxnId = {};
      for (final rawItem in orderItemsRaw) {
        final txnId = rawItem['transactionID']?.toString();
        if (txnId != null && txnId.isNotEmpty) {
          itemsByTxnId.putIfAbsent(txnId, () => []).add(rawItem);
        }
      }

      // 5. If no headers came back from API, return status
      if (orderHeaders.isEmpty) {
        debugPrint('[DriverSyncService] No advance orders returned from server for driver $driverCode.');
        return SyncResult(
          success: true,
          message: 'Sync completed. No new orders found for driver $driverCode.',
          orderCount: 0,
        );
      }

      // 6. Map headers and items to local models
      // Deduplicate order headers by refno so unique orders match dashboard cards exactly
      final Map<String, Map<dynamic, dynamic>> uniqueHeaders = {};
      for (final header in orderHeaders) {
        final refno = (header['refno']?.toString() ?? header['transactionID']?.toString() ?? '').trim();
        if (refno.isNotEmpty) {
          uniqueHeaders[refno] = header;
        }
      }
      final dedupedHeaders = uniqueHeaders.values.toList();

      // Check existing orders in DB to preserve status (e.g. if already Delivered locally)
      final existingOrders = await _dbService.getAllDeliveryOrders();
      final Map<String, String> existingStatuses = {
        for (var o in existingOrders) o.id: o.status.value,
        for (var o in existingOrders) o.transactionId: o.status.value,
      };

      final List<DeliveryOrder> ordersToSave = [];
      final List<OrderItem> itemsToSave = [];

      for (int i = 0; i < dedupedHeaders.length; i++) {
        final header = dedupedHeaders[i];
        final txnId = header['transactionID']?.toString() ?? 'TXN-${i + 1}';
        final refno = header['refno']?.toString() ?? txnId;
        final custCode = (header['custCode']?.toString() ??
                header['STOREID']?.toString() ??
                header['customerCode']?.toString() ??
                header['cID']?.toString() ??
                '')
            .trim();
        final cust = customerMap[custCode];

        // Resolve store photo URL for this customer
        String storePhotoUrl = '';
        if (custCode.isNotEmpty) {
          storePhotoUrl =
              'https://filezsystem.sgp1.vultrobjects.com/STOREIMAGE/MNC/$distCode/${custCode.toLowerCase()}_1.jpg';
        }

        final storeName = (header['STORENAME']?.toString() ??
                cust?['custName']?.toString() ??
                header['storeName']?.toString() ??
                header['custName']?.toString() ??
                'Store ($custCode)')
            .trim();
        final address = (cust?['address']?.toString() ??
                header['address']?.toString() ??
                'Store Address')
            .trim();
        final lat = cust?['latitude'] != null
            ? double.tryParse(cust!['latitude'].toString())
            : double.tryParse(header['latitude']?.toString() ?? '');
        final lng = cust?['longitude'] != null
            ? double.tryParse(cust!['longitude'].toString())
            : double.tryParse(header['longitude']?.toString() ?? '');

        // Items for this order: either from separate items endpoint or embedded in header
        List<Map<dynamic, dynamic>> txnItems = itemsByTxnId[txnId] ?? [];
        if (txnItems.isEmpty && header['ADVANCE_ORDER_DETAILS'] is List) {
          txnItems = List<Map<dynamic, dynamic>>.from(header['ADVANCE_ORDER_DETAILS']);
        }

        // Map items
        double computedTotalAmount = 0.0;
        for (final rawItem in txnItems) {
          final stockCode = rawItem['stockCode']?.toString() ?? '';
          final title = (rawItem['PRODUCTDESCRIPTION']?.toString() ??
                  rawItem['Description']?.toString() ??
                  rawItem['productDes']?.toString() ??
                  rawItem['sosyoItemName']?.toString() ??
                  rawItem['title']?.toString() ??
                  'Item $stockCode')
              .trim();
          final price = double.tryParse(rawItem['piecePrice']?.toString() ??
                  rawItem['piecePrice_Gross']?.toString() ??
                  '0') ??
              0.0;
          final qty = rawItem['quantity'] ??
              rawItem['po'] ??
              rawItem['quantityOrdered'] ??
              rawItem['QUANTITY ORDERED IN PCS'] ??
              1;
          final uom = (rawItem['PurchaseUom']?.toString() ??
                  rawItem['uom']?.toString() ??
                  rawItem['unit']?.toString() ??
                  'PC')
              .trim();
          final itemTotal = double.tryParse(rawItem['totalAmount']?.toString() ?? '') ??
              (price * (double.tryParse(qty.toString()) ?? 1.0));
          computedTotalAmount += itemTotal;

          itemsToSave.add(
            OrderItem(
              deliveryOrderId: refno,
              stockCode: stockCode,
              title: title,
              price: price,
              orderedQty: '$qty',
              totalAmount: itemTotal,
              uom: uom,
            ),
          );
        }

        final headerAmount = double.tryParse(header['totalAmount']?.toString() ?? '');
        final finalTotalAmount = headerAmount ?? computedTotalAmount;

        // Preserve 'Delivered' if already marked locally
        final existingStatus = existingStatuses[refno] ?? existingStatuses[txnId];
        final status = existingStatus ?? 'Out for Delivery';

        final parts = finalTotalAmount.toStringAsFixed(2).split('.');
        final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
        parts[0] = parts[0].replaceAllMapped(regExp, (Match m) => ',');
        final formattedAmount = '₱ ${parts.join('.')}';

        ordersToSave.add(
          DeliveryOrder(
            id: refno,
            transactionId: txnId,
            custCode: custCode,
            storePhoto: storePhotoUrl,
            storeName: storeName,
            address: address,
            distance: 'Ready',
            sku: txnItems.isNotEmpty ? txnItems.length.toString() : (header['sku_count']?.toString() ?? '1'),
            totalAmount: formattedAmount,
            status: status,
            deliveryDate: header['unloadingDate']?.toString() ?? header['deliveryDate']?.toString() ?? todayStr,
            latitude: lat,
            longitude: lng,
          ),
        );
      }

      // 7. Save batch to SQLite
      onProgress?.call(0.92, 'Updating offline database & items...');
      await _dbService.saveDeliveryOrdersBatch(ordersToSave);
      if (itemsToSave.isNotEmpty) {
        await _dbService.saveOrderItemsBatch(itemsToSave);
      }

      onProgress?.call(1.0, 'Dispatch ready! Orders updated.');
      debugPrint('[DriverSyncService] Successfully synced ${ordersToSave.length} orders & ${itemsToSave.length} items.');
      return SyncResult(
        success: true,
        message: 'Sync completed successfully.',
        orderCount: ordersToSave.length,
        itemCount: itemsToSave.length,
      );
    } catch (e, stack) {
      debugPrint('[DriverSyncService] Unexpected error: $e\n$stack');
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
      );
    }
  }
}

