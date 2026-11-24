import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/constants/app_constants.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';

/// Branded driver navigation drawer housing Notifications, Van Loadout,
/// Route Planner, Route Calendar, Cash Remittance, Offline Sync Queue, and End of Day.
class HomeSidebarDrawer extends StatelessWidget {
  const HomeSidebarDrawer({
    super.key,
    required this.controller,
    required this.onOpenNotifications,
  });

  final HomeController controller;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(AppRadii.xl),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Branded Dark Cobalt Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xxxl,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surfaceDark,
                  Color(0xFF1542B5),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Obx(() {
                final activeCount = controller.orders
                    .where((o) =>
                        o.status.value == 'Out for Delivery' && !o.isLocked)
                    .length;
                final deliveredCount = controller.deliveredCount.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: SvgPicture.asset(
                            AppConstants.paqnerLogoAsset,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Driver Dispatch',
                                style: AppTypography.title.copyWith(
                                  fontSize: 19,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '$activeCount active · $deliveredCount delivered',
                                style: AppTypography.monoRef.copyWith(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }),
            ),
          ),

          // ── Navigation Menu Items ──
          Expanded(
            child: Obx(() {
              final smsAlerts = controller.ordersMissingPhone.length +
                  controller.ordersPendingSmsWithPhone.length;
              final pendingSync = controller.orders
                  .where((o) => o.syncStatus == 'pending')
                  .length;

              return ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                children: [
                  const _DrawerSectionLabel('ALERTS & LOGISTICS'),
                  _DrawerMenuTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications & SMS',
                    subtitle: smsAlerts > 0
                        ? '$smsAlerts customer SMS / phone alert(s)'
                        : 'All customer alerts up to date',
                    badgeCount: smsAlerts,
                    badgeColor: AppColors.warning,
                    onTap: () {
                      Navigator.of(context).pop();
                      onOpenNotifications();
                    },
                  ),
                  _DrawerMenuTile(
                    icon: Icons.inventory_2_outlined,
                    title: 'Van Loadout Manifest',
                    subtitle: 'LIFO truck loading & SKU picking list',
                    onTap: () {
                      Navigator.of(context).pop();
                      Get.toNamed(AppRoutes.vanLoadout);
                    },
                  ),
                  _DrawerMenuTile(
                    icon: Icons.alt_route_rounded,
                    title: 'Route Planner',
                    subtitle: 'Today & Weekly sequencing, priority & depot',
                    onTap: () {
                      Navigator.of(context).pop();
                      Get.toNamed(
                        AppRoutes.routePlanner,
                        arguments: {'mode': 'today'},
                      );
                    },
                  ),
                  _DrawerMenuTile(
                    icon: Icons.calendar_month_rounded,
                    title: 'Route Calendar',
                    subtitle: 'Schedule by unloading & delivery date',
                    onTap: () {
                      Navigator.of(context).pop();
                      Get.toNamed(AppRoutes.routeCalendar);
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                  const _DrawerSectionLabel('REMITTANCE & SYNC'),
                  _DrawerMenuTile(
                    icon: Icons.payments_outlined,
                    title: 'Cash Remittance',
                    subtitle: 'Cash vs QR breakdown & bill counter',
                    onTap: () {
                      Navigator.of(context).pop();
                      Get.toNamed(AppRoutes.cashRemittance);
                    },
                  ),
                  _DrawerMenuTile(
                    icon: Icons.cloud_sync_outlined,
                    title: 'Offline Sync Queue',
                    subtitle: pendingSync > 0
                        ? '$pendingSync local update(s) waiting to upload'
                        : 'All updates synced',
                    badgeCount: pendingSync,
                    badgeColor: AppColors.primary,
                    onTap: () {
                      Navigator.of(context).pop();
                      Get.toNamed(AppRoutes.syncQueue);
                    },
                  ),
                  _DrawerMenuTile(
                    icon: Icons.assessment_outlined,
                    title: 'End of Day Report',
                    subtitle: 'Shift totals, attempts & thermal print',
                    onTap: () {
                      Navigator.of(context).pop();
                      Get.toNamed(AppRoutes.endOfDay);
                    },
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Text(
        text,
        style: AppTypography.monoRef.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }
}

class _DrawerMenuTile extends StatelessWidget {
  const _DrawerMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeCount = 0,
    this.badgeColor = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badgeCount;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.label.copyWith(fontSize: 14.5),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          fontSize: 12,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: AppTypography.monoRef.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
