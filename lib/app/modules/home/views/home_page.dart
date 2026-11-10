import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/utils/peso_formatter.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';
import 'package:p_sosyo_driver/app/widgets/custom_appBar.dart';
import 'package:p_sosyo_driver/app/widgets/store_image_widget.dart';

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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFECEEF2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B4B).withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF6533E7), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
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
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E212D),
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E212D),
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
      final outForDeliveryCount = controller.orders
          .where((o) => o.status.value == 'Out for Delivery')
          .length;
      final deliveredCount = controller.orders
          .where((o) => o.status.value == 'Delivered')
          .length;

      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFEEEAFE),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTabButton(
                label: 'Out for Delivery',
                count: outForDeliveryCount,
                isSelected: active == 'Out for Delivery',
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildTabButton(
                label: 'Delivered',
                count: deliveredCount,
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
    required int count,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => controller.changeTab(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6533E7) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6533E7).withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF7E73E8),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.25)
                    : const Color(0xFFDDD6FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF6533E7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Single delivery card UI.
  Widget _buildDeliveryCard(DeliveryOrder order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFECEEF2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B4B).withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF1E1B4B).withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: const Color(0xFF6533E7).withOpacity(0.06),
          highlightColor: const Color(0xFF6533E7).withOpacity(0.03),
          onTap: () => Get.toNamed(AppRoutes.orderDetails, arguments: order),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Top Badges Row (Status Pill + Reference Number Tag)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status Badge
                    Obx(() {
                      final isDelivered = order.status.value == 'Delivered';
                      if (isDelivered) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8FDF3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF059669),
                                size: 14,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Delivered',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Row(
                        children: [
                          // On-Time Pulse Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8FDF3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF10B981).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'On Time',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Distance Chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F7F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.near_me_rounded,
                                  size: 11,
                                  color: Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  order.distance.isNotEmpty
                                      ? order.distance
                                      : 'Ready',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),

                    // Reference Number Tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F0FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFE0D7FE),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.receipt_long_rounded,
                            size: 12,
                            color: Color(0xFF6533E7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            order.id,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6533E7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2. Store Thumbnail, Name, Address & Expected Date
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Storefront Icon Box / Tagged Store Photo
                    StoreImageWidget(
                      imageUrl: order.storePhoto,
                      custCode: order.custCode,
                      width: 58,
                      height: 58,
                      borderRadius: BorderRadius.circular(16),
                      fallback: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6533E7), Color(0xFF887DF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6533E7).withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.storefront_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Store Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.storeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E212D),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.location_on_outlined,
                                  size: 13,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  order.address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    height: 1.35,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 11,
                                color: Color(0xFF9CA3AF),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Delivery: ${order.deliveryDate.isNotEmpty ? order.deliveryDate : 'Scheduled'}',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF8A8F99),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Unified Bottom Metrics Strip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FD),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFEEF0F6),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Items count
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEEAFE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              size: 14,
                              color: Color(0xFF6533E7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${order.sku} ${order.sku == '1' ? 'Item' : 'Items'}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),

                      // Order Value
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'TOTAL AMOUNT',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text.rich(
                            PesoFormatter.buildPesoTextSpan(
                              amount: order.totalAmount
                                  .replaceAll('₱', '')
                                  .trim(),
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF6533E7),
                            ),
                          ),
                        ],
                      ),

                      // Action Button / Arrow
                      Obx(() {
                        final isDelivered = order.status.value == 'Delivered';
                        if (isDelivered) {
                          return Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8FDF3),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF10B981).withOpacity(0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 13,
                              color: Color(0xFF059669),
                            ),
                          );
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6533E7), Color(0xFF7A4CF0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6533E7).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Deliver',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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