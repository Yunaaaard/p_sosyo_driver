import 'package:flutter/material.dart';

class PesoFormatter {
  static const List<FontFeature> _tabularFeatures = [
    FontFeature.tabularFigures(),
  ];

  /// Formats a numeric amount with thousands commas and 2 decimals (e.g. `5,354.40`).
  static String formatAmount(double amount) {
    final isNeg = amount < 0;
    final absVal = amount.abs();
    final parts = absVal.toStringAsFixed(2).split('.');
    final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAllMapped(regExp, (Match m) => ',');
    return '${isNeg ? '-' : ''}${parts.join('.')}';
  }

  /// Normalizes any amount string so it always has thousands commas and 2 decimals.
  static String formatString(String raw) {
    final clean = raw.replaceAll('₱', '').replaceAll(',', '').trim();
    final parsed = double.tryParse(clean);
    if (parsed != null) return formatAmount(parsed);
    return raw.replaceAll('₱', '').trim();
  }

  static TextSpan buildPesoSymbolSpan({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
  }) {
    return TextSpan(
      text: '₱',
      style: TextStyle(
        fontFamily: 'Arial',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      ),
    );
  }

  static Widget buildPesoText({
    required String amount,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
  }) {
    return Text.rich(
      buildPesoTextSpan(
        amount: amount,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  static TextSpan buildPesoTextSpan({
    required String amount,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
  }) {
    final cleanAmount = formatString(amount);
    return TextSpan(
      children: [
        buildPesoSymbolSpan(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        ),
        const TextSpan(text: ' '),
        TextSpan(
          text: cleanAmount,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
            fontFeatures: _tabularFeatures,
          ),
        ),
      ],
    );
  }
}
