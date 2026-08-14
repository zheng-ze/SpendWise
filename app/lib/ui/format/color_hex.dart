import 'package:flutter/material.dart';

const Color colorHexFallback = Color(0xFF8E8E93);

final RegExp _sixDigitHex = RegExp(r'^#?([0-9a-fA-F]{6})$');

Color parseColorHex(String hex) {
  final match = _sixDigitHex.firstMatch(hex.trim());
  if (match == null) return colorHexFallback;

  return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
}

/// Alpha is dropped, so a stored color round-trips through the six-digit form
/// the native app reads.
String toColorHex(Color color) {
  int channel(double value) => (value * 255).round().clamp(0, 255);

  final rgb =
      (channel(color.r) << 16) | (channel(color.g) << 8) | channel(color.b);
  return '#${rgb.toRadixString(16).toUpperCase().padLeft(6, '0')}';
}
