import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/data/models/delivery_order.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';

/// Handles direct Android SMS notifications (matching Ravamate's SMSService pattern).
class SmsService extends GetxService {
  static SmsService get to => Get.find<SmsService>();

  static const MethodChannel _channel =
      MethodChannel('com.example.p_sosyo_driver/sms');

  /// Normalizes common Philippine phone formats (e.g. 09xx, +639xx, 639xx, 9xxxxxxxxx).
  String normalizePhoneNumber(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('+63')) return cleaned;
    if (cleaned.startsWith('63') && cleaned.length >= 11) return '+$cleaned';
    if (cleaned.startsWith('09') && cleaned.length == 11) {
      return '+63${cleaned.substring(1)}';
    }
    if (cleaned.startsWith('9') && cleaned.length == 10) return '+63$cleaned';
    return cleaned;
  }

  bool isValidPhoneNumber(String raw) {
    final normalized = normalizePhoneNumber(raw);
    final digits = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 10;
  }

  Future<bool> hasSmsPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('hasSmsPermission');
      return granted ?? false;
    } catch (e, stack) {
      logError('Error checking SMS permission', e, stack);
      return false;
    }
  }

  Future<bool> requestSmsPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestSmsPermission');
      return granted ?? false;
    } catch (e, stack) {
      logError('Error requesting SMS permission', e, stack);
      return false;
    }
  }

  Future<bool> sendSms({
    required String number,
    required String message,
    bool showToastOnResult = false,
  }) async {
    final normalized = normalizePhoneNumber(number);
    if (!isValidPhoneNumber(normalized)) {
      logWarning('Skipping SMS: invalid phone number "$number"', tag: 'SMS');
      return false;
    }

    final hasPermission = await hasSmsPermission();
    if (!hasPermission) {
      final granted = await requestSmsPermission();
      if (!granted) {
        logWarning('SMS permission denied by user', tag: 'SMS');
        if (showToastOnResult) {
          Get.snackbar(
            'SMS Permission Required',
            'Please allow SMS permission to notify customers automatically.',
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
          );
        }
        return false;
      }
    }

    final finalMessage = message;

    try {
      logImportant('Sending SMS to $normalized: $message', tag: 'SMS');
      final sent = await _channel.invokeMethod<bool>('sendSms', {
        'number': normalized,
        'message': finalMessage,
      });
      final ok = sent ?? false;
      if (ok && showToastOnResult) {
        Get.snackbar(
          'SMS Sent',
          'Customer ($normalized) has been notified.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFE8F5E9),
          colorText: const Color(0xFF15803D),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 2),
        );
      }
      return ok;
    } on MissingPluginException catch (e, stack) {
      logError('SMS native channel unavailable (app rebuild required)', e, stack);
      if (showToastOnResult) {
        Get.snackbar(
          'Rebuild Required',
          'Please rebuild and reinstall the app (flutter run) to activate SMS sending.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 4),
        );
      }
      return false;
    } on PlatformException catch (e, stack) {
      logError('Failed to send SMS to $normalized', e, stack);
      if (showToastOnResult) {
        await _channel.invokeMethod<bool>('openSmsComposer', {
          'number': normalized,
          'message': finalMessage,
        });
        Get.snackbar(
          'Direct SMS Failed — Opened SMS App',
          e.message ?? 'Could not send directly to $normalized',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 4),
        );
      }
      return false;
    }
  }

  /// Sends the "Out for Delivery" customer SMS and marks timestamp in SQLite.
  Future<bool> sendOutForDeliveryNotification(
    DeliveryOrder order, {
    bool showToast = false,
    bool forceResend = false,
  }) async {
    if (!forceResend &&
        order.outForDeliverySmsSentAt != null &&
        order.outForDeliverySmsSentAt!.isNotEmpty) {
      return false;
    }
    if (!isValidPhoneNumber(order.customerPhone)) {
      logWarning(
        'Order #${order.id} (${order.storeName}) has no valid phone number; skipping Out-for-Delivery SMS.',
        tag: 'SMS',
      );
      return false;
    }

    final msg =
        'Hi ${order.storeName}, your order #${order.id} will be delivered today in your location.';
    final sent = await sendSms(
      number: order.customerPhone,
      message: msg,
      showToastOnResult: showToast,
    );
    if (sent) {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await DatabaseService.to.markOutForDeliverySmsSent(order.id, nowIso);
    }
    return sent;
  }

  /// Sends an automated SMS for a retry delivery attempt.
  Future<bool> sendAttemptNotification(
    DeliveryOrder order, {
    required int attemptNumber,
    required String reason,
    bool showToast = false,
  }) async {
    if (!isValidPhoneNumber(order.customerPhone)) {
      logWarning(
        'Order #${order.id} has no valid phone number; skipping Attempt $attemptNumber SMS.',
        tag: 'SMS',
      );
      return false;
    }

    final msg =
        'Hi ${order.storeName}, we attempted to deliver your order #${order.id} today (Attempt #$attemptNumber - $reason). We will try again shortly.';

    return await sendSms(
      number: order.customerPhone,
      message: msg,
      showToastOnResult: showToast,
    );
  }

  /// Sends an SMS confirming a deferred/rescheduled delivery date so driver and
  /// customer can settle on when it will be delivered.
  Future<bool> sendRescheduleNotification(
    DeliveryOrder order, {
    required String scheduledDateLabel,
    required String reason,
    bool showToast = false,
  }) async {
    if (!isValidPhoneNumber(order.customerPhone)) {
      logWarning(
        'Order #${order.id} has no valid phone number; skipping Reschedule SMS.',
        tag: 'SMS',
      );
      return false;
    }

    final msg =
        'Hi ${order.storeName}, your order #${order.id} is queued for $scheduledDateLabel ($reason). Reply if you prefer another date.';

    return await sendSms(
      number: order.customerPhone,
      message: msg,
      showToastOnResult: showToast,
    );
  }
}
