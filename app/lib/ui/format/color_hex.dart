import 'package:flutter/material.dart';

const Color colorHexFallback = Color(0xFF8E8E93);

final RegExp _sixDigitHex = RegExp(r'^#?([0-9a-fA-F]{6})$');

const _opaqueAlphaBits = 0xFF000000;

const _hexChannelBits = 8;

const _redChannelShift = 16;

const _channelMax = 255;

Color parseColorHex(String hex) {
  final match = _sixDigitHex.firstMatch(hex.trim());
  if (match == null) return colorHexFallback;

  return Color(_opaqueAlphaBits | int.parse(match.group(1)!, radix: 16));
}

String toColorHex(Color color) {
  int channel(double value) =>
      (value * _channelMax).round().clamp(0, _channelMax);

  final rgb =
      (channel(color.r) << _redChannelShift) |
      (channel(color.g) << _hexChannelBits) |
      channel(color.b);
  return '#${rgb.toRadixString(16).toUpperCase().padLeft(6, '0')}';
}
