import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
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

      final connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.macAdress,
      );
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

      bytes.addAll(generator.text('Customer: $customerName'));
      bytes.addAll(generator.text('Ref No:   $referenceNumber'));
      bytes.addAll(generator.text('Date:     $date'));

      if (items.isNotEmpty) {
        bytes.addAll(generator.hr());
        for (int i = 0; i < items.length; i++) {
          if (i > 0) {
            bytes.addAll(generator.emptyLines(1));
          }
          final item = items[i];
          bytes.addAll(generator.text(item.title));
          final lineAmt = item.totalAmount.toStringAsFixed(2);
          final unitAmt = item.price.toStringAsFixed(2);
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

      bytes.addAll(generator.hr());
      bytes.addAll(
        generator.text(
          'TOTAL AMOUNT: PHP $totalAmount',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        ),
      );
      bytes.addAll(generator.hr());
      bytes.addAll(generator.feed(2));
      bytes.addAll(generator.cut());

      final printed = await PrintBluetoothThermal.writeBytes(bytes);
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
}
