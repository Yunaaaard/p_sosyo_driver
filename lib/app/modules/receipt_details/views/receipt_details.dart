import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/core/utils/peso_formatter.dart';
import 'package:p_sosyo_driver/app/modules/receipt_details/controller/receipt_details_controller.dart';
import 'package:p_sosyo_driver/app/widgets/custom_appBar.dart';
import 'package:p_sosyo_driver/app/widgets/custom_button.dart';
import 'package:p_sosyo_driver/app/widgets/status_badge.dart';

class ReceiptDetailsPage extends GetView<ReceiptDetailsController> {
  const ReceiptDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final targetOrder = controller.order;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const CustomAppBar(
        title: 'Receipt Details',
        showBackButton: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Rounded Target Order Context Card ──────────────────
                    if (targetOrder != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          border:
                              Border.all(color: AppColors.surfaceDarkBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SETTLING ORDER  ·  #${targetOrder.id}',
                                    style: AppTypography.monoRef.copyWith(
                                      fontSize: 13.5,
                                      color: AppColors.mint,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    targetOrder.storeName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.label.copyWith(
                                      fontSize: 18.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'EXPECTED',
                                  style: AppTypography.eyebrow.copyWith(
                                    fontSize: 12.5,
                                    color: Colors.white.withOpacity(0.65),
                                  ),
                                ),
                                Text.rich(
                                  PesoFormatter.buildPesoTextSpan(
                                    amount: targetOrder.totalAmount
                                        .replaceAll('₱', '')
                                        .trim(),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // ── Rounded E-Receipt Verification Card ────────────────
                    Obx(() {
                      final scanned = controller.isScanned.value;
                      final ref = controller.referenceNumber.value;
                      final amount = controller.totalAmount.value;
                      final sender = controller.sender.value;
                      final date = controller.date.value;

                      final borderColor = scanned
                          ? AppColors.successBorder
                          : AppColors.border;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TicketHalfCard(
                            isTop: true,
                            borderColor: borderColor,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.xl,
                                AppSpacing.xl,
                                AppSpacing.xl,
                                AppSpacing.lg,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      StatusPill(
                                        label: scanned
                                            ? 'Receipt Verified'
                                            : 'Awaiting Scan',
                                        isPositive: scanned,
                                        icon: scanned
                                            ? Icons.check_circle_outline_rounded
                                            : Icons.qr_code_scanner_rounded,
                                      ),
                                      Text(
                                        'E-RECEIPT',
                                        style: AppTypography.monoRef.copyWith(
                                          fontSize: 13.5,
                                          color: AppColors.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  if (scanned && amount.isNotEmpty) ...[
                                    Text(
                                      'TOTAL AMOUNT SENT',
                                      style: AppTypography.eyebrow.copyWith(
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: PesoFormatter.buildPesoText(
                                        amount: amount,
                                        fontSize: 38,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.inkPrimary,
                                      ),
                                    ),
                                  ] else
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.lg,
                                        vertical: AppSpacing.xl,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.canvas,
                                        borderRadius:
                                            BorderRadius.circular(AppRadii.md),
                                        border:
                                            Border.all(color: AppColors.border),
                                      ),
                                      child: Column(
                                        children: [
                                          const Icon(
                                            Icons.qr_code_scanner_rounded,
                                            size: 32,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(height: AppSpacing.sm),
                                          Text(
                                            'Scan Customer E-Receipt',
                                            style: AppTypography.title.copyWith(
                                              fontSize: 20,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Verified payment details and reference number will populate here.',
                                            textAlign: TextAlign.center,
                                            style:
                                                AppTypography.caption.copyWith(
                                              fontSize: 16.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          _TicketHalfCard(
                            isTop: false,
                            borderColor: borderColor,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.xl,
                                AppSpacing.lg,
                                AppSpacing.xl,
                                AppSpacing.xl,
                              ),
                              child: Column(
                                children: [
                                  _LedgerRow(
                                    label: 'Reference Number',
                                    value: ref,
                                    placeholder: 'Pending QR scan',
                                    isMonospace: true,
                                  ),
                                  const Divider(
                                    height: 24,
                                    thickness: 1,
                                    color: AppColors.border,
                                  ),
                                  _LedgerRow(
                                    label: 'Total Amount Sent',
                                    value: amount,
                                    placeholder: 'Pending QR scan',
                                    isPeso: true,
                                    isMonospace: true,
                                  ),
                                  const Divider(
                                    height: 24,
                                    thickness: 1,
                                    color: AppColors.border,
                                  ),
                                  _LedgerRow(
                                    label: 'Sender',
                                    value: sender,
                                    placeholder: 'Pending QR scan',
                                  ),
                                  const Divider(
                                    height: 24,
                                    thickness: 1,
                                    color: AppColors.border,
                                  ),
                                  _LedgerRow(
                                    label: 'Date',
                                    value: date,
                                    placeholder: 'Pending QR scan',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: AppSpacing.md),

                    // ── Local Proof of Delivery Capture Card ───────────────
                    Obx(() {
                      final podPath = controller.proofOfDeliveryPath.value;
                      final hasPod =
                          podPath.isNotEmpty && File(podPath).existsSync();
                      final isBusy = controller.isCapturingPod.value;

                      return SurfaceCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        borderRadius: AppRadii.xl,
                        borderColor: hasPod
                            ? AppColors.successBorder
                            : AppColors.border,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'PROOF OF DELIVERY',
                                  style: AppTypography.eyebrow
                                      .copyWith(fontSize: 13.5),
                                ),
                                StatusPill(
                                  label: hasPod ? 'Photo Saved' : 'Required',
                                  isPositive: hasPod,
                                  isDanger: !hasPod,
                                  icon: hasPod
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.camera_alt_outlined,
                                ),
                              ],
                            ),
                            if (hasPod) ...[
                              const SizedBox(height: AppSpacing.md),
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppRadii.md),
                                child: Image.file(
                                  File(podPath),
                                  height: 160,
                                  width: double.infinity,
                                  cacheWidth: (MediaQuery.sizeOf(context).width *
                                          MediaQuery.devicePixelRatioOf(context))
                                      .round(),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            CustomButton(
                              label: hasPod
                                  ? 'Retake Proof of Delivery'
                                  : 'Capture Proof of Delivery',
                              icon: Icons.camera_alt_outlined,
                              variant: CustomButtonVariant.secondary,
                              height: 46,
                              isLoading: isBusy,
                              onPressed: controller.captureProofOfDelivery,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // ── Clean Rounded Bottom Action Dock ────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.xl),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.surfaceDark.withOpacity(0.05),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Obx(() {
                final scanned = controller.isScanned.value;
                final podPath = controller.proofOfDeliveryPath.value.trim();
                final hasPod = podPath.isNotEmpty && File(podPath).existsSync();
                final canTagDelivered = scanned && hasPod;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomButton(
                      label: 'Scan Customer Receipt',
                      icon: Icons.qr_code_scanner_rounded,
                      variant: scanned
                          ? CustomButtonVariant.secondary
                          : CustomButtonVariant.primary,
                      onPressed: controller.startScanning,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomButton(
                      label: 'Tag as Delivered',
                      icon: Icons.check_circle_outline_rounded,
                      variant: CustomButtonVariant.success,
                      enabled: canTagDelivered,
                      onPressed: controller.tagAsDelivered,
                    ),
                    if (scanned && !hasPod) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Capture Proof of Delivery photo above to tag as delivered.',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          fontSize: 13.5,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.label,
    required this.value,
    required this.placeholder,
    this.isMonospace = false,
    this.isPeso = false,
  });

  final String label;
  final String value;
  final String placeholder;
  final bool isMonospace;
  final bool isPeso;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: 17,
              color: AppColors.inkMuted,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerRight,
            child: (hasValue && isPeso)
                ? PesoFormatter.buildPesoText(
                    amount: value,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkPrimary,
                  )
                : Text(
                    hasValue ? value : placeholder,
                    textAlign: TextAlign.right,
                    style: (isMonospace
                            ? AppTypography.monoRef
                            : AppTypography.label)
                        .copyWith(
                      fontSize: 18,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                      color:
                          hasValue ? AppColors.inkPrimary : AppColors.inkSubtle,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _TicketHalfCard extends StatelessWidget {
  const _TicketHalfCard({
    required this.isTop,
    required this.borderColor,
    required this.child,
  });

  final bool isTop;
  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TicketHalfPainter(
        isTop: isTop,
        borderColor: borderColor,
      ),
      child: ClipPath(
        clipper: _TicketHalfClipper(isTop: isTop),
        child: Container(
          color: AppColors.surface,
          child: child,
        ),
      ),
    );
  }
}

Path _buildTicketHalfPath(Size size, {required bool isTop}) {
  const double r = AppRadii.xl;
  const double n = 10.0;
  final double w = size.width;
  final double h = size.height;

  final path = Path();
  if (isTop) {
    path.moveTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0);
    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w, r);
    path.lineTo(w, h - n);
    path.arcToPoint(
      Offset(w - n, h),
      radius: const Radius.circular(n),
      clockwise: false,
    );
    path.lineTo(n, h);
    path.arcToPoint(
      Offset(0, h - n),
      radius: const Radius.circular(n),
      clockwise: false,
    );
    path.close();
  } else {
    path.moveTo(n, 0);
    path.lineTo(w - n, 0);
    path.arcToPoint(
      Offset(w, n),
      radius: const Radius.circular(n),
      clockwise: false,
    );
    path.lineTo(w, h - r);
    path.quadraticBezierTo(w, h, w - r, h);
    path.lineTo(r, h);
    path.quadraticBezierTo(0, h, 0, h - r);
    path.lineTo(0, n);
    path.arcToPoint(
      const Offset(n, 0),
      radius: const Radius.circular(n),
      clockwise: false,
    );
    path.close();
  }
  return path;
}

class _TicketHalfClipper extends CustomClipper<Path> {
  const _TicketHalfClipper({required this.isTop});
  final bool isTop;

  @override
  Path getClip(Size size) => _buildTicketHalfPath(size, isTop: isTop);

  @override
  bool shouldReclip(covariant _TicketHalfClipper oldClipper) =>
      oldClipper.isTop != isTop;
}

class _TicketHalfPainter extends CustomPainter {
  const _TicketHalfPainter({
    required this.isTop,
    required this.borderColor,
  });

  final bool isTop;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double r = AppRadii.xl;
    const double n = 10.0;
    final double w = size.width;
    final double h = size.height;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;

    final outlinePath = Path();
    if (isTop) {
      outlinePath.moveTo(0, h - n);
      outlinePath.lineTo(0, r);
      outlinePath.quadraticBezierTo(0, 0, r, 0);
      outlinePath.lineTo(w - r, 0);
      outlinePath.quadraticBezierTo(w, 0, w, r);
      outlinePath.lineTo(w, h - n);
      outlinePath.arcToPoint(
        Offset(w - n, h),
        radius: const Radius.circular(n),
        clockwise: false,
      );
      final leftArc = Path()
        ..moveTo(n, h)
        ..arcToPoint(
          Offset(0, h - n),
          radius: const Radius.circular(n),
          clockwise: false,
        );
      canvas.drawPath(outlinePath, borderPaint);
      canvas.drawPath(leftArc, borderPaint);

      // Dashed tear rule along the shared seam between top and bottom halves
      final dashPaint = Paint()
        ..color = AppColors.borderStrong
        ..strokeWidth = 1.2;
      double x = n + 4;
      while (x + 6 <= w - n - 4) {
        canvas.drawLine(Offset(x, h), Offset(x + 6, h), dashPaint);
        x += 11;
      }
    } else {
      outlinePath.moveTo(w - n, 0);
      outlinePath.arcToPoint(
        Offset(w, n),
        radius: const Radius.circular(n),
        clockwise: false,
      );
      outlinePath.lineTo(w, h - r);
      outlinePath.quadraticBezierTo(w, h, w - r, h);
      outlinePath.lineTo(r, h);
      outlinePath.quadraticBezierTo(0, h, 0, h - r);
      outlinePath.lineTo(0, n);
      outlinePath.arcToPoint(
        const Offset(n, 0),
        radius: const Radius.circular(n),
        clockwise: false,
      );
      canvas.drawPath(outlinePath, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TicketHalfPainter oldDelegate) =>
      oldDelegate.isTop != isTop || oldDelegate.borderColor != borderColor;
}
