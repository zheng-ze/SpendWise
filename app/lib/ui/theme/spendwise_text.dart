import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_colors.dart';

// MARK: - Constants
const _amountFamily = 'InstrumentSans';
const _heroSize = 34.0;
const _heroLetterSpacing = -1.2;
const _headlineSize = 26.0;
const _headlineLetterSpacing = -0.7;
const _rowSize = 14.0;
const _rowLetterSpacing = -0.2;
const _smallSize = 12.0;
const _smallLetterSpacing = 0.0;

// MARK: - Amount Style

TextStyle _amount(double size, FontWeight weight, double letterSpacing) {
  return const TextStyle().copyWith(
    fontFamily: _amountFamily,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

// MARK: - SpendWiseText
class SpendWiseText extends ThemeExtension<SpendWiseText> {
  const SpendWiseText({
    required this.hero,
    required this.headline,
    required this.row,
    required this.small,
  });

  static final light = SpendWiseText(
    hero: _amount(_heroSize, FontWeight.w500, _heroLetterSpacing),
    headline: _amount(_headlineSize, FontWeight.w500, _headlineLetterSpacing),
    row: _amount(_rowSize, FontWeight.w600, _rowLetterSpacing),
    small: _amount(_smallSize, FontWeight.w600, _smallLetterSpacing),
  );

  static final dark = SpendWiseText(
    hero: _amount(_heroSize, FontWeight.w500, _heroLetterSpacing),
    headline: _amount(_headlineSize, FontWeight.w500, _headlineLetterSpacing),
    row: _amount(_rowSize, FontWeight.w600, _rowLetterSpacing),
    small: _amount(_smallSize, FontWeight.w600, _smallLetterSpacing),
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

// MARK: - SpendWiseThemeContext
extension SpendWiseThemeContext on BuildContext {
  SpendWiseColors get colors =>
      Theme.of(this).extension<SpendWiseColors>() ?? SpendWiseColors.light;

  SpendWiseText get text =>
      Theme.of(this).extension<SpendWiseText>() ?? SpendWiseText.light;
}
