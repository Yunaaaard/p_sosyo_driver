import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/utils/location_helper.dart';
import 'package:p_sosyo_driver/app/core/utils/peso_formatter.dart';

class DeliveryOrder {
  final String id;
  final String transactionId;
  final String custCode;
  final String storePhoto;
  final String storeName;
  final String address;
  final String distance;
  final String sku;
  final String totalAmount;
  final RxString status;
  final String deliveryDate;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final String? deliveredAt;
  final String? paymentReference;
  final String? proofOfDeliveryPath;
  final String? cancellationReason;
  final String customerPhone;
  final String orderRemarks;
  final int attemptCount;
  final String? lastAttemptReason;
  final String? lastAttemptAt;
  final String? outForDeliverySmsSentAt;
  final bool isLocked;
  final String? scheduledDeliveryDate;
  final String? lockedAt;

  DeliveryOrder({
    required this.id,
    String? transactionId,
    String? custCode,
    String? storePhoto,
    required this.storeName,
    required this.address,
    required this.distance,
    required this.sku,
    required this.totalAmount,
    required String status,
    String? deliveryDate,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.deliveredAt,
    this.paymentReference,
    this.proofOfDeliveryPath,
    this.cancellationReason,
    String? customerPhone,
    String? orderRemarks,
    this.attemptCount = 0,
    this.lastAttemptReason,
    this.lastAttemptAt,
    this.outForDeliverySmsSentAt,
    this.isLocked = false,
    this.scheduledDeliveryDate,
    this.lockedAt,
  }) : transactionId = transactionId ?? id,
        custCode = custCode ?? '',
        storePhoto = storePhoto ?? '',
        deliveryDate = deliveryDate ?? '',
        customerPhone = customerPhone ?? '',
        orderRemarks = orderRemarks ?? '',
        status = status.obs;

  /// Parsed UTC delivery completion timestamp for the 1-hour cancellation window.
  DateTime? get deliveredAtDateTime {
    final raw = deliveredAt?.trim() ?? '';
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  /// Remaining time left in the 1-hour post-delivery cancellation window.
  Duration remainingCancelDuration(DateTime now) {
    final delivered = deliveredAtDateTime;
    if (delivered == null) return Duration.zero;
    final expiresAt = delivered.add(const Duration(hours: 1));
    final diff = expiresAt.difference(now.toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Whether this delivered order is still within its 1-hour cancellation window.
  bool canCancelDelivered(DateTime now) =>
      status.value == 'Delivered' &&
      remainingCancelDuration(now) > Duration.zero;

  /// Numeric order total parsed from [totalAmount].
  double get numericTotalAmount {
    final clean = totalAmount.replaceAll('₱', '').replaceAll(',', '').trim();
    return double.tryParse(clean) ?? 0.0;
  }

  /// Formatted distance label (e.g. "12.6KM away").
  String get formattedDistanceAway {
    if (distanceKm != null) {
      return LocationHelper.formatDistanceKmAway(distanceKm!);
    }
    if (distance.isNotEmpty && distance.toUpperCase().contains('KM')) {
      return distance;
    }
    return '';
  }

  /// Formatted coordinates string (e.g. "10.31570, 123.88540").
  String get formattedCoordinates =>
      LocationHelper.formatLatLong(latitude, longitude);

  DeliveryOrder withResolvedLocation({
    required double driverLat,
    required double driverLng,
  }) {
    final coords = LocationHelper.resolveOrderCoordinates(
      seedKey: custCode.isNotEmpty ? custCode : id,
      rawLat: latitude,
      rawLng: longitude,
    );
    final km = LocationHelper.calculateDistanceKm(
      startLat: driverLat,
      startLng: driverLng,
      endLat: coords.latitude,
      endLng: coords.longitude,
    );
    final formattedDist = LocationHelper.formatDistanceKmAway(km);
    final order = DeliveryOrder(
      id: id,
      transactionId: transactionId,
      custCode: custCode,
      storePhoto: storePhoto,
      storeName: storeName,
      address: address,
      distance: formattedDist,
      sku: sku,
      totalAmount: totalAmount,
      status: status.value,
      deliveryDate: deliveryDate,
      latitude: coords.latitude,
      longitude: coords.longitude,
      distanceKm: km,
      deliveredAt: deliveredAt,
      paymentReference: paymentReference,
      proofOfDeliveryPath: proofOfDeliveryPath,
      cancellationReason: cancellationReason,
      customerPhone: customerPhone,
      orderRemarks: orderRemarks,
      attemptCount: attemptCount,
      lastAttemptReason: lastAttemptReason,
      lastAttemptAt: lastAttemptAt,
      outForDeliverySmsSentAt: outForDeliverySmsSentAt,
      isLocked: isLocked,
      scheduledDeliveryDate: scheduledDeliveryDate,
      lockedAt: lockedAt,
    );
    return order;
  }

  DeliveryOrder copyWith({
    String? status,
    String? deliveredAt,
    String? paymentReference,
    String? proofOfDeliveryPath,
    String? cancellationReason,
    String? customerPhone,
    String? orderRemarks,
    int? attemptCount,
    String? lastAttemptReason,
    String? lastAttemptAt,
    String? outForDeliverySmsSentAt,
    bool? isLocked,
    String? scheduledDeliveryDate,
    bool clearScheduledDeliveryDate = false,
    String? lockedAt,
    bool clearLockedAt = false,
  }) {
    return DeliveryOrder(
      id: id,
      transactionId: transactionId,
      custCode: custCode,
      storePhoto: storePhoto,
      storeName: storeName,
      address: address,
      distance: distance,
      sku: sku,
      totalAmount: totalAmount,
      status: status ?? this.status.value,
      deliveryDate: deliveryDate,
      latitude: latitude,
      longitude: longitude,
      distanceKm: distanceKm,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      paymentReference: paymentReference ?? this.paymentReference,
      proofOfDeliveryPath: proofOfDeliveryPath ?? this.proofOfDeliveryPath,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      customerPhone: customerPhone ?? this.customerPhone,
      orderRemarks: orderRemarks ?? this.orderRemarks,
      attemptCount: attemptCount ?? this.attemptCount,
      lastAttemptReason: lastAttemptReason ?? this.lastAttemptReason,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      outForDeliverySmsSentAt:
          outForDeliverySmsSentAt ?? this.outForDeliverySmsSentAt,
      isLocked: isLocked ?? this.isLocked,
      scheduledDeliveryDate: clearScheduledDeliveryDate
          ? null
          : (scheduledDeliveryDate ?? this.scheduledDeliveryDate),
      lockedAt: clearLockedAt ? null : (lockedAt ?? this.lockedAt),
    );
  }

  factory DeliveryOrder.fromMap(Map<String, dynamic> map) {
    return DeliveryOrder(
      id: map['id'].toString(),
      transactionId: map['transaction_id']?.toString() ?? map['id'].toString(),
      custCode: map['cust_code']?.toString() ?? '',
      storePhoto: map['store_photo']?.toString() ?? '',
      storeName: map['store_name']?.toString() ?? 'Store',
      address: map['address']?.toString() ?? '',
      distance: map['distance']?.toString() ?? '',
      sku: map['sku_count']?.toString() ?? '0',
      totalAmount: map['total_amount'] is num
          ? '₱ ${PesoFormatter.formatAmount((map['total_amount'] as num).toDouble())}'
          : '₱ ${PesoFormatter.formatString(map['total_amount']?.toString() ?? '0.00')}',
      status: map['status']?.toString() ?? 'Out for Delivery',
      deliveryDate: map['delivery_date']?.toString() ?? '',
      latitude: map['latitude'] != null ? double.tryParse(map['latitude'].toString()) : null,
      longitude: map['longitude'] != null ? double.tryParse(map['longitude'].toString()) : null,
      deliveredAt: map['delivered_at']?.toString(),
      paymentReference: map['payment_reference']?.toString(),
      proofOfDeliveryPath: map['proof_of_delivery_path']?.toString(),
      cancellationReason: map['cancellation_reason']?.toString(),
      customerPhone: map['customer_phone']?.toString() ?? '',
      orderRemarks: map['order_remarks']?.toString() ?? '',
      attemptCount: (map['attempt_count'] as num?)?.toInt() ?? 0,
      lastAttemptReason: map['last_attempt_reason']?.toString(),
      lastAttemptAt: map['last_attempt_at']?.toString(),
      outForDeliverySmsSentAt: map['out_for_delivery_sms_sent_at']?.toString(),
      isLocked: (map['is_locked'] as num?)?.toInt() == 1,
      scheduledDeliveryDate: map['scheduled_delivery_date']?.toString(),
      lockedAt: map['locked_at']?.toString(),
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
      'cust_code': custCode,
      'store_photo': storePhoto,
      'store_name': storeName,
      'address': address,
      'distance': distance,
      'sku_count': skuNum,
      'total_amount': amountNum,
      'status': status.value,
      'delivery_date': deliveryDate,
      'latitude': latitude,
      'longitude': longitude,
      'delivered_at': deliveredAt,
      'payment_reference': paymentReference,
      'proof_of_delivery_path': proofOfDeliveryPath,
      'cancellation_reason': cancellationReason,
      'customer_phone': customerPhone,
      'order_remarks': orderRemarks,
      'attempt_count': attemptCount,
      'last_attempt_reason': lastAttemptReason,
      'last_attempt_at': lastAttemptAt,
      'out_for_delivery_sms_sent_at': outForDeliverySmsSentAt,
      'is_locked': isLocked ? 1 : 0,
      'scheduled_delivery_date': scheduledDeliveryDate,
      'locked_at': lockedAt,
    };
  }
}
