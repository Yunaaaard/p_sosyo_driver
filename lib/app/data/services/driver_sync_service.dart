import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/core/utils/location_helper.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/models/order_item.dart';
import 'package:p_sosyo_driver/app/data/providers/api_client.dart';
import 'package:p_sosyo_driver/app/data/providers/api_driver_ds.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/data/services/sms_service.dart';

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
      logSync('Initiating advance order sync for dispatch...');
      onProgress?.call(0.12, 'Connecting to dispatch server...');

      // 1. Resolve Driver Credentials & Settings
      final authenticatedDriver = await _dbService.getAuthenticatedDriver();
      final driverCode = authenticatedDriver?.username ?? await ApiClient.getDriverCode();
      final distCode = await ApiClient.getDistCode();
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      logImportant('Syncing Route for Driver: $driverCode | Dist: $distCode | Date: $todayStr');

      // 2. Fetch Customers for this driver (to enrich names, addresses, coordinates)
      onProgress?.call(0.28, 'Locating store destinations...');
      Map<String, Map<dynamic, dynamic>> customerMap = {};
      try {
        final customers = await ApiDriverDs.getDynamicRouteCustomers(
          distCode: distCode,
          mdCode: driverCode,
        );
        for (final cust in customers) {
          final code = (cust['custCode'] ??
                  cust['CUSTCODE'] ??
                  cust['customerCode'] ??
                  '')
              .toString()
              .trim();
          if (code.isNotEmpty) {
            customerMap[code] = cust;
            customerMap[code.toUpperCase()] = cust;
          }
        }
        logSync('Fetched ${customerMap.length} dynamic route customers');
      } catch (e) {
        logWarning('Note: Failed to fetch customers: $e');
      }

      // 3. Fetch Advance Order Headers
      onProgress?.call(0.55, 'Loading delivery orders & packages...');
      List<Map<dynamic, dynamic>> orderHeaders = [];
      try {
        orderHeaders = await ApiDriverDs.getAdvanceOrders(
          distCode: distCode,
          mdCode: driverCode,
        );
        logSync('Fetched ${orderHeaders.length} advance order headers from server');
      } catch (e) {
        logError('Failed to fetch advance orders from server', e);
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
        logSync('Fetched ${orderItemsRaw.length} item line details');
      } catch (e) {
        logWarning('Note: Failed to fetch advance order items batch: $e');
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
        logImportant('No advance orders returned from server for driver $driverCode.');
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
      logImportant('Deduplicated headers: ${dedupedHeaders.length} unique orders from ${orderHeaders.length} raw headers');

      // Check existing orders in DB to preserve status, deliveredAt, and paymentReference
      final existingOrders = await _dbService.getAllDeliveryOrders();
      final Map<String, DeliveryOrder> existingOrderMap = {
        for (var o in existingOrders) o.id: o,
        for (var o in existingOrders) o.transactionId: o,
      };

      final List<DeliveryOrder> ordersToSave = [];
      final List<OrderItem> itemsToSave = [];
      final driverCoords = await LocationHelper.getCurrentDriverLocation();

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
        final cust =
            customerMap[custCode] ?? customerMap[custCode.toUpperCase()];

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
        double? rawLat = _parseCoord(
          cust?['latitude'] ??
              cust?['latitudeNew'] ??
              cust?['LATITUDE'] ??
              header['latitude'] ??
              header['LATITUDE'] ??
              header['lat'],
        );
        double? rawLng = _parseCoord(
          cust?['longitude'] ??
              cust?['longitudeNew'] ??
              cust?['LONGITUDE'] ??
              header['longitude'] ??
              header['LONGITUDE'] ??
              header['lng'] ??
              header['lon'],
        );
        if (!LocationHelper.isValidCoordinate(rawLat, rawLng)) {
          final geo = (cust?['geolocation'] ?? header['geolocation'] ?? '')
              .toString()
              .trim();
          if (geo.contains(',')) {
            final parts = geo.split(',');
            rawLat = double.tryParse(parts[0].trim());
            rawLng = double.tryParse(parts[1].trim());
          }
        }
        final resolvedCoords = LocationHelper.resolveOrderCoordinates(
          seedKey: custCode.isNotEmpty ? custCode : refno,
          rawLat: rawLat,
          rawLng: rawLng,
        );
        final lat = resolvedCoords.latitude;
        final lng = resolvedCoords.longitude;
        final distanceKm = LocationHelper.calculateDistanceKm(
          startLat: driverCoords.latitude,
          startLng: driverCoords.longitude,
          endLat: lat,
          endLng: lng,
        );
        final distanceLabel = LocationHelper.formatDistanceKmAway(distanceKm);

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
          final category = (rawItem['mainCategory']?.toString() ??
                  rawItem['CATEGORY']?.toString() ??
                  rawItem['category']?.toString() ??
                  'BEVERAGE')
              .trim();
          final itemTotal = double.tryParse(rawItem['totalAmount']?.toString() ?? '') ??
              (price * (double.tryParse(qty.toString()) ?? 1.0));
          computedTotalAmount += itemTotal;

          itemsToSave.add(
            OrderItem(
              deliveryOrderId: refno,
              stockCode: stockCode,
              title: title,
              category: category,
              price: price,
              orderedQty: '$qty',
              totalAmount: itemTotal,
              uom: uom,
            ),
          );
        }

        final headerAmount = double.tryParse(header['totalAmount']?.toString() ?? '');
        final finalTotalAmount = headerAmount ?? computedTotalAmount;

        // Preserve local status, 1h delivery timestamp, and payment reference
        final existingOrder = existingOrderMap[refno] ?? existingOrderMap[txnId];
        final status = existingOrder?.status.value ?? 'Out for Delivery';

        final rawPhone = (header['phone']?.toString() ??
                header['contactNumber']?.toString() ??
                header['contactCellNumber']?.toString() ??
                header['mobileNumber']?.toString() ??
                header['mobile']?.toString() ??
                header['telNo']?.toString() ??
                cust?['contactCellNumber']?.toString() ??
                cust?['phone']?.toString() ??
                cust?['mobile']?.toString() ??
                cust?['contactNumber']?.toString() ??
                cust?['telNo']?.toString() ??
                '')
            .trim();
        final resolvedPhone = rawPhone.isNotEmpty
            ? rawPhone
            : (existingOrder?.customerPhone ?? '');
        final resolvedRemarks = (header['remarks']?.toString() ??
                header['REMARKS']?.toString() ??
                existingOrder?.orderRemarks ??
                '')
            .trim();

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
            distance: distanceLabel,
            sku: txnItems.isNotEmpty ? txnItems.length.toString() : (header['sku_count']?.toString() ?? '1'),
            totalAmount: formattedAmount,
            status: status,
            deliveryDate: header['unloadingDate']?.toString() ?? header['deliveryDate']?.toString() ?? todayStr,
            latitude: lat,
            longitude: lng,
            distanceKm: distanceKm,
            deliveredAt: existingOrder?.deliveredAt,
            paymentReference: existingOrder?.paymentReference,
            proofOfDeliveryPath: existingOrder?.proofOfDeliveryPath,
            cancellationReason: existingOrder?.cancellationReason,
            customerPhone: resolvedPhone,
            orderRemarks: resolvedRemarks,
            attemptCount: existingOrder?.attemptCount ?? 0,
            lastAttemptReason: existingOrder?.lastAttemptReason,
            lastAttemptAt: existingOrder?.lastAttemptAt,
            outForDeliverySmsSentAt: existingOrder?.outForDeliverySmsSentAt,
            isLocked: existingOrder?.isLocked ?? false,
            scheduledDeliveryDate: existingOrder?.scheduledDeliveryDate,
            lockedAt: existingOrder?.lockedAt,
            routeSequence: existingOrder?.routeSequence,
          ),
        );
      }

      // Sort in ascending order from nearest to farthest before saving to DB
      ordersToSave.sort((a, b) =>
          (a.distanceKm ?? double.infinity)
              .compareTo(b.distanceKm ?? double.infinity));

      // 7. Save batch to SQLite
      onProgress?.call(0.92, 'Updating offline database & items...');
      logSync('Saving ${ordersToSave.length} orders & ${itemsToSave.length} items to SQLite...');
      await _dbService.saveDeliveryOrdersBatch(ordersToSave);
      if (itemsToSave.isNotEmpty) {
        await _dbService.saveOrderItemsBatch(itemsToSave);
      }

      // 8. Auto-notify customers via SMS for newly dispatched Out-for-Delivery orders
      if (Get.isRegistered<SmsService>()) {
        final smsService = SmsService.to;
        for (final order in ordersToSave) {
          if (order.status.value == 'Out for Delivery' &&
              (order.outForDeliverySmsSentAt == null ||
                  order.outForDeliverySmsSentAt!.isEmpty) &&
              smsService.isValidPhoneNumber(order.customerPhone)) {
            await smsService.sendOutForDeliveryNotification(order);
          }
        }
      }

      onProgress?.call(1.0, 'Dispatch ready! Orders updated.');
      logImportant('Successfully synced ${ordersToSave.length} delivery orders & ${itemsToSave.length} items for dispatch!');
      return SyncResult(
        success: true,
        message: 'Sync completed successfully.',
        orderCount: ordersToSave.length,
        itemCount: itemsToSave.length,
      );
    } catch (e, stack) {
      logError('DriverSyncService unexpected sync failure', e, stack);
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
      );
    }
  }

  static double? _parseCoord(dynamic raw) {
    if (raw == null) return null;
    final val = double.tryParse(raw.toString().trim());
    if (val == null || val == 0.0 || val == 9999.0) return null;
    return val;
  }
}

