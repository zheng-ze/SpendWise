import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

@immutable
class AmountStyle {
  const AmountStyle({required this.color});

  factory AmountStyle.of(
    BuildContext context, {
    AmountKind? kind,
    Decimal? signedValue,
  }) {
    final colors = context.colors;
    if (kind != null) {
      return AmountStyle(
        color: switch (kind) {
          AmountKind.income => colors.income,
          AmountKind.expense => colors.expense,
          AmountKind.transfer => colors.text,
        },
      );
    }
    if (signedValue != null) {
      if (signedValue > Decimal.zero) return AmountStyle(color: colors.income);
      if (signedValue < Decimal.zero) return AmountStyle(color: colors.expense);
    }
    return AmountStyle(color: colors.text);
  }

  final Color color;
}
