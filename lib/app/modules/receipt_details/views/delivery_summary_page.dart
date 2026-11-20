import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/core/utils/peso_formatter.dart';
import 'package:p_sosyo_driver/app/data/models/order_item.dart';
import 'package:p_sosyo_driver/app/data/services/bluetooth_printer_service.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';
import 'package:p_sosyo_driver/app/widgets/custom_appBar.dart';
import 'package:p_sosyo_driver/app/widgets/custom_button.dart';
import 'package:p_sosyo_driver/app/widgets/status_badge.dart';

class DeliverySummaryPage extends StatelessWidget {
  const DeliverySummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> args = (Get.arguments is Map)
        ? Map<String, dynamic>.from(Get.arguments as Map)
        : <String, dynamic>{};

    final String totalAmount = (args['totalAmount'] ?? '0.00').toString();
    final String date = (args['date'] ?? '-').toString();
    final String customerName = (args['customerName'] ?? 'Customer').toString();
    final String referenceNumber =
        (args['referenceNumber'] ?? '-').toString();
    final String podPath = (args['proofOfDeliveryPath'] ?? '').toString();
    final bool hasPod = podPath.isNotEmpty && File(podPath).existsSync();
    final List<OrderItem> orderedItems = (args['items'] is List<OrderItem>)
        ? (args['items'] as List<OrderItem>)
        : <OrderItem>[];

    final printerService = BluetoothPrinterService.to;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      printerService.refreshConnectionStatus();
    });

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Get.until(
              (route) => route.settings.name == AppRoutes.home || route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: const CustomAppBar(
          title: 'Delivery Order Details',
          showBackButton: false,
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
                      // ── Delivered Banner ────────────────────────────────
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
                            const StatusPill(
                              label: 'Delivered',
                              isPositive: true,
                              icon: Icons.check_circle_outline_rounded,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'TOTAL AMOUNT',
                              style: AppTypography.eyebrow.copyWith(
                                fontSize: 13,
                                color: AppColors.mint,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: PesoFormatter.buildPesoText(
                                amount: totalAmount,
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Order & Receipt Summary Card ────────────────────
                      SurfaceCard(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        borderRadius: AppRadii.xl,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'DELIVERY SUMMARY',
                              style: AppTypography.eyebrow
                                  .copyWith(fontSize: 13.5),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _SummaryFieldRow(
                              label: 'Customer Name',
                              value: customerName,
                            ),
                            const Divider(
                              height: 24,
                              color: AppColors.border,
                            ),
                            _SummaryFieldRow(
                              label: 'Reference Number',
                              value: referenceNumber,
                              isMonospace: true,
                            ),
                            const Divider(
                              height: 24,
                              color: AppColors.border,
                            ),
                            _SummaryFieldRow(
                              label: 'Date',
                              value: date,
                            ),
                            const Divider(
                              height: 24,
                              color: AppColors.border,
                            ),
                            _SummaryFieldRow(
                              label: 'Total Amount',
                              value: '₱ $totalAmount',
                              isMonospace: true,
                            ),
                          ],
                        ),
                      ),

                      if (orderedItems.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        SurfaceCard(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          borderRadius: AppRadii.xl,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'PRODUCTS ORDERED',
                                    style: AppTypography.eyebrow
                                        .copyWith(fontSize: 13.5),
                                  ),
                                  Text(
                                    '${orderedItems.length} ${orderedItems.length == 1 ? 'Item' : 'Items'}',
                                    style: AppTypography.monoRef.copyWith(
                                      fontSize: 13.5,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              for (int i = 0; i < orderedItems.length; i++) ...[
                                if (i > 0)
                                  const Divider(
                                    height: 20,
                                    color: AppColors.border,
                                  ),
                                _OrderedProductRow(item: orderedItems[i]),
                              ],
                            ],
                          ),
                        ),
                      ],

                      if (hasPod) ...[
                        const SizedBox(height: AppSpacing.md),
                        SurfaceCard(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          borderRadius: AppRadii.xl,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PROOF OF DELIVERY (LOCAL)',
                                style: AppTypography.eyebrow
                                    .copyWith(fontSize: 13),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppRadii.md),
                                child: Image.file(
                                  File(podPath),
                                  height: 170,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Bottom Print & Done Dock ────────────────────────────────
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Obx(() {
                      final connected = printerService.isPrinterConnected.value;
                      final printerName =
                          printerService.connectedPrinterName.value;
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: connected
                              ? AppColors.successTint
                              : AppColors.canvas,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(
                            color: connected
                                ? AppColors.successBorder
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: connected
                                    ? AppColors.success
                                    : AppColors.inkSubtle,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                connected
                                    ? 'Printer Connected${printerName.isNotEmpty ? ': $printerName' : ''}'
                                    : 'Printer Not Connected · Tap Print to pair',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: connected
                                      ? AppColors.success
                                      : AppColors.inkMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    Obx(
                      () => CustomButton(
                        label: printerService.isPrinting.value
                            ? 'Printing Receipt...'
                            : 'Print Thermal Receipt',
                        icon: Icons.print_rounded,
                        variant: CustomButtonVariant.secondary,
                        isLoading: printerService.isPrinting.value,
                        onPressed: () => _handlePrintTap(
                          context,
                          printerService: printerService,
                          customerName: customerName,
                          referenceNumber: referenceNumber,
                          date: date,
                          totalAmount: totalAmount,
                          items: orderedItems,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomButton(
                      label: 'Done',
                      icon: Icons.check_rounded,
                      onPressed: () => Get.until(
                        (route) =>
                            route.settings.name == AppRoutes.home ||
                            route.isFirst,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePrintTap(
    BuildContext context, {
    required BluetoothPrinterService printerService,
    required String customerName,
    required String referenceNumber,
    required String date,
    required String totalAmount,
    required List<OrderItem> items,
  }) async {
    final ready = await printerService.ensureConnected();
    if (!ready) {
      final devices = await printerService.getPairedPrinters();
      if (!context.mounted) return;
      final selected = await _showPrinterPickerDialog(context, devices);
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

    final printed = await printerService.printDeliveryReceipt(
      customerName: customerName,
      referenceNumber: referenceNumber,
      date: date,
      totalAmount: totalAmount,
      items: items,
    );

    Get.snackbar(
      printed ? 'Receipt Printed' : 'Print Failed',
      printed
          ? 'Delivery receipt sent to thermal printer.'
          : 'Please check Bluetooth printer paper and connection.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor:
          printed ? AppColors.successTint : AppColors.dangerTint,
      colorText: printed ? AppColors.success : AppColors.danger,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  Future<BluetoothInfo?> _showPrinterPickerDialog(
    BuildContext context,
    List<BluetoothInfo> devices,
  ) {
    return showDialog<BluetoothInfo>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select Thermal Printer',
                style: AppTypography.title.copyWith(fontSize: 20),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                devices.isEmpty
                    ? 'No paired Bluetooth printers found. Pair your thermal printer in Android Bluetooth settings first.'
                    : 'Choose a paired Bluetooth printer:',
                style: AppTypography.caption.copyWith(fontSize: 15),
              ),
              const SizedBox(height: AppSpacing.md),
              if (devices.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (_, index) {
                      final d = devices[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.print_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(d.name, style: AppTypography.label),
                        subtitle: Text(
                          d.macAdress,
                          style: AppTypography.monoRef.copyWith(fontSize: 13),
                        ),
                        onTap: () => Navigator.of(dialogContext).pop(d),
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(null),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryFieldRow extends StatelessWidget {
  const _SummaryFieldRow({
    required this.label,
    required this.value,
    this.isMonospace = false,
  });

  final String label;
  final String value;
  final bool isMonospace;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: 15.5,
              color: AppColors.inkMuted,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 7,
          child: Text(
            value.isNotEmpty ? value : '-',
            textAlign: TextAlign.right,
            style: (isMonospace ? AppTypography.monoRef : AppTypography.bodyMedium)
                .copyWith(
              fontSize: 16.5,
              fontWeight: FontWeight.w600,
              color: AppColors.inkPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderedProductRow extends StatelessWidget {
  const _OrderedProductRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.displayQty}  ×  ${item.formattedPrice}',
                style: AppTypography.caption.copyWith(
                  fontSize: 14.5,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          item.formattedTotalAmount,
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
