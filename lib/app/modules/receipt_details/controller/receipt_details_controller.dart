import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/data/services/scanner_service.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';

class ReceiptDetailsController extends GetxController {
  final RxString referenceNumber = ''.obs;
  final RxString totalAmount = ''.obs;
  final RxString sender = ''.obs;
  final RxString receiver = ''.obs;
  final RxString date = ''.obs;
  final RxBool isScanned = false.obs;

  final ScannerService _scannerService = Get.find<ScannerService>();

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
      try {
        String jsonString = result.trim();
        
        // 1. If scanned content is a URL, fetch the payload from the URL
        if (jsonString.startsWith('http://') || jsonString.startsWith('https://')) {
          jsonString = await _fetchUrl(jsonString);
        }

        Map<String, dynamic> data = jsonDecode(jsonString);
        
        // 2. If payload is wrapped inside a "record" object (e.g. JSONBin), extract it
        if (data.containsKey('record') && data['record'] is Map<String, dynamic>) {
          data = data['record'] as Map<String, dynamic>;
        }
        
        // 3. Reference Number (id/reference_id)
        referenceNumber.value = data['id'] ?? data['reference_id'] ?? '';
        
        // 4. Amount Format (e.g. 10000.0 -> 10,000.00)
        final rawAmount = data['amount'];
        if (rawAmount is num) {
          totalAmount.value = _formatAmount(rawAmount.toDouble());
        } else if (rawAmount is String) {
          final parsedDouble = double.tryParse(rawAmount.replaceAll(',', ''));
          if (parsedDouble != null) {
            totalAmount.value = _formatAmount(parsedDouble);
          } else {
            totalAmount.value = rawAmount;
          }
        } else {
          totalAmount.value = '';
        }

        // 5. Sender / Customer Name
        final metadata = data['metadata'];
        if (metadata is Map<String, dynamic>) {
          sender.value = metadata['customer_name'] ?? '';
        } else {
          sender.value = '';
        }

        // 6. Receiver / Payment Channel
        final paymentMethod = data['payment_method'];
        String? channelCode;
        if (paymentMethod is Map<String, dynamic>) {
          final ewallet = paymentMethod['ewallet'];
          if (ewallet is Map<String, dynamic>) {
            channelCode = ewallet['channel_code'];
          }
        }
        if (channelCode != null && channelCode.isNotEmpty) {
          receiver.value = 'FAST SOSYO ($channelCode)';
        } else {
          receiver.value = 'FAST SOSYO NESTLE';
        }

        // 7. Date Format (e.g. "2026-05-05T08:12:33.001Z" -> "May 5, 2026")
        final createdStr = data['created'];
        if (createdStr != null && createdStr.isNotEmpty) {
          try {
            final dateTime = DateTime.parse(createdStr);
            final months = [
              'January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December'
            ];
            date.value = '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
          } catch (_) {
            date.value = createdStr;
          }
        } else {
          date.value = '';
        }

        isScanned.value = true;
      } catch (e) {
        debugPrint('Error parsing scanned QR receipt JSON: $e');
      }
    }
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

  void tagAsDelivered() {
    if (!isScanned.value) return;

    try {
      final HomeController homeController = Get.find<HomeController>();
      homeController.markOrderAsDelivered('1');
    } catch (e) {
      debugPrint('Error accessing HomeController: $e');
    }

    // Show a beautiful, stylized dialog
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFFFEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 60,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Delivery Confirmed',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2F333A),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'The order has been tagged as delivered successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Color(0xFF8A8F99),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back(); // Close dialog
                    Get.back(); // Pop ReceiptDetailsPage
                    Get.back(); // Pop OrderDetailsPage (goes back to home)
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6533E7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
}
