import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Encoder, decoder, and reference generator for the Paqner Trade Terms (PesoPaq)
/// QR payment and receipt protocol (matching RavaMate v1 specification).
class PaqnerQrCodec {
  PaqnerQrCodec._();

  /// Encode a JSON payload map into Base64(GZIP(UTF-8(JSON))).
  static String encode(Map<String, dynamic> payload) {
    final plainJson = jsonEncode(payload);
    final utf8Bytes = utf8.encode(plainJson);
    final compressedBytes = gzip.encode(utf8Bytes);
    return base64Encode(compressedBytes);
  }

  /// Decode either a plain `{...}` JSON string or a Base64(GZIP(UTF-8(JSON))) string.
  static Map<String, dynamic> decode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('{')) {
      return Map<String, dynamic>.from(jsonDecode(trimmed) as Map);
    }
    final compressedBytes = base64Decode(trimmed);
    final utf8Bytes = gzip.decode(compressedBytes);
    final jsonString = utf8.decode(utf8Bytes);
    return Map<String, dynamic>.from(jsonDecode(jsonString) as Map);
  }

  /// Generate a unique Paqner salesman reference ID (`r` / `salesman_reference_id`):
  /// Format: `REF-<salesmanCode>-<3-letter principal/prefix>-<YYMMDD>-<3 random>`
  static String generateSalesmanReferenceId({
    required String salesmanCode,
    String principal = 'Monde',
  }) {
    final cleanSc =
        salesmanCode.trim().isNotEmpty ? salesmanCode.trim() : 'DRP1';
    final now = DateTime.now();
    final dateStr =
        '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    final randomStr =
        List.generate(3, (_) => chars[rnd.nextInt(chars.length)]).join();

    final cleanPrincipal = principal.trim();
    final prefix = cleanPrincipal.length >= 3
        ? cleanPrincipal.substring(0, 3).toUpperCase()
        : cleanPrincipal.toUpperCase().padRight(3, 'X');

    return 'REF-$cleanSc-$prefix-$dateStr-$randomStr';
  }

  /// Build the Paqner Trade Terms v1 cancellation QR payload (`{v, r, p, a, d, s, n, t}`),
  /// matching `PaqnerCancelQr.buildCancelPayload` in RavaMate.
  static Map<String, dynamic> buildCancelPayload({
    required String paymentReference,
    required double totalAmount,
    String principal = 'Monde',
    DateTime? appliedAt,
    DateTime? expiresAt,
  }) {
    final DateTime now = (appliedAt ?? DateTime.now()).toUtc();
    final DateTime expiry =
        (expiresAt ?? now.add(const Duration(hours: 1))).toUtc();
    return {
      'v': 1,
      'r': paymentReference.trim(),
      'p': principal.trim().isEmpty ? 'MNC' : principal.trim(),
      'a': now.toIso8601String(),
      'd': expiry.toIso8601String(),
      's': 'cancelled',
      'n': 0,
      't': totalAmount,
    };
  }

  /// Verify a scanned Paqner user's cancellation confirmation QR:
  /// requires `r` to match [expectedReference] and `s == 'cancelled'`.
  /// Returns `null` on success, otherwise an error message.
  static String? verifyCancelScan({
    required Map<String, dynamic> scanned,
    required String expectedReference,
  }) {
    if (!scanned.containsKey('r')) return 'Invalid QR Structure';
    final String r = '${scanned['r'] ?? ''}'.trim();
    final String s = '${scanned['s'] ?? ''}'.trim().toLowerCase();
    if (r.isEmpty || r != expectedReference.trim()) {
      return 'Reference ID Mismatch';
    }
    if (s != 'cancelled') {
      return 'Confirmation QR is not a cancellation approval';
    }
    return null;
  }
}
