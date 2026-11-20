import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/core/utils/paqner_qr_codec.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/models/order_item.dart';
import 'package:p_sosyo_driver/app/data/models/receipt.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/data/services/scanner_service.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';

class ReceiptDetailsController extends GetxController {
  DeliveryOrder? order;
  final RxString referenceNumber = ''.obs;
  final RxString referenceId = ''.obs;
  final RxString totalAmount = ''.obs;
  final RxString sender = ''.obs;
  final RxString receiver = ''.obs;
  final RxString date = ''.obs;
  final RxString scannedInvoiceSi = ''.obs;
  final RxString proofOfDeliveryPath = ''.obs;
  final RxBool isCapturingPod = false.obs;
  final RxBool isScanned = false.obs;
  String _expectedReferenceId = '';
  double? _expectedAmount;

  final ScannerService _scannerService = Get.find<ScannerService>();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is DeliveryOrder) {
      order = args;
      _expectedAmount = args.numericTotalAmount;
    } else if (args is Map) {
      if (args['order'] is DeliveryOrder) {
        order = args['order'] as DeliveryOrder;
      }
      _expectedReferenceId =
          (args['expectedReferenceId'] ?? '').toString().trim();
      final rawExpAmt = args['expectedAmount'];
      if (rawExpAmt is num) {
        _expectedAmount = rawExpAmt.toDouble();
      } else {
        _expectedAmount = order?.numericTotalAmount;
      }
    }
  }

  Future<String> _fetchUrl(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        return responseBody;
      } else {
        throw Exception('Failed to fetch data: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  Future<void> startScanning() async {
    final result = await _scannerService.scanReceipt();
    if (result != null) {
      await processScannedReceipt(result);
    }
  }

  /// Parse a scanned Paqner Trade Terms receipt QR (supports URL, plain JSON,
  /// and Base64+GZIP compressed payloads) and populate receipt fields:
  /// - Reference Number: `salesman_reference_id`
  /// - Total Amount Sent: `amountDue`
  /// - Sender: `principalTitle`
  /// - Date: `appliedDate`
  Future<void> processScannedReceipt(String rawResult) async {
    try {
      String payloadString = rawResult.trim();

      // 1. If scanned content is a URL, fetch the payload from the URL
      if (payloadString.startsWith('http://') ||
          payloadString.startsWith('https://')) {
        payloadString = await _fetchUrl(payloadString);
      }

      Map<String, dynamic> data = PaqnerQrCodec.decode(payloadString);

      // 2. If payload is wrapped inside a "record" object (e.g. JSONBin), extract it
      if (data.containsKey('record') &&
          data['record'] is Map<String, dynamic>) {
        data = Map<String, dynamic>.from(data['record'] as Map);
      }

      logImportant(
        'Scanned Customer Receipt Payload: ${jsonEncode(data)}',
        tag: 'RECEIPT',
      );

      final scannedSi = (data['si'] ?? '').toString().trim();
      final scannedSalesmanRef =
          (data['salesman_reference_id'] ?? data['r'] ?? '').toString().trim();
      final scannedRefId = (data['referenceId'] ??
              data['payment_reference'] ??
              data['m'] ??
              data['referenceNumber'] ??
              data['reference_number'] ??
              scannedSalesmanRef)
          .toString()
          .trim();

      final rawAmountVal = data['amountDue'] ??
          data['t'] ??
          data['totalAmountSent'] ??
          data['total_amount_sent'] ??
          data['totalAmount'] ??
          data['amount'];
      final double? parsedScannedAmount = rawAmountVal is num
          ? rawAmountVal.toDouble()
          : double.tryParse(
              (rawAmountVal ?? '')
                  .toString()
                  .replaceAll(',', '')
                  .replaceAll('₱', '')
                  .trim(),
            );

      // Validate that the scanned receipt actually belongs to this order/customer
      final validationError = await _validateScannedReceipt(
        scannedSi: scannedSi,
        scannedSalesmanRef: scannedSalesmanRef,
        scannedRefId: scannedRefId,
        parsedAmount: parsedScannedAmount,
      );
      if (validationError != null) {
        logWarning('Rejected mismatched receipt scan: $validationError',
            tag: 'RECEIPT');
        isScanned.value = false;
        Get.snackbar(
          'Receipt Mismatch',
          validationError,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFFEECEC),
          colorText: const Color(0xFFC81E1E),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      scannedInvoiceSi.value = scannedSi;
      referenceId.value = scannedRefId;

      // 3. Reference Number ← referenceId (with fallbacks for compact/legacy payloads)
      referenceNumber.value = (scannedRefId.isNotEmpty
              ? scannedRefId
              : (data['refno'] ?? data['id'] ?? data['reference_id'] ?? '')
                  .toString()
                  .trim());

      // 4. Total Amount Sent ← amountDue (with fallbacks)
      if (parsedScannedAmount != null) {
        totalAmount.value = _formatAmount(parsedScannedAmount);
      } else if (rawAmountVal is String) {
        totalAmount.value = rawAmountVal;
      } else {
        totalAmount.value = '';
      }

      // 5. Sender ← principalTitle (with fallbacks)
      final metadata = data['metadata'];
      if (data['principalTitle'] != null &&
          data['principalTitle'].toString().trim().isNotEmpty) {
        sender.value = data['principalTitle'].toString().trim();
      } else if (data['p'] != null && data['p'].toString().trim().isNotEmpty) {
        sender.value = data['p'].toString().trim();
      } else if (data['sender'] != null &&
          data['sender'].toString().trim().isNotEmpty) {
        sender.value = data['sender'].toString().trim();
      } else if (data['customerName'] != null &&
          data['customerName'].toString().trim().isNotEmpty) {
        sender.value = data['customerName'].toString().trim();
      } else if (data['customer_name'] != null &&
          data['customer_name'].toString().trim().isNotEmpty) {
        sender.value = data['customer_name'].toString().trim();
      } else if (metadata is Map<String, dynamic>) {
        sender.value = (metadata['customer_name'] ?? '').toString().trim();
      } else {
        sender.value = '';
      }

      // 6. Receiver / Payment Channel
      if (data['receiver'] != null &&
          data['receiver'].toString().trim().isNotEmpty) {
        receiver.value = data['receiver'].toString().trim();
      } else if (data['c'] != null && data['c'].toString().trim().isNotEmpty) {
        receiver.value = data['c'].toString().trim();
      } else {
        final paymentMethod = data['payment_method'];
        String? channelCode;
        if (paymentMethod is Map<String, dynamic>) {
          final ewallet = paymentMethod['ewallet'];
          if (ewallet is Map<String, dynamic>) {
            channelCode = ewallet['channel_code']?.toString();
          }
        }
        if (channelCode != null && channelCode.isNotEmpty) {
          receiver.value = 'PAQNER ($channelCode)';
        } else {
          receiver.value = 'PAQNER TRADE TERMS';
        }
      }

      // 7. Date ← appliedDate (with fallbacks)
      final rawDate = (data['appliedDate'] ??
              data['a'] ??
              data['date'] ??
              data['created'] ??
              '')
          .toString()
          .trim();
      if (rawDate.isNotEmpty) {
        try {
          final dateTime = DateTime.parse(rawDate);
          const months = [
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December',
          ];
          date.value =
              '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
        } catch (_) {
          date.value = rawDate;
        }
      } else {
        date.value = '';
      }

      isScanned.value = true;
      logImportant(
        'Scanned Receipt matched: Ref #${referenceNumber.value} | Total: ${totalAmount.value} | Sender: ${sender.value} | Date: ${date.value}',
        tag: 'RECEIPT',
      );
    } catch (e, stack) {
      logError('Error parsing scanned QR receipt JSON', e, stack);
    }
  }

  Future<String?> _validateScannedReceipt({
    required String scannedSi,
    required String scannedSalesmanRef,
    required String scannedRefId,
    required double? parsedAmount,
  }) async {
    final targetOrder = order;
    if (targetOrder == null) return null;

    // 1. Check Sales Invoice / Order ID if present in receipt payload
    if (scannedSi.isNotEmpty &&
        scannedSi != targetOrder.id &&
        scannedSi != targetOrder.transactionId) {
      return 'This receipt is for Order #$scannedSi, not ${targetOrder.storeName} (#${targetOrder.id}).';
    }

    // 2. Check generated salesman reference ID if present in receipt payload
    if (_expectedReferenceId.isNotEmpty &&
        scannedSalesmanRef.isNotEmpty &&
        scannedSalesmanRef != _expectedReferenceId) {
      return 'Reference mismatch: This receipt does not match the QR generated for ${targetOrder.storeName}.';
    }

    // 3. Check exact amount due
    final expectedAmt = (_expectedAmount != null && _expectedAmount! > 0)
        ? _expectedAmount!
        : targetOrder.numericTotalAmount;
    if (expectedAmt > 0) {
      if (parsedAmount == null) {
        return 'Receipt is missing a valid amount (expected ₱${expectedAmt.toStringAsFixed(2)}).';
      }
      if ((parsedAmount - expectedAmt).abs() > 0.01) {
        return 'Amount mismatch: Receipt is ₱${parsedAmount.toStringAsFixed(2)}, but ${targetOrder.storeName} expects ₱${expectedAmt.toStringAsFixed(2)}.';
      }
    }

    // 4. Prevent reusing a receipt reference already attached to another order
    if (scannedRefId.isNotEmpty) {
      final existingReceipts = await DatabaseService.to.getAllReceipts();
      final duplicate = existingReceipts.any(
        (r) =>
            r.referenceNumber.trim() == scannedRefId &&
            r.deliveryOrderId != targetOrder.id &&
            r.deliveryOrderId != targetOrder.transactionId,
      );
      if (duplicate) {
        return 'This receipt ($scannedRefId) was already used for another order.';
      }
    }

    return null;
  }

  String _formatAmount(double amount) {
    String str = amount.toStringAsFixed(2);
    List<String> parts = str.split('.');
    String integerPart = parts[0];
    String decimalPart = parts[1];
    
    StringBuffer sb = StringBuffer();
    int len = integerPart.length;
    for (int i = 0; i < len; i++) {
      sb.write(integerPart[i]);
      if ((len - i - 1) % 3 == 0 && i != len - 1) {
        sb.write(',');
      }
    }
    return '${sb.toString()}.$decimalPart';
  }

  /// Capture Proof of Delivery photo via camera and persist it locally.
  Future<void> captureProofOfDelivery() async {
    try {
      isCapturingPod.value = true;
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final podDir = Directory(p.join(appDir.path, 'proof_of_delivery'));
      if (!await podDir.exists()) {
        await podDir.create(recursive: true);
      }

      final safeOrderId =
          (order?.id ?? 'ORDER').replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName =
          'POD_${safeOrderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = p.join(podDir.path, fileName);
      await File(picked.path).copy(savedPath);

      proofOfDeliveryPath.value = savedPath;
      logImportant(
        'Saved local Proof of Delivery: $savedPath',
        tag: 'POD',
      );
    } catch (e, stack) {
      logError('Error capturing Proof of Delivery', e, stack);
      Get.snackbar(
        'Camera Error',
        'Could not capture Proof of Delivery photo.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      isCapturingPod.value = false;
    }
  }

  Future<void> tagAsDelivered() async {
    if (!isScanned.value) return;
    final targetOrder = order;
    if (targetOrder != null) {
      final expectedAmt = (_expectedAmount != null && _expectedAmount! > 0)
          ? _expectedAmount!
          : targetOrder.numericTotalAmount;
      final cleanTotal =
          totalAmount.value.replaceAll(',', '').replaceAll('₱', '').trim();
      final parsedTotal = double.tryParse(cleanTotal);
      if (expectedAmt > 0 &&
          (parsedTotal == null || (parsedTotal - expectedAmt).abs() > 0.01)) {
        Get.snackbar(
          'Receipt Mismatch',
          'Scanned receipt amount does not match ${targetOrder.storeName} (expected ₱${expectedAmt.toStringAsFixed(2)}).',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFFEECEC),
          colorText: const Color(0xFFC81E1E),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return;
      }
    }
    if (proofOfDeliveryPath.value.trim().isEmpty) {
      Get.snackbar(
        'Proof of Delivery Required',
        'Please capture a Proof of Delivery photo before tagging as delivered.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }

    final scannedRef = referenceNumber.value.trim();
    final scannedSi = scannedInvoiceSi.value.trim();
    final targetOrderId = (order?.id.trim().isNotEmpty == true)
        ? order!.id.trim()
        : (order?.transactionId.trim().isNotEmpty == true)
            ? order!.transactionId.trim()
            : (scannedSi.isNotEmpty)
                ? scannedSi
                : scannedRef;
    final customerName = order?.storeName ?? 'Customer';
    final localPodPath = proofOfDeliveryPath.value.trim();

    try {
      final HomeController homeController = Get.find<HomeController>();
      await homeController.markOrderAsDelivered(
        targetOrderId,
        paymentReference: scannedRef,
        proofOfDeliveryPath: localPodPath,
      );
    } catch (e, stack) {
      logError('Error accessing HomeController to mark delivered', e, stack);
    }

    try {
      final cleanAmount =
          totalAmount.value.replaceAll(',', '').replaceAll('₱', '').trim();
      final parsedAmount = double.tryParse(cleanAmount) ?? 0.0;
      await DatabaseService.to.insertReceipt(
        Receipt(
          deliveryOrderId: targetOrderId,
          referenceNumber: referenceNumber.value,
          totalAmount: parsedAmount,
          sender: sender.value,
          receiver: receiver.value,
          date: date.value,
          scannedAt: DateTime.now().toIso8601String(),
          customerName: customerName,
          proofOfDeliveryPath: localPodPath.isNotEmpty ? localPodPath : null,
        ),
      );
      logImportant('Saved receipt record for delivery order #$targetOrderId');
    } catch (e, stack) {
      logError('Error saving receipt to database', e, stack);
    }

    List<OrderItem> orderedItems = [];
    try {
      orderedItems = await DatabaseService.to.getOrderItems(targetOrderId);
      if (orderedItems.isEmpty &&
          order != null &&
          order!.transactionId.trim().isNotEmpty) {
        orderedItems =
            await DatabaseService.to.getOrderItems(order!.transactionId.trim());
      }
    } catch (e, stack) {
      logError('Error loading order items for delivery summary', e, stack);
    }

    // No confirmation modal — navigate directly to the Delivery Order Summary & Print screen
    Get.offNamed(
      AppRoutes.deliverySummary,
      arguments: <String, dynamic>{
        'totalAmount': totalAmount.value,
        'date': date.value,
        'customerName': customerName,
        'referenceNumber': targetOrderId,
        'proofOfDeliveryPath': localPodPath,
        'items': orderedItems,
      },
    );
  }
}
