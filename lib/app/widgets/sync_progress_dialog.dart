import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';
import 'package:p_sosyo_driver/app/widgets/custom_button.dart';

/// Dispatch route sync dialog with live depot-to-store progress indicator,
/// reduced-motion awareness, and unified design-system controls.
class SyncProgressDialog extends StatefulWidget {
  final HomeController controller;

  const SyncProgressDialog({super.key, required this.controller});

  @override
  State<SyncProgressDialog> createState() => _SyncProgressDialogState();
}

class _SyncProgressDialogState extends State<SyncProgressDialog>
    with TickerProviderStateMixin {
  late final AnimationController _roadController;
  late final AnimationController _engineController;
  late final AnimationController _pulseController;
  late final AnimationController _celebrateController;
  bool _reduceMotion = false;
  bool _tickersStarted = false;

  @override
  void initState() {
    super.initState();
    _roadController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _engineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _roadController.stop();
      _engineController.stop();
      _pulseController.stop();
    } else if (!_tickersStarted) {
      _tickersStarted = true;
      _roadController.repeat();
      _engineController.repeat();
      _pulseController.repeat();
    }
  }

  @override
  void dispose() {
    _roadController.dispose();
    _engineController.dispose();
    _pulseController.dispose();
    _celebrateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xxl,
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.surfaceDark.withOpacity(0.16),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Obx(() {
          final isSyncing = widget.controller.isSyncing.value;
          final isCompleted = widget.controller.isSyncCompleted.value;
          final progress = widget.controller.syncProgress.value;
          final status = widget.controller.syncStatusMessage.value;

          if (isCompleted &&
              !_celebrateController.isAnimating &&
              _celebrateController.value == 0) {
            if (_reduceMotion) {
              _celebrateController.value = 1.0;
            } else {
              _celebrateController.forward();
            }
          }

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Top status header row ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHeaderPill(isCompleted, isSyncing),
                    Text(
                      '${((isCompleted ? 1.0 : progress).clamp(0.0, 1.0) * 100).toInt()}%',
                      style: AppTypography.monoRef.copyWith(
                        fontSize: 18,
                        color: isCompleted
                            ? AppColors.success
                            : isSyncing
                                ? AppColors.primary
                                : AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Route Track Canvas ──
                _buildDeliveryRoadTrack(progress, isSyncing, isCompleted),
                const SizedBox(height: AppSpacing.md),

                // ── Clean Segmented Progress Bar ──
                _buildProgressBar(progress, isCompleted),
                const SizedBox(height: AppSpacing.xl),

                // ── Title & Status Copy ──
                _buildTitleAndStatus(isCompleted, isSyncing, status),
                const SizedBox(height: AppSpacing.xxl),

                // ── Primary Action ──
                if (!isSyncing && !isCompleted)
                  CustomButton(
                    label: (widget.controller.syncFailed.value ||
                            !widget.controller.isMandatorySync.value)
                        ? 'Resync'
                        : 'Sync Now',
                    icon: Icons.sync_rounded,
                    onPressed: () => widget.controller.syncDeliveries(),
                  )
                else if (isSyncing && !widget.controller.isMandatorySync.value)
                  OutlinedButton.icon(
                    onPressed: () => widget.controller.minimizeSyncDialog(),
                    icon: const Icon(Icons.open_in_new_off_rounded, size: 18),
                    label: Text(
                      'Sync in Background',
                      style: AppTypography.label.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primaryBorder),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                  )
                else if (isCompleted)
                  CustomButton(
                    label: 'Continue to Route',
                    icon: Icons.check_rounded,
                    variant: CustomButtonVariant.success,
                    onPressed: () => Get.back(),
                  ),
              ],
            ),
          );
        }),
      ),
      ),
    );
  }

  Widget _buildHeaderPill(bool isCompleted, bool isSyncing) {
    final Color bg =
        isCompleted ? AppColors.successTint : AppColors.primaryTint;
    final Color border =
        isCompleted ? AppColors.successBorder : AppColors.primaryBorder;
    final Color fg = isCompleted ? AppColors.success : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSyncing && !_reduceMotion)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) => Transform.rotate(
                angle: _pulseController.value * 2 * math.pi,
                child: Icon(Icons.sync_rounded, size: 14, color: fg),
              ),
            )
          else
            Icon(
              isCompleted
                  ? Icons.check_circle_outline_rounded
                  : Icons.cloud_sync_outlined,
              size: 14,
              color: fg,
            ),
          const SizedBox(width: 6),
          Text(
            isCompleted
                ? 'DISPATCH READY'
                : isSyncing
                    ? 'SYNCING ROUTE'
                    : 'ROUTE SYNC',
            style: AppTypography.micro.copyWith(
              fontSize: 14,
              letterSpacing: 0.7,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryRoadTrack(
    double progress,
    bool isSyncing,
    bool isCompleted,
  ) {
    return Container(
      height: 98,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double trackWidth = constraints.maxWidth;
          final double usableDistance = (trackWidth - 88).clamp(40.0, 400.0);
          final double targetValue = isCompleted
              ? 1.0
              : (isSyncing ? progress.clamp(0.05, 1.0) : 0.04);

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: targetValue),
            duration: _reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, _) {
              final double vanLeft = 36 + (usableDistance * animatedValue);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Road lane (between Depot & Stores stations)
                  Positioned(
                    left: 44,
                    right: 44,
                    top: 24,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AnimatedBuilder(
                        animation: _roadController,
                        builder: (context, _) => CustomPaint(
                          painter: _RoadDashPainter(
                            offset: (isSyncing && !_reduceMotion)
                                ? _roadController.value * 20.0
                                : 0.0,
                            dashColor: AppColors.surface,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Depot Station (Left)
                  const Positioned(
                    left: 0,
                    top: 10,
                    child: _StationNode(
                      icon: Icons.warehouse_outlined,
                      label: 'Depot',
                      isActive: true,
                      isDone: false,
                    ),
                  ),

                  // Stores Station (Right)
                  Positioned(
                    right: 0,
                    top: 10,
                    child: AnimatedBuilder(
                      animation: _celebrateController,
                      builder: (context, child) {
                        final bounce = (isCompleted && !_reduceMotion)
                            ? math.sin(_celebrateController.value * math.pi) *
                                0.1
                            : 0.0;
                        return Transform.scale(
                            scale: 1.0 + bounce, child: child);
                      },
                      child: _StationNode(
                        icon: isCompleted
                            ? Icons.check_rounded
                            : Icons.storefront_outlined,
                        label: 'Stores',
                        isActive: isCompleted,
                        isDone: isCompleted,
                      ),
                    ),
                  ),

                  // Delivery Truck
                  AnimatedBuilder(
                    animation: _engineController,
                    builder: (context, _) {
                      final double bounce = (isSyncing && !_reduceMotion)
                          ? math.sin(_engineController.value * 2 * math.pi) *
                              1.4
                          : 0.0;

                      return Positioned(
                        left: (vanLeft - 22).clamp(20.0, trackWidth - 66),
                        top: 6 + bounce,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Image.asset(
                            'assets/images/truck_3d.png',
                            width: 44,
                            height: 44,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? AppColors.success
                                    : AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.local_shipping_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProgressBar(double progress, bool isCompleted) {
    final target = isCompleted ? 1.0 : progress.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        height: 8,
        width: double.infinity,
        color: AppColors.surfaceMuted,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: target),
          duration:
              _reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.success : AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTitleAndStatus(
    bool isCompleted,
    bool isSyncing,
    String status,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isCompleted
              ? 'Route Sync Complete'
              : isSyncing
                  ? 'Syncing Assigned Route'
                  : 'Sync Today\'s Dispatch',
          style: AppTypography.heading.copyWith(fontSize: 23),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration:
              _reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
          child: Align(
            key: ValueKey<String>('$status-$isCompleted-$isSyncing'),
            alignment: Alignment.centerLeft,
            child: Text(
              isCompleted
                  ? (status.isNotEmpty
                      ? status
                      : 'All customer orders and route details are up to date.')
                  : isSyncing
                      ? (status.isNotEmpty
                          ? status
                          : 'Connecting to dispatch server...')
                      : 'Fetch your assigned delivery stops, store addresses, and item manifests before starting your route.',
              style: AppTypography.body.copyWith(
                fontSize: 18,
                color: isCompleted ? AppColors.success : AppColors.inkMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StationNode extends StatelessWidget {
  const _StationNode({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isDone,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = isDone
        ? AppColors.success
        : isActive
            ? AppColors.primaryBorder
            : AppColors.border;
    final Color bgColor = isDone ? AppColors.successTint : AppColors.surface;
    final Color iconColor = isDone ? AppColors.success : AppColors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1.4),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.micro.copyWith(
            fontSize: 13.5,
            color: isDone ? AppColors.success : AppColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

class _RoadDashPainter extends CustomPainter {
  const _RoadDashPainter({
    required this.offset,
    required this.dashColor,
  });

  final double offset;
  final Color dashColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dashColor
      ..style = PaintingStyle.fill;

    const double dashWidth = 10.0;
    const double dashGap = 10.0;
    const double step = dashWidth + dashGap;
    final double top = (size.height - 2.0) / 2.0;

    for (double x = -step + (offset % step); x < size.width; x += step) {
      canvas.drawRect(Rect.fromLTWH(x, top, dashWidth, 2.0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoadDashPainter oldDelegate) =>
      oldDelegate.offset != offset || oldDelegate.dashColor != dashColor;
}
