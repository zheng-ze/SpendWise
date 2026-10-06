import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_colors.dart';

const _amountFamily = 'InstrumentSans';

TextStyle _amount(double size, FontWeight weight, double letterSpacing) {
  return const TextStyle().copyWith(
    fontFamily: _amountFamily,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

class SpendWiseText extends ThemeExtension<SpendWiseText> {
  const SpendWiseText({
    required this.hero,
    required this.headline,
    required this.row,
    required this.small,
  });

  static final light = SpendWiseText(
    hero: _amount(34, FontWeight.w500, -1.2),
    headline: _amount(26, FontWeight.w500, -0.7),
    row: _amount(14, FontWeight.w600, -0.2),
    small: _amount(12, FontWeight.w600, 0),
  );

  static final dark = SpendWiseText(
    hero: _amount(34, FontWeight.w500, -1.2),
    headline: _amount(26, FontWeight.w500, -0.7),
    row: _amount(14, FontWeight.w600, -0.2),
    small: _amount(12, FontWeight.w600, 0),
  );

  final TextStyle hero;
  final TextStyle headline;
  final TextStyle row;
  final TextStyle small;

  @override
  SpendWiseText copyWith({
    TextStyle? hero,
    TextStyle? headline,
    TextStyle? row,
    TextStyle? small,
  }) {
    return SpendWiseText(
      hero: hero ?? this.hero,
      headline: headline ?? this.headline,
      row: row ?? this.row,
      small: small ?? this.small,
    );
  }

  @override
  SpendWiseText lerp(ThemeExtension<SpendWiseText>? other, double t) {
    if (other is! SpendWiseText) return this;
    return SpendWiseText(
      hero: TextStyle.lerp(hero, other.hero, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      row: TextStyle.lerp(row, other.row, t)!,
      small: TextStyle.lerp(small, other.small, t)!,
    );
  }
}

extension SpendWiseThemeContext on BuildContext {
  SpendWiseColors get colors =>
      Theme.of(this).extension<SpendWiseColors>() ?? SpendWiseColors.light;

  SpendWiseText get text =>
      Theme.of(this).extension<SpendWiseText>() ?? SpendWiseText.light;
}
