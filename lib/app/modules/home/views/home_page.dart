import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';
import 'package:p_sosyo_driver/app/widgets/custom_appBar.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sales & Orders stats row
                  _buildStatsRow(),
                  const SizedBox(height: 20),

                  // Custom Tab Selector
                  _buildTabSelector(),
                  const SizedBox(height: 20),

                  // Delivery Cards List
                  _buildDeliveryCards(),
                ],
              ),
            ),
          ),
          
          // Custom Bottom Navigation Bar
          _buildBottomNavBar(),
        ],
      ),
    );
  }

  /// Row showing "Sales Today" and "Delivered Orders" cards.
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.receipt_long_outlined,
            title: 'Sales Today',
            value: '₱ 23,893.12',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_box_outlined,
            title: 'Delivered Orders',
            value: '5',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2EFFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF6533E7),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6533E7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6533E7),
            ),
          ),
        ],
      ),
    );
  }

  /// Custom tab pills switcher: "Out for Delivery" vs "Delivered".
  Widget _buildTabSelector() {
    return Obx(() {
      final active = controller.activeTab.value;
      
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: _buildTabButton(
                label: 'Out for Delivery',
                isSelected: active == 'Out for Delivery',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTabButton(
                label: 'Delivered',
                isSelected: active == 'Delivered',
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => controller.changeTab(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6533E7) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF887DF6),
          ),
        ),
      ),
    );
  }

  /// Builds the list of delivery cards.
  Widget _buildDeliveryCards() {
    return Obx(() {
      final active = controller.activeTab.value;
      
      if (active == 'Delivered') {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'No delivered orders yet',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Color(0xFF8A8F99),
              ),
            ),
          ),
        );
      }

      // 'Out for Delivery' active: show the sample card
      return _buildSampleDeliveryCard();
    });
  }

  /// Single sample delivery card UI representing "TINDAHAN NI ALING NENA".
  Widget _buildSampleDeliveryCard() {
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
          // Header: distance and button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '12m away',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6533E7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Deliver Now',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(
            height: 1,
            color: Color(0xFFF1F1F1),
          ),
          const SizedBox(height: 16),

          // Store image and details row
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

          // SKU and total amount boxes
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
        ],
      ),
    );
  }

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
          Text(
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

  /// Builds custom Bottom Navigation Bar.
  Widget _buildBottomNavBar() {
    return Container(
      color: const Color(0xFFF2EFFF),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBottomBarItem(Icons.sync_rounded, 'Resync', () {}),
          _buildBottomBarItem(Icons.exit_to_app_rounded, 'End of Day', () {}),
          _buildBottomBarItem(Icons.calendar_today_rounded, 'Date', () {}),
        ],
      ),
    );
  }

  Widget _buildBottomBarItem(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF6533E7), size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6533E7),
            ),
          ),
        ],
      ),
    );
  }
}