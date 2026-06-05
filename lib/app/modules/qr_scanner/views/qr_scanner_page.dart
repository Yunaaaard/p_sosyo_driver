import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    // Draw background overlay except the cutout
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(cutoutRect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(backgroundPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QrScannerPageState extends State<QrScannerPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _laserAnimation;
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _animationController.forward();
        }
      });

    _animationController.forward();
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
    final size = MediaQuery.of(context).size;
    final double scanAreaSize = size.width * 0.7;
    final double left = (size.width - scanAreaSize) / 2;
    final double top = (size.height - scanAreaSize) / 2 - 40;
    final cutoutRect = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);

    return Scaffold(
      body: Stack(
        children: [
          // Real camera preview
          Positioned.fill(
            child: MobileScanner(
              controller: _cameraController,
              onDetect: _onDetect,
            ),
          ),

          // Custom overlay with transparent cutout
          Positioned.fill(
            child: CustomPaint(
              painter: _ScannerOverlayPainter(cutoutRect: cutoutRect),
            ),
          ),

          // Cutout border decoration
          Positioned(
            left: left - 2,
            top: top - 2,
            width: scanAreaSize + 4,
            height: scanAreaSize + 4,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF6533E7),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),

          // Moving Laser Line
          AnimatedBuilder(
            animation: _laserAnimation,
            builder: (context, child) {
              final laserY = top + (scanAreaSize * _laserAnimation.value);
              return Positioned(
                left: left + 10,
                top: laserY,
                width: scanAreaSize - 20,
                height: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF74E1AE),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF74E1AE).withOpacity(0.8),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () => Get.back(),
            ),
          ),

          // Flash toggle button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: IconButton(
              icon: ValueListenableBuilder(
                valueListenable: _cameraController,
                builder: (context, state, child) {
                  return Icon(
                    state.torchState == TorchState.on
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    color: Colors.white,
                    size: 28,
                  );
                },
              ),
              onPressed: () => _cameraController.toggleTorch(),
            ),
          ),

          // Title / Instruction top
          Positioned(
            top: top - 80,
            left: 20,
            right: 20,
            child: const Text(
              'Scan Receipt QR Code',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Details instruction / Status bottom
          Positioned(
            top: top + scanAreaSize + 30,
            left: 30,
            right: 30,
            child: const Column(
              children: [
                Text(
                  'Align the receipt QR code within the frame to scan automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFB8BCC5),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF74E1AE),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Scanning...',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color(0xFF74E1AE),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
}
