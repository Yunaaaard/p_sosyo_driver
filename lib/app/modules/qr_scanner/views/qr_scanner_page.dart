import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _ScannerOverlayPainter extends CustomPainter {
  final Rect cutoutRect;

  _ScannerOverlayPainter({required this.cutoutRect});

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPaint = Paint()
      ..color = AppColors.surfaceDark.withOpacity(0.72)
      ..style = PaintingStyle.fill;

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(cutoutRect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(backgroundPath, scrimPaint);

    // Subtle hairline border around the frame
    final framePaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutoutRect, const Radius.circular(20)),
      framePaint,
    );

    // Crisp corner reticle brackets in Signal Mint
    final bracketPaint = Paint()
      ..color = AppColors.mint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const double len = 28;
    const double r = 20;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(cutoutRect.left, cutoutRect.top + len)
        ..lineTo(cutoutRect.left, cutoutRect.top + r)
        ..arcToPoint(
          Offset(cutoutRect.left + r, cutoutRect.top),
          radius: const Radius.circular(r),
        )
        ..lineTo(cutoutRect.left + len, cutoutRect.top),
      bracketPaint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(cutoutRect.right - len, cutoutRect.top)
        ..lineTo(cutoutRect.right - r, cutoutRect.top)
        ..arcToPoint(
          Offset(cutoutRect.right, cutoutRect.top + r),
          radius: const Radius.circular(r),
        )
        ..lineTo(cutoutRect.right, cutoutRect.top + len),
      bracketPaint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(cutoutRect.right, cutoutRect.bottom - len)
        ..lineTo(cutoutRect.right, cutoutRect.bottom - r)
        ..arcToPoint(
          Offset(cutoutRect.right - r, cutoutRect.bottom),
          radius: const Radius.circular(r),
        )
        ..lineTo(cutoutRect.right - len, cutoutRect.bottom),
      bracketPaint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(cutoutRect.left + len, cutoutRect.bottom)
        ..lineTo(cutoutRect.left + r, cutoutRect.bottom)
        ..arcToPoint(
          Offset(cutoutRect.left, cutoutRect.bottom - r),
          radius: const Radius.circular(r),
        )
        ..lineTo(cutoutRect.left, cutoutRect.bottom - len),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) =>
      oldDelegate.cutoutRect != cutoutRect;
}

class _QrScannerPageState extends State<QrScannerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _laserAnimation;
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _hasScanned = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _laserAnimation = Tween<double>(begin: 0.06, end: 0.94).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _animationController.stop();
      _animationController.value = 0.5;
    } else if (!_animationController.isAnimating) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        _hasScanned = true;
        _cameraController.stop();
        Get.back(result: barcode.rawValue!);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;
          final double height = constraints.maxHeight;
          final double topInset = MediaQuery.paddingOf(context).top;
          final double bottomInset = MediaQuery.paddingOf(context).bottom;
          final double scanAreaSize =
              math.min(width * 0.68, height * 0.42).clamp(200.0, 290.0);
          final double left = (width - scanAreaSize) / 2;
          final double minTop = topInset + 84.0;
          final double maxTop =
              math.max(minTop, height - bottomInset - scanAreaSize - 136.0);
          final double top =
              ((height - scanAreaSize) / 2 - 16).clamp(minTop, maxTop);
          final cutoutRect =
              Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);

          return SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Real camera preview
                Positioned.fill(
                  child: MobileScanner(
                    controller: _cameraController,
                    onDetect: _onDetect,
                  ),
                ),

                // Scrim & reticle brackets
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ScannerOverlayPainter(cutoutRect: cutoutRect),
                  ),
                ),

                // Scanning laser line
                AnimatedBuilder(
                  animation: _laserAnimation,
                  builder: (context, _) {
                    final laserY = top + (scanAreaSize * _laserAnimation.value);
                    return Positioned(
                      left: left + 18,
                      top: laserY,
                      width: scanAreaSize - 36,
                      height: 2.5,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  },
                ),

                // Responsive Top Controls (explicitly Positioned so Stack fills screen)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _ScannerIconButton(
                            icon: Icons.close_rounded,
                            tooltip: 'Close scanner',
                            onTap: () => Get.back(),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark.withOpacity(0.82),
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.18),
                              ),
                            ),
                            child: Text(
                              'SCAN RECEIPT QR',
                              style: AppTypography.monoRef.copyWith(
                                fontSize: 15,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          ValueListenableBuilder(
                            valueListenable: _cameraController,
                            builder: (context, state, _) {
                              final torchOn = state.torchState == TorchState.on;
                              return _ScannerIconButton(
                                icon: torchOn
                                    ? Icons.flash_on_rounded
                                    : Icons.flash_off_rounded,
                                tooltip: torchOn
                                    ? 'Turn flash off'
                                    : 'Turn flash on',
                                isActive: torchOn,
                                onTap: () => _cameraController.toggleTorch(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Instruction Card
                Positioned(
                  left: AppSpacing.xxl,
                  right: AppSpacing.xxl,
                  bottom: 20,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.16),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Align the customer\'s e-receipt QR code within the frame.',
                            textAlign: TextAlign.center,
                            style: AppTypography.body.copyWith(
                              fontSize: 17.5,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.mint,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ready to scan automatically',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 15.5,
                                  color: AppColors.mint,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScannerIconButton extends StatelessWidget {
  const _ScannerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive
            ? AppColors.primary
            : AppColors.surfaceDark.withOpacity(0.78),
        shape: CircleBorder(
          side: BorderSide(
            color: Colors.white.withOpacity(0.16),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
