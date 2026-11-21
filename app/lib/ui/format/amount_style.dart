import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - AmountStyle
@immutable
class AmountStyle {
  const AmountStyle({required this.color});

  factory AmountStyle.of(
    BuildContext context, {
    AmountKind? kind,
    Decimal? signedValue,
  }) {
    final colors = context.colors;
    if (signedValue != null && signedValue < Decimal.zero) {
      return AmountStyle(color: colors.expense);
    }
    if (kind != null) {
      return AmountStyle(
        color: switch (kind) {
          AmountKind.income => colors.income,
          AmountKind.expense => colors.expense,
          AmountKind.transfer => colors.text,
        },
      );
    }
    if (signedValue != null && signedValue > Decimal.zero) {
      return AmountStyle(color: colors.income);
    }
    return AmountStyle(color: colors.text);
  }

  final Color color;
}

AmountKind amountKindOfSign(Decimal value) {
  if (value < Decimal.zero) return AmountKind.expense;
  if (value > Decimal.zero) return AmountKind.income;
  return AmountKind.transfer;
}

// MARK: - AmountText
enum AmountTextSize { small, row, headline }

class AmountText extends StatelessWidget {
  AmountText({
    super.key,
    required Decimal amount,
    required this.kind,
    this.size = AmountTextSize.small,
    this.textAlign,
    bool showSymbol = false,
    this.color,
  }) : text = formatSignedMoney(amount, kind: kind, symbol: showSymbol);

  const AmountText.formatted({
    super.key,
    required this.text,
    required this.kind,
    this.size = AmountTextSize.small,
    this.textAlign,
    this.color,
  });

  final String text;
  final AmountKind kind;
  final AmountTextSize size;
  final TextAlign? textAlign;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = switch (size) {
      AmountTextSize.small => context.text.small,
      AmountTextSize.row => context.text.row,
      AmountTextSize.headline => context.text.headline,
    };
    return Text(
      text,
      textAlign: textAlign,
      style: base.copyWith(
        color: color ?? AmountStyle.of(context, kind: kind).color,
      ),
    );
  }
}
