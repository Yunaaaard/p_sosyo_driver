import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/core/utils/peso_formatter.dart';
import 'package:p_sosyo_driver/app/modules/cash_remittance/controller/cash_remittance_controller.dart';
import 'package:p_sosyo_driver/app/widgets/custom_appBar.dart';
import 'package:p_sosyo_driver/app/widgets/status_badge.dart';

class CashRemittancePage extends StatelessWidget {
  const CashRemittancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<CashRemittanceController>()
        ? Get.find<CashRemittanceController>()
        : Get.put(CashRemittanceController());

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const CustomAppBar(
        title: 'Cash Remittance',
        showBackButton: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final expected = controller.expectedCashTotal;
        final counted = controller.countedCashTotal;
        final digital = controller.digitalQrTotal;
        final variance = controller.variance;
        final isExact = variance.abs() < 0.01;
        final isOver = variance > 0.01;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Dark Remittance Summary Card ──
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'COUNTED CASH',
                          style: AppTypography.monoRef.copyWith(
                            fontSize: 11.5,
                            color: Colors.white70,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isExact
                                ? AppColors.success
                                : isOver
                                    ? AppColors.primary
                                    : AppColors.danger,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            isExact
                                ? 'EXACT MATCH'
                                : isOver
                                    ? 'OVER +₱${PesoFormatter.formatAmount(variance)}'
                                    : 'SHORT -₱${PesoFormatter.formatAmount(variance.abs())}',
                            style: AppTypography.monoRef.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₱ ${PesoFormatter.formatAmount(counted)}',
                      style: AppTypography.display.copyWith(
                        fontSize: 30,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryMiniStat(
                            label: 'Expected Cash',
                            value: '₱ ${PesoFormatter.formatAmount(expected)}',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _SummaryMiniStat(
                            label: 'Digital / QR',
                            value: '₱ ${PesoFormatter.formatAmount(digital)}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Denomination Counter ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: SectionHeader(title: 'Cash Denomination Counter'),
                  ),
                  TextButton(
                    onPressed: controller.resetCounts,
                    child: Text(
                      'Reset',
                      style: AppTypography.label.copyWith(
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              SurfaceCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: CashRemittanceController.denominations.map((denom) {
                    final count = controller.denominationCounts[denom] ?? 0;
                    final subtotal = denom * count;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(
                              '₱$denom',
                              style: AppTypography.monoRef.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                controller.decrementDenomination(denom),
                            icon: const Icon(Icons.remove_circle_outline),
                            color: AppColors.inkMuted,
                            iconSize: 22,
                            visualDensity: VisualDensity.compact,
                          ),
                          SizedBox(
                            width: 36,
                            child: Text(
                              '$count',
                              textAlign: TextAlign.center,
                              style: AppTypography.monoRef.copyWith(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                controller.incrementDenomination(denom),
                            icon: const Icon(Icons.add_circle_outline),
                            color: AppColors.primary,
                            iconSize: 22,
                            visualDensity: VisualDensity.compact,
                          ),
                          Expanded(
                            child: Text(
                              '₱ ${PesoFormatter.formatAmount(subtotal.toDouble())}',
                              textAlign: TextAlign.right,
                              style: AppTypography.monoRef.copyWith(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: count > 0
                                    ? AppColors.inkPrimary
                                    : AppColors.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(title: 'Delivered Payment Breakdown'),
              const SizedBox(height: AppSpacing.sm),
              if (controller.deliveredOrders.isEmpty)
                SurfaceCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'No delivered orders yet. Mark a stop delivered to track Cash vs Digital/QR remittance here.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      fontSize: 13.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                )
              else
                ...controller.deliveredOrders.map((order) {
                  final isQr = order.paymentMethod == 'Digital/QR';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: SurfaceCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 2,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.storeName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.label.copyWith(
                                    fontSize: 14.5,
                                  ),
                                ),
                                Text(
                                  order.totalAmount,
                                  style: AppTypography.monoRef.copyWith(
                                    fontSize: 12.5,
                                    color: AppColors.inkSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () =>
                                controller.toggleOrderPaymentMethod(order),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isQr
                                    ? AppColors.primaryTint
                                    : AppColors.successTint,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.pill),
                                border: Border.all(
                                  color: isQr
                                      ? AppColors.primaryBorder
                                      : AppColors.successBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isQr
                                        ? Icons.qr_code_2_rounded
                                        : Icons.payments_outlined,
                                    size: 14,
                                    color: isQr
                                        ? AppColors.primary
                                        : AppColors.success,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    order.paymentMethod,
                                    style: AppTypography.monoRef.copyWith(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: isQr
                                          ? AppColors.primary
                                          : AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      }),
    );
  }
}

class _SummaryMiniStat extends StatelessWidget {
  const _SummaryMiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceDarkElevated,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.monoRef.copyWith(
              fontSize: 11,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.label.copyWith(
              fontSize: 14.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
