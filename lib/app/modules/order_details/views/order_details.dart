import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/utils/peso_formatter.dart';
import 'package:p_sosyo_driver/app/modules/order_details/controller/order_details_controller.dart';
import 'package:p_sosyo_driver/app/widgets/custom_appBar.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';

class OrderDetailsPage extends GetView<OrderDetailsController> {
  const OrderDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: const CustomAppBar(
        title: 'Order Details',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top card combining stats details & store details
            _buildMainDetailsCard(),
            const SizedBox(height: 16),

            // Order items list
            Obx(() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: controller.items
                    .map((item) => _buildItemCard(item))
                    .toList(),
              );
            }),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFFF6F6F8),
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () => Get.toNamed(AppRoutes.receiptDetails),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6533E7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Scan Customer Reciept',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the main details card containing SKU/Amount boxes, store details, and payment trigger.
  Widget _buildMainDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // SKU and total amount boxes row
          Row(
            children: [
              Expanded(
                child: _buildItemDetailsBox(
                  icon: Icons.inventory_2_outlined,
                  label: 'SKU',
                  value: '32',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildItemDetailsBox(
                  icon: Icons.payments_outlined,
                  label: 'Total Amount',
                  value: '₱ 23,893.12',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(
            height: 1,
            color: Color(0xFFF1F1F1),
          ),
          const SizedBox(height: 16),

          // Store details row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/shop_thumbnail.png',
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TINDAHAN NI ALING NENA',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2F333A),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Fast Distribution Head Office H. Abellana Canduman, Mandaue City Cebu',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        height: 1.3,
                        color: Color(0xFF8A8F99),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Generate QR button
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6533E7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Generate QR for Payment',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Single item details info box (SKU / Total Amount).
  Widget _buildItemDetailsBox({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFFB8BCC5),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Color(0xFF8A8F99),
            ),
          ),
          const Spacer(),
          value.contains('₱')
              ? Text.rich(
                  PesoFormatter.buildPesoTextSpan(
                    amount: value.replaceAll('₱', '').trim(),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2F333A),
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2F333A),
                  ),
                ),
        ],
      ),
    );
  }

  /// Single item card layout showing quantity and total info.
  Widget _buildItemCard(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProductImage(item.title),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2F333A),
                  ),
                ),
                const SizedBox(height: 6),
                PesoFormatter.buildPesoText(
                  amount: item.price,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2F333A),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ordered Qty: ${item.orderedQty}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Color(0xFF8A8F99),
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Total: ',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Color(0xFF8A8F99),
                            ),
                          ),
                          PesoFormatter.buildPesoTextSpan(
                            amount: item.totalAmount,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2F333A),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds customized product image placeholder or thumbnail icon.
  Widget _buildProductImage(String title) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: const Color(0xFFF2EFFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.inventory_2_outlined,
        color: Color(0xFF6533E7),
        size: 32,
      ),
    );
  }
}
