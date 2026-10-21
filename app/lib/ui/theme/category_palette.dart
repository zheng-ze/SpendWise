import 'package:flutter/material.dart';

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';

abstract final class CategoryPalette {
  static const _rampWeights = <double>[
    0,
    1 / 14,
    2 / 14,
    3 / 14,
    4 / 14,
    5 / 14,
    6 / 14,
    1 / 2,
  ];

  static const _contrastingMarks = <_CategoryMark>[
    _CategoryMark.groceries,
    _CategoryMark.supermarket,
    _CategoryMark.freshMarket,
    _CategoryMark.dining,
    _CategoryMark.transport,
    _CategoryMark.salary,
    _CategoryMark.fitness,
    _CategoryMark.housing,
  ];

  static const _savedMarks = <int, _CategoryMark>{
    0xFF34C759: _CategoryMark.groceries,
    0xFFFF9500: _CategoryMark.dining,
    0xFF5856D6: _CategoryMark.transport,
    0xFF007AFF: _CategoryMark.salary,
    0xFF30D158: _CategoryMark.supermarket,
    0xFF63E6BE: _CategoryMark.freshMarket,
  };

  static const _lightMinimumLightness = 72 / 255;
  static const _lightMaximumLightness = 130.5 / 255;
  static const _darkMinimumLightness = 164 / 255;
  static const _darkMaximumLightness = 199.5 / 255;

  static Color resolve({
    required String? savedHex,
    required int rank,
    required ChartColours mode,
    required SpendWiseColors colors,
  }) {
    return switch (mode) {
      ChartColours.categoryColours => _savedColor(savedHex, colors),
      ChartColours.themeShades => _shade(rank, colors),
      ChartColours.contrasting =>
        _contrastingMarks[rank % _contrastingMarks.length].resolve(colors),
    };
  }

  static Color _shade(int rank, SpendWiseColors colors) {
    return Color.lerp(
          colors.action,
          colors.surface,
          _rampWeights[rank % _rampWeights.length],
        ) ??
        colors.action;
  }

  static Color _savedColor(String? savedHex, SpendWiseColors colors) {
    final saved = savedHex == null ? colorHexFallback : parseColorHex(savedHex);
    final mark = _savedMarks[saved.toARGB32()];
    if (mark != null) return mark.resolve(colors);

    final isDark =
        ThemeData.estimateBrightnessForColor(colors.surface) == Brightness.dark;
    final minimum = isDark ? _darkMinimumLightness : _lightMinimumLightness;
    final maximum = isDark ? _darkMaximumLightness : _lightMaximumLightness;
    final hsl = HSLColor.fromColor(saved);
    return hsl.withLightness(hsl.lightness.clamp(minimum, maximum)).toColor();
  }
}

enum _CategoryMark {
  groceries,
  supermarket,
  freshMarket,
  dining,
  transport,
  salary,
  fitness,
  housing;

  Color resolve(SpendWiseColors colors) => switch (this) {
    groceries => colors.groceries,
    supermarket => colors.supermarket,
    freshMarket => colors.freshMarket,
    dining => colors.dining,
    transport => colors.transport,
    salary => colors.salary,
    fitness => colors.fitness,
    housing => colors.housing,
  };
}
