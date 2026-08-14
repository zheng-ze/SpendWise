import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/money_format.dart';

@immutable
class AmountColors {
  const AmountColors({
    required this.gain,
    required this.loss,
    required this.neutral,
  });

  factory AmountColors.of(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    return AmountColors(
      gain: dark ? const Color(0xFF6FA8FF) : const Color(0xFF0A64C8),
      loss: dark ? const Color(0xFFFF7A73) : const Color(0xFFC81E14),
      neutral: theme.colorScheme.onSurfaceVariant,
    );
  }

  final Color gain;
  final Color loss;
  final Color neutral;

  Color netAmountColor(Decimal amount) {
    if (amount > Decimal.zero) return gain;
    if (amount < Decimal.zero) return loss;
    return neutral;
  }

  Color kindColor(AmountKind kind) {
    return switch (kind) {
      AmountKind.income => gain,
      AmountKind.expense => loss,
      AmountKind.transfer => neutral,
    };
  }
}
