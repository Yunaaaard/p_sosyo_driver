import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/utils/peso_formatter.dart';
import 'package:p_sosyo_driver/app/modules/receipt_details/controller/receipt_details_controller.dart';
import 'package:p_sosyo_driver/app/widgets/custom_appBar.dart';
import 'package:p_sosyo_driver/app/widgets/custom_button.dart';

class ReceiptDetailsPage extends GetView<ReceiptDetailsController> {
  const ReceiptDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: const CustomAppBar(
        title: 'Receipt Details',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    // Header card or badge for premium aesthetics
                    _buildHeaderCard(),
                    const SizedBox(height: 24),
                    
                    // Fields
                    Obx(() => _buildField(
                          label: 'Reference Number',
                          value: controller.referenceNumber.value,
                          placeholder: 'Scan a receipt to display details',
                        )),
                    const SizedBox(height: 18),
                    Obx(() => _buildAmountField(
                          label: 'Total Amount Sent',
                          value: controller.totalAmount.value,
                          placeholder: 'Scan a receipt to display details',
                        )),
                    const SizedBox(height: 18),
                    Obx(() => _buildField(
                          label: 'Sender',
                          value: controller.sender.value,
                          placeholder: 'Scan a receipt to display details',
                        )),
                    const SizedBox(height: 18),
                    Obx(() => _buildField(
                          label: 'Date',
                          value: controller.date.value,
                          placeholder: 'Scan a receipt to display details',
                        )),
                  ],
                ),
              ),
            ),
            
            // Bottom Buttons Container
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomButton(
                    label: 'Scan Customer Receipt',
                    onPressed: controller.startScanning,
                  ),
                  const SizedBox(height: 12),
                  Obx(() => CustomButton(
                        label: 'Tag as Delivered',
                        enabled: controller.isScanned.value,
                        onPressed: controller.tagAsDelivered,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6533E7), Color(0xFF887DF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6533E7).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receipt Verification',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Scan the customer\'s e-receipt to verify payment.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFE2E4E8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String value,
    required String placeholder,
  }) {
    final hasValue = value.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2F333A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: hasValue ? Colors.white : const Color(0xFFEAEAEF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasValue ? const Color(0xFFE2E4E8) : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: hasValue
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            hasValue ? value : placeholder,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: hasValue ? const Color(0xFF2F333A) : const Color(0xFFB8BCC5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField({
    required String label,
    required String value,
    required String placeholder,
  }) {
    final hasValue = value.isNotEmpty;
    // Extract the numeric part from the amount string (e.g. "₱ 1,574.00" -> "1,574.00")
    String displayAmount = '';
    if (hasValue) {
      displayAmount = value.replaceAll('₱', '').trim();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2F333A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: hasValue ? Colors.white : const Color(0xFFEAEAEF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasValue ? const Color(0xFFE2E4E8) : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: hasValue
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: hasValue
              ? PesoFormatter.buildPesoText(
                  amount: displayAmount,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF2F333A),
                )
              : Text(
                  placeholder,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFB8BCC5),
                  ),
                ),
        ),
      ],
    );
  }
}