import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/core/utils/location_helper.dart';
import 'package:p_sosyo_driver/app/core/utils/paqner_qr_codec.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_attempt.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/models/order_item.dart';
import 'package:p_sosyo_driver/app/data/providers/api_client.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/data/services/sms_service.dart';
import 'package:p_sosyo_driver/app/data/services/transaction_services.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';

class OrderDetailsController extends GetxController {
  DeliveryOrder? order;
  final RxList<OrderItem> items = <OrderItem>[].obs;
  final RxList<DeliveryAttempt> attempts = <DeliveryAttempt>[].obs;
  final RxString customerPhone = ''.obs;
  final RxInt attemptCount = 0.obs;
  final RxString orderStatus = 'Out for Delivery'.obs;
  final RxBool isLocked = false.obs;
  final RxString scheduledDeliveryDate = ''.obs;
  final RxString paymentMethod = 'Cash'.obs;
  final RxBool isSendingSms = false.obs;
  final RxBool isLoading = true.obs;
  String? _generatedReferenceId;

  final DatabaseService _dbService = DatabaseService.to;

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments is DeliveryOrder) {
      order = Get.arguments as DeliveryOrder;
      customerPhone.value = order?.customerPhone ?? '';
      attemptCount.value = order?.attemptCount ?? 0;
      orderStatus.value = order?.status.value ?? 'Out for Delivery';
      isLocked.value = order?.isLocked ?? false;
      scheduledDeliveryDate.value = order?.scheduledDeliveryDate ?? '';
      paymentMethod.value = order?.paymentMethod ?? 'Cash';
      final savedRef = order?.paymentReference?.trim() ?? '';
      if (savedRef.isNotEmpty) {
        _generatedReferenceId = savedRef;
      }
    }
    _loadOrderItems();
    loadDeliveryAttempts();
  }

  String get storeName => order?.storeName ?? 'Store';

  String get address => order?.address ?? '';

  String get orderId => order?.id ?? order?.transactionId ?? '';

  String get custCode => order?.custCode ?? '';

  String get storePhoto => order?.storePhoto ?? '';

  String get orderRemarks => order?.orderRemarks ?? '';

  Future<void> togglePaymentMethod() async {
    final targetId = orderId;
    if (targetId.isEmpty) return;
    final next = paymentMethod.value == 'Digital/QR' ? 'Cash' : 'Digital/QR';
    paymentMethod.value = next;
    await _dbService.updateOrderPaymentMethod(targetId, next);
    if (Get.isRegistered<HomeController>()) {
      await Get.find<HomeController>().loadOrdersFromDb();
    }
    logImportant('Payment method for #$targetId set to $next');
  }

  Future<void> adjustOrderItemQuantity({
    required OrderItem item,
    required int newQty,
    required String reason,
  }) async {
    final itemId = item.id;
    final targetId = orderId;
    if (itemId == null || targetId.isEmpty) return;

    final origQty = item.originalQty ?? item.numericQty;
    final clampedQty = newQty.clamp(0, origQty);
    final newItemTotal = item.price * clampedQty;

    final idx = items.indexWhere((i) => i.id == itemId);
    if (idx != -1) {
      items[idx] = item.copyWith(
        orderedQty: '$clampedQty',
        totalAmount: newItemTotal,
        adjustmentReason: reason,
        originalQty: origQty,
      );
      items.refresh();
    }

    final newOrderTotal = items.fold(0.0, (sum, i) => sum + i.totalAmount);
    await _dbService.updateOrderItemDeliveryAdjustment(
      itemId: itemId,
      orderId: targetId,
      newQty: clampedQty,
      newItemTotal: newItemTotal,
      reason: reason,
      originalQty: origQty,
      newOrderTotal: newOrderTotal,
    );
    await TransactionServices.to.recordTransaction(
      orderId: targetId,
      storeName: storeName,
      actionType: 'SKU_ADJUSTED',
      amount: '₱ ${newOrderTotal.toStringAsFixed(2)}',
      summary: '${item.title}: $origQty → $clampedQty ($reason)',
      payload: {
        'itemId': itemId,
        'newQty': clampedQty,
        'originalQty': origQty,
        'reason': reason,
        'newOrderTotal': newOrderTotal,
      },
    );
    if (Get.isRegistered<HomeController>()) {
      await Get.find<HomeController>().loadOrdersFromDb();
    }
    logImportant(
      'Adjusted SKU ${item.title} on #$targetId: $origQty -> $clampedQty ($reason)',
      tag: 'PARTIAL_DELIVERY',
    );
  }

  Future<void> loadDeliveryAttempts() async {
    final targetId = orderId;
    if (targetId.isEmpty) return;
    try {
      final list = await _dbService.getDeliveryAttempts(targetId);
      attempts.assignAll(list);
    } catch (e, stack) {
      logError('Error loading delivery attempts for #$targetId', e, stack);
    }
  }

  Future<void> saveCustomerPhone(String phone) async {
    final target = order;
    if (target == null) return;
    final clean = phone.trim();
    customerPhone.value = clean;
    order = target.copyWith(customerPhone: clean);
    if (Get.isRegistered<HomeController>()) {
      await Get.find<HomeController>().updateOrderCustomerPhone(target.id, clean);
    } else {
      await _dbService.updateOrderCustomerPhone(target.id, clean);
    }
  }

  Future<void> sendOutForDeliverySms() async {
    final target = order;
    if (target == null) return;
    final phone = customerPhone.value.trim();
    if (phone.isEmpty ||
        (Get.isRegistered<SmsService>() &&
            !SmsService.to.isValidPhoneNumber(phone))) {
      Get.snackbar(
        'Phone Number Required',
        'Please enter a valid customer phone number first.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }
    isSendingSms.value = true;
    try {
      final updatedOrder = target.copyWith(customerPhone: phone);
      order = updatedOrder;
      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>()
            .notifyCustomerOutForDelivery(updatedOrder);
      } else if (Get.isRegistered<SmsService>()) {
        await SmsService.to.sendOutForDeliveryNotification(
          updatedOrder,
          showToast: true,
          forceResend: true,
        );
      }
    } finally {
      isSendingSms.value = false;
    }
  }

  Future<int> recordAttempt({
    required String reason,
    String remarks = '',
    bool lockAndQueue = false,
    String? scheduledDateIso,
  }) async {
    final target = order;
    if (target == null) return 0;
    int newCount = target.attemptCount + 1;
    if (Get.isRegistered<HomeController>()) {
      newCount = await Get.find<HomeController>().recordDeliveryAttempt(
        orderId: target.id,
        reason: reason,
        remarks: remarks,
        lockAndQueue: lockAndQueue,
        scheduledDateIso: scheduledDateIso,
      );
    }
    attemptCount.value = newCount;
    if (lockAndQueue) {
      isLocked.value = true;
      scheduledDeliveryDate.value = scheduledDateIso ?? '';
    }
    order = target.copyWith(
      attemptCount: newCount,
      isLocked: lockAndQueue ? true : target.isLocked,
      scheduledDeliveryDate:
          lockAndQueue ? scheduledDateIso : target.scheduledDeliveryDate,
      lastAttemptReason:
          remarks.trim().isNotEmpty ? '$reason - ${remarks.trim()}' : reason,
    );
    await loadDeliveryAttempts();
    return newCount;
  }

  Future<void> unlockOrder() async {
    final target = order;
    if (target == null) return;
    if (Get.isRegistered<HomeController>()) {
      await Get.find<HomeController>().unlockOrder(target.id);
    }
    isLocked.value = false;
    scheduledDeliveryDate.value = '';
    order = target.copyWith(
      isLocked: false,
      clearScheduledDeliveryDate: true,
      clearLockedAt: true,
    );
  }

  Future<void> rescheduleOrder(String newDateIso) async {
    final target = order;
    if (target == null) return;
    if (Get.isRegistered<HomeController>()) {
      await Get.find<HomeController>()
          .rescheduleLockedOrder(target.id, newDateIso);
    }
    isLocked.value = true;
    scheduledDeliveryDate.value = newDateIso;
    order = target.copyWith(
      isLocked: true,
      scheduledDeliveryDate: newDateIso,
    );
  }

  /// Open Google Maps directions from the driver's current location to this store.
  Future<void> openStoreNavigation() async {
    final currentOrder = order;
    if (currentOrder == null) return;
    final driverCoords = await LocationHelper.getCurrentDriverLocation();
    final resolved = currentOrder.withResolvedLocation(
      driverLat: driverCoords.latitude,
      driverLng: driverCoords.longitude,
    );
    final destLat = resolved.latitude;
    final destLng = resolved.longitude;
    if (destLat == null || destLng == null) return;

    final success = await LocationHelper.openGoogleMapsDirections(
      originLat: driverCoords.latitude,
      originLng: driverCoords.longitude,
      destLat: destLat,
      destLng: destLng,
      storeName: storeName,
    );

    if (!success) {
      Get.snackbar(
        'Map Navigation',
        'Rebuild the app (flutter run) to activate native Google Maps launching for $storeName ($destLat, $destLng).',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// Load order items from the database for the active order.
  Future<void> _loadOrderItems() async {
    try {
      isLoading.value = true;
      final targetId = orderId;
      final Set<String> targetIds = {
        if (targetId.isNotEmpty) targetId,
        if (order != null && order!.transactionId.isNotEmpty) order!.transactionId,
        if (order != null && order!.id.isNotEmpty) order!.id,
      };

      final List<OrderItem> allLoaded = [];
      for (final id in targetIds) {
        final queryResults = await _dbService.getOrderItems(id);
        allLoaded.addAll(queryResults);
      }

      // Deduplicate items by stockCode or title to prevent duplicate cards
      final Map<String, OrderItem> uniqueItems = {};
      for (final item in allLoaded) {
        final key = item.stockCode.isNotEmpty ? item.stockCode : item.title;
        uniqueItems[key] = item;
      }

      items.assignAll(uniqueItems.values.toList());
    } catch (e, stack) {
      logError('Error loading order items', e, stack);
    } finally {
      isLoading.value = false;
    }
  }

  int get totalSku => items.isNotEmpty
      ? items.length
      : (int.tryParse(order?.sku ?? '0') ?? 0);

  double get totalAmount {
    if (items.isNotEmpty) {
      final sum = items.fold(0.0, (sum, item) => sum + item.totalAmount);
      if (sum > 0) return sum;
    }
    if (order != null) {
      return order!.numericTotalAmount;
    }
    return 0.0;
  }

  String get formattedTotalAmount {
    if (items.isEmpty && order != null && order!.totalAmount.isNotEmpty) {
      return order!.totalAmount;
    }
    final parts = totalAmount.toStringAsFixed(2).split('.');
    final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAllMapped(regExp, (Match m) => ',');
    return '₱ ${parts.join('.')}';
  }

  String get generatedReferenceId => _generatedReferenceId ?? '';

  /// Build the RavaMate Paqner Trade Terms v1 pay QR payload (`{v,md,sn,sc,r,di,c,si,p,a,d,s,n,t,i}`).
  /// Keeps `r` stable across repeated QR opens for the same order.
  Future<Map<String, dynamic>> buildPaqnerPayPayload() async {
    const String dynamicPrincipal = 'Monde';
    final authenticatedDriver = await _dbService.getAuthenticatedDriver();
    final mdCode =
        authenticatedDriver?.username ?? await ApiClient.getDriverCode();
    final salesmanName = (authenticatedDriver?.fullName.trim().isNotEmpty == true)
        ? authenticatedDriver!.fullName.trim()
        : mdCode;

    String salesmanCode = await ApiClient.getSalesmanCode();
    if (salesmanCode.isEmpty || salesmanCode == ApiClient.defaultSalesmanCode) {
      if (salesmanName.contains(' - ')) {
        final prefix = salesmanName.split(' - ').first.trim();
        if (prefix.isNotEmpty) {
          salesmanCode = prefix;
        }
      }
    }
    if (salesmanCode.isEmpty) {
      salesmanCode = mdCode;
    }

    final distCode = await ApiClient.getDistCode();
    final companyName = await ApiClient.getCompanyName();

    if (_generatedReferenceId == null || _generatedReferenceId!.isEmpty) {
      final newRef = PaqnerQrCodec.generateSalesmanReferenceId(
        salesmanCode: salesmanCode,
        principal: dynamicPrincipal,
      );
      _generatedReferenceId = newRef;
      final target = order;
      if (target != null) {
        order = target.copyWith(paymentReference: newRef);
        if (Get.isRegistered<HomeController>()) {
          await Get.find<HomeController>()
              .updateOrderPaymentReference(target.id, newRef);
        } else {
          await _dbService.updateOrderPaymentReference(target.id, newRef);
        }
      }
    }

    final refNo =
        order?.id ?? order?.transactionId ?? (orderId.isNotEmpty ? orderId : 'R92611051');

    final List<List<dynamic>> productJsonList = [];
    for (final item in items) {
      final description = item.title.length > 15
          ? item.title.substring(0, 15)
          : item.title;
      final qtyMatch = RegExp(r'\d+').stringMatch(item.orderedQty);
      final totalQty = qtyMatch != null ? (int.tryParse(qtyMatch) ?? 1) : 1;

      productJsonList.add([
        item.stockCode,
        description,
        item.category,
        totalQty,
        item.price,
        item.totalAmount,
        item.uom,
      ]);
    }

    final now = DateTime.now();
    final grossAmount = totalAmount;

    return {
      'v': 1,
      'md': mdCode,
      'sn': salesmanName,
      'sc': salesmanCode,
      'r': _generatedReferenceId!,
      'di': distCode,
      'c': companyName,
      'si': refNo,
      'p': dynamicPrincipal,
      'a': now.toIso8601String().split('T')[0],
      'd': now.add(const Duration(days: 7)).toIso8601String().split('T')[0],
      's': 'active',
      'n': productJsonList.length,
      't': grossAmount,
      'i': productJsonList,
    };
  }
}
