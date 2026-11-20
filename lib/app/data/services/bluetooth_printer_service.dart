import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/core/utils/peso_formatter.dart';
import 'package:p_sosyo_driver/app/data/models/order_item.dart';

class BluetoothPrinterService extends GetxService {
  static BluetoothPrinterService get to => Get.find<BluetoothPrinterService>();

  static const MethodChannel _permissionsChannel =
      MethodChannel('com.example.p_sosyo_driver/permissions');
  static const String _preferredPrinterMacKey = 'preferred_bt_printer_mac';
  static const String _preferredPrinterNameKey = 'preferred_bt_printer_name';

  final RxBool isPrinterConnected = false.obs;
  RxBool get isConnected => isPrinterConnected;
  final RxBool isBluetoothPermissionGranted = false.obs;
  final RxBool isPrinting = false.obs;
  final RxString connectedPrinterName = ''.obs;
  final RxString connectedPrinterMac = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _restoreConnectionState();
  }

  Future<void> _restoreConnectionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      connectedPrinterMac.value =
          prefs.getString(_preferredPrinterMacKey) ?? '';
      connectedPrinterName.value =
          prefs.getString(_preferredPrinterNameKey) ?? '';

      await ensureBluetoothPermission(promptIfDenied: true);
      if (isBluetoothPermissionGranted.value) {
        isPrinterConnected.value = await PrintBluetoothThermal.connectionStatus;
      }
    } catch (e, stack) {
      logError('Error checking Bluetooth printer state', e, stack);
    }
  }

  /// Mandatory Bluetooth / Nearby Devices permission check & runtime request.
  /// Shows a non-dismissible dialog if denied so the driver must allow it.
  Future<bool> ensureBluetoothPermission({bool promptIfDenied = true}) async {
    try {
      bool granted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!granted) {
        try {
          final requested = await _permissionsChannel
              .invokeMethod<bool>('requestBluetoothPermissions');
          granted = requested ??
              await PrintBluetoothThermal.isPermissionBluetoothGranted;
        } on MissingPluginException {
          logWarning(
            'Native permissions channel not registered yet — run a full "flutter run".',
            tag: 'PRINTER',
          );
        }
      }

      isBluetoothPermissionGranted.value = granted;

      if (!granted && promptIfDenied && Get.context != null) {
        await _showMandatoryBluetoothDialog();
        granted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
        isBluetoothPermissionGranted.value = granted;
      }

      return granted;
    } catch (e, stack) {
      logError('Error requesting Bluetooth permission', e, stack);
      isBluetoothPermissionGranted.value = false;
      return false;
    }
  }

  Future<void> _showMandatoryBluetoothDialog() async {
    if (Get.isDialogOpen ?? false) return;
    await Get.dialog(
      PopScope(
        canPop: false,
        child: Dialog(
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
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      child: const Icon(
                        Icons.bluetooth_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Bluetooth Permission Required',
                        style: AppTypography.title.copyWith(fontSize: 19),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Nearby Devices (Bluetooth) permission is mandatory to connect and print delivery receipts on your thermal printer. Please allow it to continue.',
                  style: AppTypography.body.copyWith(
                    fontSize: 16.5,
                    color: AppColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: () async {
                    final requested = await _permissionsChannel
                        .invokeMethod<bool>('requestBluetoothPermissions');
                    final ok = (requested ?? false) ||
                        await PrintBluetoothThermal
                            .isPermissionBluetoothGranted;
                    if (ok) {
                      isBluetoothPermissionGranted.value = true;
                      Get.back();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  child: Text(
                    'Allow Bluetooth Permission',
                    style: AppTypography.label.copyWith(
                      fontSize: 16.5,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () async {
                    await _permissionsChannel.invokeMethod<bool>(
                      'openAppSettings',
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primaryBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  child: Text(
                    'Open App Settings (Nearby Devices)',
                    style: AppTypography.label.copyWith(
                      fontSize: 15.5,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  /// Refresh live [isPrinterConnected] status from the Bluetooth thermal plugin.
  Future<bool> refreshConnectionStatus() async {
    try {
      final hasPerm = await ensureBluetoothPermission(promptIfDenied: false);
      if (!hasPerm) {
        isPrinterConnected.value = false;
        return false;
      }
      final status = await PrintBluetoothThermal.connectionStatus;
      isPrinterConnected.value = status;
      return status;
    } catch (e, stack) {
      logError('Failed to refresh Bluetooth printer status', e, stack);
      isPrinterConnected.value = false;
      return false;
    }
  }

  /// Fetch all paired Bluetooth printers on the device.
  Future<List<BluetoothInfo>> getPairedPrinters() async {
    try {
      final hasPerm = await ensureBluetoothPermission(promptIfDenied: true);
      if (!hasPerm) return [];

      final bool enabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!enabled) {
        logWarning('Bluetooth is disabled on device', tag: 'PRINTER');
        return [];
      }
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (e, stack) {
      logError('Failed to query paired Bluetooth printers', e, stack);
      return [];
    }
  }

  /// Connect to a paired thermal printer and remember it as preferred.
  Future<bool> connectPrinter(BluetoothInfo device) async {
    try {
      final currentlyConnected = await PrintBluetoothThermal.connectionStatus;
      if (currentlyConnected &&
          connectedPrinterMac.value == device.macAdress) {
        isConnected.value = true;
        return true;
      }
      if (currentlyConnected) {
        await PrintBluetoothThermal.disconnect;
      }

      bool connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.macAdress,
      );
      if (!connected) {
        logWarning(
          'Initial printer connect failed for ${device.name}; resetting socket and retrying...',
          tag: 'PRINTER',
        );
        await PrintBluetoothThermal.disconnect;
        await Future.delayed(const Duration(milliseconds: 350));
        connected = await PrintBluetoothThermal.connect(
          macPrinterAddress: device.macAdress,
        );
      }
      isConnected.value = connected;
      if (connected) {
        connectedPrinterMac.value = device.macAdress;
        connectedPrinterName.value = device.name;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_preferredPrinterMacKey, device.macAdress);
        await prefs.setString(_preferredPrinterNameKey, device.name);
        logImportant(
          'Connected thermal printer: ${device.name} (${device.macAdress})',
          tag: 'PRINTER',
        );
      }
      return connected;
    } catch (e, stack) {
      logError('Bluetooth printer connect failed', e, stack);
      isConnected.value = false;
      return false;
    }
  }

  /// Attempt auto-reconnect to the last used printer if not currently connected.
  Future<bool> ensureConnected() async {
    try {
      final hasPerm = await ensureBluetoothPermission(promptIfDenied: true);
      if (!hasPerm) return false;

      if (await PrintBluetoothThermal.connectionStatus) {
        isConnected.value = true;
        return true;
      }
      final prefs = await SharedPreferences.getInstance();
      final savedMac = prefs.getString(_preferredPrinterMacKey) ?? '';
      if (savedMac.isEmpty) return false;
      final ok = await PrintBluetoothThermal.connect(
        macPrinterAddress: savedMac,
      );
      isConnected.value = ok;
      return ok;
    } catch (e, stack) {
      logError('Error ensuring Bluetooth printer connection', e, stack);
      return false;
    }
  }

  /// Print the formatted 58mm ESC/POS delivery receipt.
  Future<bool> printDeliveryReceipt({
    required String customerName,
    required String referenceNumber,
    required String date,
    required String totalAmount,
    List<OrderItem> items = const [],
  }) async {
    isPrinting.value = true;
    try {
      final connected = await ensureConnected();
      if (!connected) {
        return false;
      }

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final List<int> bytes = [];

      bytes.addAll(generator.reset());
      bytes.addAll(
        generator.text(
          'PAQNER DRIVER',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        ),
      );
      bytes.addAll(
        generator.text(
          'DELIVERY RECEIPT',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      );
      bytes.addAll(generator.hr());

      final formattedDate = _ensurePhilippineDateTime(date);
      bytes.addAll(generator.text('Customer: ${_toAscii(customerName)}'));
      bytes.addAll(generator.text('Ref No:   ${_toAscii(referenceNumber)}'));
      bytes.addAll(generator.text('Date:     ${_toAscii(formattedDate)}'));

      if (items.isNotEmpty) {
        bytes.addAll(generator.hr());
        for (int i = 0; i < items.length; i++) {
          if (i > 0) {
            bytes.addAll(generator.emptyLines(1));
          }
          final item = items[i];
          bytes.addAll(generator.text(_toAscii(item.title)));
          final lineAmt = PesoFormatter.formatAmount(item.totalAmount);
          final unitAmt = PesoFormatter.formatAmount(item.price);
          bytes.addAll(
            generator.row([
              PosColumn(
                text: '  ${item.displayQty} x $unitAmt',
                width: 7,
              ),
              PosColumn(
                text: 'PHP $lineAmt',
                width: 5,
                styles: const PosStyles(align: PosAlign.right),
              ),
            ]),
          );
        }
      }

      final cleanTotal =
          _toAscii(PesoFormatter.formatString(totalAmount));
      bytes.addAll(generator.hr());
      bytes.addAll(
        generator.text(
          'TOTAL AMOUNT: PHP $cleanTotal',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        ),
      );
      bytes.addAll(generator.hr());
      bytes.addAll(generator.feed(3));

      final printed = await _writeBytesChunked(bytes);
      logImportant(
        'Thermal receipt print result=$printed (Ref #$referenceNumber)',
        tag: 'PRINTER',
      );
      return printed;
    } catch (e, stack) {
      logError('Error printing delivery receipt', e, stack);
      return false;
    } finally {
      isPrinting.value = false;
    }
  }

  /// Prints a 58mm thermal End of Day route summary for the driver.
  Future<bool> printEndOfDaySummary({
    required String driverName,
    required String dateLabel,
    required int totalStops,
    required int deliveredCount,
    required int remainingCount,
    required int queuedCount,
    required int cancelledCount,
    required double collectedAmount,
    required double targetAmount,
    required double pendingAmount,
    required int podCount,
    required int attemptCount,
  }) async {
    isPrinting.value = true;
    try {
      if (!await ensureConnected()) {
        return false;
      }
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final List<int> bytes = [];

      bytes.addAll(generator.reset());
      bytes.addAll(
        generator.text(
          'END OF DAY SUMMARY',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size1,
          ),
        ),
      );
      bytes.addAll(generator.hr());
      bytes.addAll(generator.text('Driver:   ${_toAscii(driverName)}'));
      bytes.addAll(generator.text(
          'Date:     ${_toAscii(_ensurePhilippineDateTime(dateLabel))}'));
      bytes.addAll(generator.hr());
      bytes.addAll(generator.text('Total Stops:    $totalStops'));
      bytes.addAll(generator.text('Delivered:      $deliveredCount'));
      bytes.addAll(generator.text('Remaining:      $remainingCount'));
      bytes.addAll(generator.text('Queued/Locked:  $queuedCount'));
      bytes.addAll(generator.text('Cancelled:      $cancelledCount'));
      bytes.addAll(generator.hr());
      bytes.addAll(
        generator.text(
            'Target:    PHP ${PesoFormatter.formatAmount(targetAmount)}'),
      );
      bytes.addAll(
        generator.text(
            'Pending:   PHP ${PesoFormatter.formatAmount(pendingAmount)}'),
      );
      bytes.addAll(
        generator.text(
          'COLLECTED: PHP ${PesoFormatter.formatAmount(collectedAmount)}',
          styles: const PosStyles(bold: true),
        ),
      );
      bytes.addAll(generator.hr());
      bytes.addAll(generator.feed(3));

      final printed = await _writeBytesChunked(bytes);
      logImportant('Thermal EOD summary print result=$printed', tag: 'PRINTER');
      return printed;
    } catch (e, stack) {
      logError('Error printing EOD summary', e, stack);
      return false;
    } finally {
      isPrinting.value = false;
    }
  }

  String _ensurePhilippineDateTime(String rawDate) {
    final trimmed = rawDate.trim();
    if (trimmed.toUpperCase().contains('PHT')) {
      return trimmed.replaceAll('·', '-');
    }
    final phtNow = DateTime.now().toUtc().add(const Duration(hours: 8));
    final parsed = DateTime.tryParse(trimmed);
    DateTime target = phtNow;
    if (parsed != null) {
      final hasTime = trimmed.contains(':') || trimmed.contains('T');
      target = hasTime
          ? (parsed.isUtc
              ? parsed.add(const Duration(hours: 8))
              : parsed.toUtc().add(const Duration(hours: 8)))
          : DateTime(
              parsed.year,
              parsed.month,
              parsed.day,
              phtNow.hour,
              phtNow.minute,
            );
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour24 = target.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final min = target.minute.toString().padLeft(2, '0');
    return '${months[target.month - 1]} ${target.day}, ${target.year} - ${hour12.toString().padLeft(2, '0')}:$min $period PHT';
  }

  String _toAscii(String input) {
    return input
        .replaceAll('₱', 'PHP ')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
        .trim();
  }

  /// Sends ESC/POS bytes in 512-byte chunks so portable 58mm thermal printer
  /// buffers do not drop large payloads.
  Future<bool> _writeBytesChunked(List<int> bytes) async {
    if (bytes.isEmpty) return false;
    const int chunkSize = 512;
    for (int offset = 0; offset < bytes.length; offset += chunkSize) {
      final end = (offset + chunkSize < bytes.length)
          ? offset + chunkSize
          : bytes.length;
      final chunk = bytes.sublist(offset, end);
      final ok = await PrintBluetoothThermal.writeBytes(chunk);
      if (!ok) {
        logWarning('Thermal printer chunk write returned false at $offset');
        return false;
      }
      if (end < bytes.length) {
        await Future.delayed(const Duration(milliseconds: 25));
      }
    }
    return true;
  }
}
