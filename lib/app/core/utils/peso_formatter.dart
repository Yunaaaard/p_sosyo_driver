import 'package:flutter/material.dart';

class PesoFormatter {
  static const List<FontFeature> _tabularFeatures = [
    FontFeature.tabularFigures(),
  ];

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
    final cleanAmount = amount.replaceAll('₱', '').trim();
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
