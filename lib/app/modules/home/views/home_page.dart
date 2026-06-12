import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/utils/peso_formatter.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';
import 'package:p_sosyo_driver/app/widgets/custom_appBar.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: const CustomAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Fixed: stats row ───────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildStatsRow(),
          ),
          const SizedBox(height: 20),

          // ── Fixed: tab selector ────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildTabSelector(),
          ),
          const SizedBox(height: 20),

          // ── Scrollable: delivery cards only ────
          Expanded(
            child: Obx(() {
              final active = controller.activeTab.value;
              final filtered = controller.orders
                  .where((o) => o.status.value == active)
                  .toList();

              if (filtered.isEmpty) {
                final emptyMsg = active == 'Delivered'
                    ? 'No delivered orders yet'
                    : 'No orders out for delivery';
                return Center(
                  child: Text(
                    emptyMsg,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Color(0xFF8A8F99),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: filtered.length,
                itemBuilder: (context, index) =>
                    _buildDeliveryCard(filtered[index]),
              );
            }),
          ),

          // ── Fixed: bottom nav bar ──────────────
          _buildBottomNavBar(),
        ],
      ),
    );
  }

  /// Row showing "Sales Today" and "Delivered Orders" cards.
  Widget _buildStatsRow() {
    return Obx(() {
      String formatSales(double value) {
        final parts = value.toStringAsFixed(2).split('.');
        final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
        parts[0] = parts[0].replaceAllMapped(regExp, (Match m) => ',');
        return parts.join('.');
      }

      return Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.receipt_long_outlined,
              title: 'Sales Today',
              value: '₱ ${formatSales(controller.totalSales.value)}',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.check_box_outlined,
              title: 'Delivered Orders',
              value: '${controller.deliveredCount.value}',
            ),
          ),
        ],
      );
    });
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
              Icon(icon, color: const Color(0xFF6533E7), size: 20),
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
          value.contains('₱')
              ? Text.rich(
                  PesoFormatter.buildPesoTextSpan(
                    amount: value.replaceAll('₱', '').trim(),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6533E7),
                  ),
                )
              : Text(
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

      return Row(
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

  /// Single delivery card UI.
  Widget _buildDeliveryCard(DeliveryOrder order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Header: distance and button / status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    order.distance,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              Obx(() {
                if (order.status.value == 'Delivered') {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFFFEE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF10B981),
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Delivered',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return ElevatedButton(
                    onPressed: () => Get.toNamed(AppRoutes.orderDetails),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6533E7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
                  );
                }
              }),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F1F1)),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.storeName,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2F333A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      order.address,
                      style: const TextStyle(
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
                  svgPath: 'assets/icons/sku-icon.svg',
                  label: 'SKU',
                  value: order.sku,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildItemDetailsBox(
                  icon: Icons.payments_outlined,
                  label: 'Total Amount',
                  value: order.totalAmount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemDetailsBox({
    IconData? icon,
    String? svgPath,
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
          svgPath != null
              ? SvgPicture.asset(
                  svgPath,
                  width: 15,
                  height: 15,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFFB8BCC5),
                    BlendMode.srcIn,
                  ),
                )
              : Icon(icon, color: const Color(0xFFB8BCC5), size: 16),
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

  /// Builds custom Bottom Navigation Bar.
  Widget _buildBottomNavBar() {
    return Container(
      color: const Color(0xFFF2EFFF),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBottomBarItem(
            svgPath: 'assets/icons/resync-icon.svg',
            label: 'Resync',
            onTap: () => controller.showSyncDialog(),
          ),
          _buildBottomBarItem(
            svgPath: 'assets/icons/endofday_icon.svg',
            label: 'End of Day',
            onTap: () {},
          ),
          _buildBottomBarItem(
            svgPath: 'assets/icons/date-icon.svg',
            label: 'Date',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBarItem({
    required String svgPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            svgPath,
            width: 28,
            height: 28,
            colorFilter: const ColorFilter.mode(
              Color(0xFF6533E7),
              BlendMode.srcIn,
            ),
          ),
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