import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/core/utils/peso_formatter.dart';
import 'package:p_sosyo_driver/app/data/services/bluetooth_printer_service.dart';
import 'package:p_sosyo_driver/app/modules/end_of_day/controller/end_of_day_controller.dart';
import 'package:p_sosyo_driver/app/widgets/custom_appBar.dart';
import 'package:p_sosyo_driver/app/widgets/custom_button.dart';
import 'package:p_sosyo_driver/app/widgets/printer_picker_dialog.dart';
import 'package:p_sosyo_driver/app/widgets/status_badge.dart';

class EndOfDayPage extends GetView<EndOfDayController> {
  const EndOfDayPage({super.key});

  String _formatPeso(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAllMapped(regExp, (Match m) => ',');
    return parts.join('.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: CustomAppBar(
        title: 'End of Day',
        showBackButton: true,
        trailing: IconButton(
          tooltip: 'Test Print EOD Summary',
          onPressed: () => _handlePrintTap(context),
          icon: const Icon(
            Icons.print_rounded,
            color: AppColors.primary,
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }

        final pct = (controller.completionRate * 100).round();
        final isDone = controller.isEndOfDayDone.value;
        final printerConnected = Get.isRegistered<BluetoothPrinterService>()
            ? BluetoothPrinterService.to.isPrinterConnected.value
            : false;

        return SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Dark Route Performance Header ─────────────────
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                          border:
                              Border.all(color: AppColors.surfaceDarkBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        controller.dateLabel.value
                                            .toUpperCase(),
                                        style: AppTypography.eyebrow.copyWith(
                                          fontSize: 12.5,
                                          color: AppColors.mint,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        controller.driverName.value,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.title.copyWith(
                                          fontSize: 20,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDone
                                        ? AppColors.success.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.pill),
                                  ),
                                  child: Text(
                                    isDone
                                        ? 'Done · ${controller.completedAtLabel.value}'
                                        : '$pct% Complete',
                                    style: AppTypography.monoRef.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDone
                                          ? AppColors.mint
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'COLLECTED TODAY',
                              style: AppTypography.eyebrow.copyWith(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.65),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text.rich(
                              PesoFormatter.buildPesoTextSpan(
                                amount:
                                    _formatPeso(controller.collectedAmount.value),
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'of ₱ ${_formatPeso(controller.targetAmount.value)} route target · ${controller.deliveredCount.value}/${controller.totalStops.value} stops delivered',
                              style: AppTypography.caption.copyWith(
                                fontSize: 14.5,
                                color: Colors.white.withOpacity(0.75),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill),
                              child: LinearProgressIndicator(
                                value: controller.completionRate.clamp(0.0, 1.0),
                                minHeight: 7,
                                backgroundColor: Colors.white.withOpacity(0.15),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.mint,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Stop Breakdown 2x2 Grid ───────────────────────
                      const SectionHeader(title: 'Stop Breakdown'),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _KpiTile(
                              label: 'Delivered',
                              value: '${controller.deliveredCount.value}',
                              subtitle:
                                  '₱ ${_formatPeso(controller.collectedAmount.value)}',
                              accent: AppColors.success,
                              tint: AppColors.successTint,
                              border: AppColors.successBorder,
                              icon: Icons.check_circle_outline_rounded,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm + 2),
                          Expanded(
                            child: _KpiTile(
                              label: 'Remaining',
                              value:
                                  '${controller.remainingUnlockedCount.value}',
                              subtitle: 'Active unlocked',
                              accent: AppColors.primary,
                              tint: AppColors.primaryTint,
                              border: AppColors.primaryBorder,
                              icon: Icons.local_shipping_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm + 2),
                      Row(
                        children: [
                          Expanded(
                            child: _KpiTile(
                              label: 'Queued / Locked',
                              value: '${controller.queuedLockedCount.value}',
                              subtitle:
                                  '₱ ${_formatPeso(controller.queuedAmount.value)}',
                              accent: AppColors.warning,
                              tint: AppColors.warningTint,
                              border: AppColors.warningBorder,
                              icon: Icons.lock_clock_outlined,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm + 2),
                          Expanded(
                            child: _KpiTile(
                              label: 'Cancelled',
                              value: '${controller.cancelledCount.value}',
                              subtitle:
                                  '₱ ${_formatPeso(controller.cancelledAmount.value)}',
                              accent: AppColors.danger,
                              tint: AppColors.dangerTint,
                              border: AppColors.dangerBorder,
                              icon: Icons.cancel_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Field Compliance & Financials ─────────────────
                      const SectionHeader(title: 'Route KPIs & Compliance'),
                      const SizedBox(height: AppSpacing.sm),
                      SurfaceCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            _SummaryMetricRow(
                              label: 'Average Drop Value',
                              value:
                                  '₱ ${_formatPeso(controller.averageDropValue.value)}',
                            ),
                            const Divider(height: 18, color: AppColors.border),
                            _SummaryMetricRow(
                              label: 'Pending / Uncollected Value',
                              value:
                                  '₱ ${_formatPeso(controller.pendingAmount.value)}',
                            ),
                            const Divider(height: 18, color: AppColors.border),
                            _SummaryMetricRow(
                              label: 'Delivery Attempts Logged',
                              value: '${controller.totalAttemptsCount.value}',
                            ),
                          ],
                        ),
                      ),

                      if (controller.cancellationReasonCounts.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        const SectionHeader(title: 'Cancellation Reasons'),
                        const SizedBox(height: AppSpacing.sm),
                        SurfaceCard(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            children: controller
                                .cancellationReasonCounts.entries
                                .map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _SummaryMetricRow(
                                  label: entry.key,
                                  value: '${entry.value}',
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Bottom Confirm EOD Bar ────────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _handlePrintTap(context),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              printerConnected
                                  ? Icons.bluetooth_connected_rounded
                                  : Icons.bluetooth_disabled_rounded,
                              size: 14,
                              color: printerConnected
                                  ? AppColors.success
                                  : AppColors.inkMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              printerConnected
                                  ? 'Thermal Printer Connected · Tap to Test Print'
                                  : 'Printer Not Connected · Tap to Pair & Print',
                              style: AppTypography.caption.copyWith(
                                fontSize: 13.5,
                                color: printerConnected
                                    ? AppColors.success
                                    : AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    CustomButton(
                      label: isDone
                          ? 'End of Day Completed'
                          : 'Confirm End of Day',
                      icon: isDone
                          ? Icons.check_circle_rounded
                          : Icons.task_alt_rounded,
                      variant: isDone
                          ? CustomButtonVariant.success
                          : CustomButtonVariant.primary,
                      enabled: !isDone,
                      onPressed: () => controller.confirmEndOfDay(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
  Future<void> _handlePrintTap(BuildContext context) async {
    if (!Get.isRegistered<BluetoothPrinterService>()) return;
    final printerService = BluetoothPrinterService.to;
    final ready = await printerService.ensureConnected();
    if (!ready) {
      final devices = await printerService.getPairedPrinters();
      if (!context.mounted) return;
      final selected = await showThermalPrinterPickerDialog(context, devices);
      if (selected == null) return;
      final connected = await printerService.connectPrinter(selected);
      if (!connected) {
        Get.snackbar(
          'Printer Connection Failed',
          'Could not connect to ${selected.name}.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.dangerTint,
          colorText: AppColors.danger,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return;
      }
    }

    final printed = await controller.printEndOfDaySummary();
    Get.snackbar(
      printed ? 'EOD Summary Printed' : 'Print Failed',
      printed
          ? 'End of Day summary sent to thermal printer.'
          : 'Please check Bluetooth printer paper and connection.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor:
          printed ? AppColors.successTint : AppColors.dangerTint,
      colorText: printed ? AppColors.success : AppColors.danger,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.tint,
    required this.border,
    required this.icon,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color accent;
  final Color tint;
  final Color border;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTypography.metric.copyWith(
              fontSize: 26,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.monoRef.copyWith(
              fontSize: 13,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetricRow extends StatelessWidget {
  const _SummaryMetricRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.body.copyWith(
              fontSize: 16.5,
              color: AppColors.inkSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: AppTypography.monoRef.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.inkPrimary,
          ),
        ),
      ],
    );
  }
}
