import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';

/// An animated, creative, and fun sync progress dialog featuring:
/// - Continuously moving asphalt road dashed markings (infinite scroll)
/// - Delivery van suspension bobbing & driving tilt
/// - Animated exhaust smoke puffs & speed motion particles
/// - Radio broadcast pulse waves radiating from the dispatch Depot
/// - Glowing shimmer wave on the progress bar
/// - Celebratory confetti burst on arrival at 100%
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
  late final AnimationController _exhaustController;
  late final AnimationController _shimmerController;
  late final AnimationController _pulseController;
  late final AnimationController _celebrateController;

  @override
  void initState() {
    super.initState();

    // 1. Road scrolling animation (600ms loop)
    _roadController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();

    // 2. Van engine vibration / suspension bob (380ms loop)
    _engineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..repeat();

    // 3. Exhaust smoke puffs animation (550ms loop)
    _exhaustController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat();

    // 4. Shimmer wave on progress bar (1500ms loop)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // 5. Depot radio pulse waves (1400ms loop)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // 6. Celebration burst animation (plays when complete)
    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _roadController.dispose();
    _engineController.dispose();
    _exhaustController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    _celebrateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E1B4B).withOpacity(0.18),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Obx(() {
          final isSyncing = widget.controller.isSyncing.value;
          final isCompleted = widget.controller.isSyncCompleted.value;
          final progress = widget.controller.syncProgress.value;
          final status = widget.controller.syncStatusMessage.value;

          if (isCompleted && !_celebrateController.isAnimating && _celebrateController.value == 0) {
            _celebrateController.forward();
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Top Header Pill ──
                _buildHeaderPill(isCompleted, isSyncing),
                const SizedBox(height: 20),

                // ── Interactive Animated Delivery Road Track ──
                _buildDeliveryRoadTrack(progress, isSyncing, isCompleted),
                const SizedBox(height: 16),

                // ── Shimmering Gradient Progress Bar ──
                _buildShimmerProgressBar(progress, isCompleted),
                const SizedBox(height: 20),

                // ── Title & Animated Status Text ──
                _buildTitleAndStatus(isCompleted, isSyncing, status),
                const SizedBox(height: 24),

                // ── Action Buttons ──
                if (!isSyncing && !isCompleted)
                  _buildSyncNowButton()
                else if (isCompleted)
                  _buildDoneButton(),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// Top pill badge showing live state with pulsing icon.
  Widget _buildHeaderPill(bool isCompleted, bool isSyncing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFE8FDF3) : const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF10B981).withOpacity(0.3)
              : const Color(0xFF6533E7).withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSyncing)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) => Transform.rotate(
                angle: _pulseController.value * 2 * math.pi,
                child: const Icon(
                  Icons.sync_rounded,
                  size: 15,
                  color: Color(0xFF6533E7),
                ),
              ),
            )
          else
            Icon(
              isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.cloud_sync_rounded,
              size: 15,
              color: isCompleted
                  ? const Color(0xFF047857)
                  : const Color(0xFF6533E7),
            ),
          const SizedBox(width: 6),
          Text(
            isCompleted
                ? 'DISPATCH READY'
                : isSyncing
                    ? 'SYNCING DELIVERIES'
                    : 'MANDATORY SYNC',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isCompleted
                  ? const Color(0xFF047857)
                  : const Color(0xFF6533E7),
            ),
          ),
        ],
      ),
    );
  }

  /// Animated road track with moving road dashes, delivery truck suspension,
  /// exhaust smoke puffs, radio broadcast halos, and confetti on completion.
  Widget _buildDeliveryRoadTrack(
      double progress, bool isSyncing, bool isCompleted) {
    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFECE7FE),
          width: 1.5,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double trackWidth = constraints.maxWidth;
          final double usableDistance = trackWidth - 84;

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0.0,
              end: isCompleted ? 1.0 : (isSyncing ? progress : 0.05),
            ),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, _) {
              final double vanLeft = 40 + (usableDistance * animatedValue);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Asphalt Road with Continuous Scrolling Dashed Lines
                  Positioned(
                    left: 24,
                    right: 24,
                    top: 56,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDD9EE),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: isSyncing
                          ? AnimatedBuilder(
                              animation: _roadController,
                              builder: (context, _) {
                                final offset = _roadController.value * 22;
                                return Stack(
                                  children: [
                                    Positioned(
                                      left: -offset,
                                      right: -24,
                                      top: 4,
                                      child: Row(
                                        children: List.generate(
                                          20,
                                          (i) => Container(
                                            margin: const EdgeInsets.only(right: 12),
                                            width: 10,
                                            height: 2.5,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            )
                          : Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: List.generate(
                                  8,
                                  (i) => Container(
                                    width: 10,
                                    height: 2.5,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.85),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),

                  // 2. Radio Pulse Halo from Depot Warehouse (Broadcast Animation)
                  if (isSyncing)
                    Positioned(
                      left: 1,
                      top: 17,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          final scale = 1.0 + (_pulseController.value * 0.7);
                          final opacity = (1.0 - _pulseController.value).clamp(0.0, 1.0);
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF6533E7).withOpacity(opacity * 0.45),
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // 3. Depot Station (Left)
                  Positioned(
                    left: 0,
                    top: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFD6D0FE),
                              width: 1.6,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6533E7).withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.warehouse_rounded,
                            size: 21,
                            color: Color(0xFF6533E7),
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Depot',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8A8F99),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. Stores Destination Station (Right) with Celebration Elastic Bounce
                  Positioned(
                    right: 0,
                    top: 16,
                    child: AnimatedBuilder(
                      animation: _celebrateController,
                      builder: (context, child) {
                        final bounce = isCompleted
                            ? (math.sin(_celebrateController.value * math.pi) * 0.15)
                            : 0.0;
                        return Transform.scale(
                          scale: 1.0 + bounce,
                          child: child,
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? const Color(0xFFE8FDF3)
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isCompleted
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFD6D0FE),
                                width: 1.6,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isCompleted
                                      ? const Color(0xFF10B981).withOpacity(0.35)
                                      : const Color(0xFF6533E7).withOpacity(0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              isCompleted
                                  ? Icons.task_alt_rounded
                                  : Icons.storefront_rounded,
                              size: 21,
                              color: isCompleted
                                  ? const Color(0xFF047857)
                                  : const Color(0xFF6533E7),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Stores',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isCompleted
                                  ? const Color(0xFF047857)
                                  : const Color(0xFF8A8F99),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 5. Celebration Confetti Sparkles when 100% is reached
                  if (isCompleted)
                    ..._buildConfettiSparkles(trackWidth),

                  // 6. Driving Delivery Van with Engine Suspension & Exhaust Puffs
                  AnimatedBuilder(
                    animation: Listenable.merge([_engineController, _exhaustController]),
                    builder: (context, _) {
                      final double bounce = isSyncing
                          ? (math.sin(_engineController.value * 2 * math.pi) * 2.2)
                          : 0.0;
                      final double tilt = isSyncing
                          ? (math.sin(_engineController.value * 2 * math.pi) * 0.035)
                          : 0.0;

                      return Positioned(
                        left: (vanLeft - 24).clamp(0.0, trackWidth - 52),
                        top: 4 + bounce,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Floating Speech Bubble for %
                            if (isSyncing || isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF6533E7),
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isCompleted
                                              ? const Color(0xFF059669)
                                              : const Color(0xFF6533E7))
                                          .withOpacity(0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${(animatedValue * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            else
                              const SizedBox(height: 16),
                            const SizedBox(height: 3),

                            // 3D Fluency Truck with Tilt & Exhaust
                            Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                // Animated Exhaust Smoke Clouds (Left/Back of truck)
                                if (isSyncing)
                                  Positioned(
                                    left: -10 - (_exhaustController.value * 14),
                                    top: 20 + (_exhaustController.value * 3),
                                    child: Opacity(
                                      opacity: (1.0 - _exhaustController.value).clamp(0.0, 1.0),
                                      child: Container(
                                        width: 8 + (_exhaustController.value * 6),
                                        height: 8 + (_exhaustController.value * 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFB4A5FE).withOpacity(0.65),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),

                                // 3D Fluency Delivery Truck
                                Transform.rotate(
                                  angle: tilt,
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Image.asset(
                                      'assets/images/truck_3d.png',
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => Image.network(
                                        'https://img.icons8.com/3d-fluency/94/truck.png',
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: isCompleted
                                                  ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                                  : [const Color(0xFF7C3AED), const Color(0xFF6533E7)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(11),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.local_shipping_rounded,
                                              color: Colors.white,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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

  /// Shimmering progress bar with moving light wave.
  Widget _buildShimmerProgressBar(double progress, bool isCompleted) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 11,
        width: double.infinity,
        color: const Color(0xFFECE7FE),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: 0.0,
            end: isCompleted ? 1.0 : progress,
          ),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          builder: (context, animatedValue, _) {
            return FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: animatedValue.clamp(0.0, 1.0),
              child: AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, _) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCompleted
                            ? [
                                const Color(0xFF10B981),
                                const Color(0xFF34D399),
                                const Color(0xFF059669),
                              ]
                            : [
                                const Color(0xFF6533E7),
                                const Color(0xFF9333EA),
                                const Color(0xFF38BDF8),
                                const Color(0xFF6533E7),
                              ],
                        stops: isCompleted
                            ? const [0.0, 0.5, 1.0]
                            : [
                                0.0,
                                (_shimmerController.value * 0.6 + 0.1).clamp(0.0, 0.7),
                                (_shimmerController.value * 0.6 + 0.4).clamp(0.2, 0.95),
                                1.0,
                              ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isCompleted
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF6533E7))
                              .withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  /// Confetti burst effect around destination on sync completion.
  List<Widget> _buildConfettiSparkles(double trackWidth) {
    return [
      Positioned(
        right: 8,
        top: 4,
        child: AnimatedBuilder(
          animation: _celebrateController,
          builder: (context, _) => Transform.rotate(
            angle: _celebrateController.value * math.pi,
            child: Transform.scale(
              scale: _celebrateController.value,
              child: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
            ),
          ),
        ),
      ),
      Positioned(
        right: 42,
        top: 2,
        child: AnimatedBuilder(
          animation: _celebrateController,
          builder: (context, _) => Transform.scale(
            scale: _celebrateController.value,
            child: const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF10B981)),
          ),
        ),
      ),
      Positioned(
        right: 18,
        top: 60,
        child: AnimatedBuilder(
          animation: _celebrateController,
          builder: (context, _) => Transform.scale(
            scale: _celebrateController.value,
            child: const Icon(Icons.star_rounded, size: 14, color: Color(0xFF8B5CF6)),
          ),
        ),
      ),
    ];
  }

  /// Title & Animated Status message.
  Widget _buildTitleAndStatus(
      bool isCompleted, bool isSyncing, String status) {
    return Column(
      children: [
        Text(
          isCompleted
              ? 'Sync Completed! 🎉'
              : isSyncing
                  ? 'Syncing Your Route...'
                  : 'Mandatory Route Sync',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            isCompleted
                ? status.isNotEmpty
                    ? status
                    : 'All customer orders and route details are up to date!'
                : isSyncing
                    ? status.isNotEmpty
                        ? status
                        : 'Connecting to dispatch server...'
                    : 'Sync now to fetch your latest delivery orders, store routes, and package lists.',
            key: ValueKey<String>(status + isCompleted.toString()),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              height: 1.4,
              color: isCompleted
                  ? const Color(0xFF047857)
                  : const Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }

  /// Button shown prior to initiating sync.
  Widget _buildSyncNowButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF6533E7), Color(0xFF5025D1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6533E7).withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => widget.controller.syncDeliveries(),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sync_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Sync Now',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Celebration button shown once sync is completed.
  Widget _buildDoneButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Get.back(),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  "Let's Deliver! 🚀",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
