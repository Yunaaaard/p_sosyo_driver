import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';

/// Shared dialog to select a paired Bluetooth thermal printer.
Future<BluetoothInfo?> showThermalPrinterPickerDialog(
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
