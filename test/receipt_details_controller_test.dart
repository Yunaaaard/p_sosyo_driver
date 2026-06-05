import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/data/services/scanner_service.dart';
import 'package:p_sosyo_driver/app/modules/receipt_details/controller/receipt_details_controller.dart';

class MockScannerService extends ScannerService {
  final String? mockResult;
  MockScannerService(this.mockResult);

  @override
  Future<String?> scanReceipt() async {
    return mockResult;
  }
}

void main() {
  const examplePayload = '''{
    "id": "py-1402feb0-bb79-47ae-9d1e-e69394d3949c",
    "business_id": "5f27a14a9bf05c73dd040bc8",
    "reference_id": "order-id-12345",
    "payment_request_id": "pr-1102feb0-bb79-47ae-9d1e-e69394d3949c",
    "payment_method": {
      "type": "EWALLET",
      "ewallet": {
        "channel_code": "GCASH",
        "channel_properties": {
          "success_return_url": "https://yourwebsite.com/success"
        }
      }
    },
    "amount": 10000.0,
    "currency": "IDR",
    "status": "SUCCEEDED",
    "failure_code": null,
    "created": "2026-05-05T08:12:33.001Z",
    "updated": "2026-06-05T08:13:02.000Z",
    "metadata": {
      "customer_name": "Leonard Famador Tariman",
      "cart_id": "cart_99823"
    }
  }''';

  setUp(() {
    Get.reset();
  });

  test('ReceiptDetailsController parsing of new JSON payload format', () async {
    // Inject Mock Scanner Service
    Get.put<ScannerService>(MockScannerService(examplePayload));
    
    final controller = Get.put(ReceiptDetailsController());
    
    // Call startScanning which will invoke mock scanner and parse example payload
    await controller.startScanning();
    
    // Assertions matching the design
    expect(controller.isScanned.value, isTrue);
    expect(controller.referenceNumber.value, 'py-1402feb0-bb79-47ae-9d1e-e69394d3949c');
    expect(controller.totalAmount.value, '10,000.00');
    expect(controller.sender.value, 'Leonard Famador Tariman');
    expect(controller.receiver.value, 'FAST SOSYO (GCASH)');
    expect(controller.date.value, 'May 5, 2026');
  });

  test('ReceiptDetailsController handles missing or alternative payload values gracefully', () async {
    const alternativePayload = '''{
      "reference_id": "order-id-9999",
      "amount": "1,234.56",
      "metadata": {},
      "created": "InvalidDate"
    }''';

    Get.put<ScannerService>(MockScannerService(alternativePayload));
    final controller = Get.put(ReceiptDetailsController());
    
    await controller.startScanning();
    
    expect(controller.isScanned.value, isTrue);
    expect(controller.referenceNumber.value, 'order-id-9999');
    expect(controller.totalAmount.value, '1,234.56');
    expect(controller.sender.value, '');
    expect(controller.receiver.value, 'FAST SOSYO NESTLE');
    expect(controller.date.value, 'InvalidDate');
  });

  test('ReceiptDetailsController fetches API URL and unwraps record object', () async {
    // Scan the user's new API URL
    Get.put<ScannerService>(MockScannerService('https://api.jsonbin.io/v3/b/6a19003eddf5aa59f7728e71'));
    final controller = Get.put(ReceiptDetailsController());
    
    await controller.startScanning();
    
    expect(controller.isScanned.value, isTrue);
    expect(controller.referenceNumber.value, 'py-1402feb0-bb79-47ae-9d1e-e69394d3949c');
    expect(controller.totalAmount.value, '10,000.00');
    expect(controller.sender.value, 'Leonard Famador Tariman');
    expect(controller.receiver.value, 'FAST SOSYO (GCASH)');
    expect(controller.date.value, 'May 5, 2026');
  });
}
