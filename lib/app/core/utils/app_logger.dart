import 'package:flutter/foundation.dart';

/// Centralized ANSI terminal logger for PSosyo Driver.
/// - Syncing logs: Vibrant Green (`\x1B[92m`)
/// - Important logs: Vibrant Yellow-Orange (`\x1B[38;5;214m`)
/// - Error logs: Bright Red (`\x1B[91m` / `\x1B[31m`)
/// - Warnings: Bright Yellow (`\x1B[93m`)
/// - Info logs: Cyan (`\x1B[36m`)
class AppLogger {
  // ANSI escape codes
  static const String _reset = '\x1B[0m';
  static const String _brightGreen = '\x1B[92m';
  static const String _yellowOrange = '\x1B[38;5;214m';
  static const String _brightYellow = '\x1B[93m';
  static const String _brightRed = '\x1B[91m';
  static const String _cyan = '\x1B[36m';
  static const String _bold = '\x1B[1m';

  /// Log syncing operations in vibrant GREEN
  static void sync(String message, {String tag = 'SYNC'}) {
    if (kDebugMode) {
      debugPrint('$_brightGreen$_bold[$tag] 🚚 $message$_reset');
    }
  }

  /// Log important milestones, summaries, alerts, or key data in vibrant YELLOW-ORANGE
  static void important(String message, {String tag = 'IMPORTANT'}) {
    if (kDebugMode) {
      debugPrint('$_yellowOrange$_bold[$tag] ⚡ $message$_reset');
    }
  }

  /// Log errors in bright RED
  static void error(String message, [dynamic err, StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint('$_brightRed$_bold[ERROR] ❌ $message${err != null ? ': $err' : ''}$_reset');
      if (stack != null) {
        debugPrint('$_brightRed$stack$_reset');
      }
    }
  }

  /// Log warnings in yellow
  static void warning(String message, {String tag = 'WARN'}) {
    if (kDebugMode) {
      debugPrint('$_brightYellow[$tag] ⚠️ $message$_reset');
    }
  }

  /// Log general debug/info in cyan
  static void info(String message, {String tag = 'INFO'}) {
    if (kDebugMode) {
      debugPrint('$_cyan[$tag] ℹ️ $message$_reset');
    }
  }
}

/// Shorthand helper functions for fast, expressive logging
void logSync(String message, {String tag = 'SYNC'}) => AppLogger.sync(message, tag: tag);
void logImportant(String message, {String tag = 'IMPORTANT'}) => AppLogger.important(message, tag: tag);
void logError(String message, [dynamic err, StackTrace? stack]) => AppLogger.error(message, err, stack);
void logWarning(String message, {String tag = 'WARN'}) => AppLogger.warning(message, tag: tag);
void logInfo(String message, {String tag = 'INFO'}) => AppLogger.info(message, tag: tag);

