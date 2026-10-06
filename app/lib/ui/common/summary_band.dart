import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

@immutable
class SummaryBandCell {
  const SummaryBandCell({
    required this.label,
    required this.amount,
    this.kind,
    this.symbol = true,
  });

  final String label;

  final Decimal amount;

  final AmountKind? kind;

  final bool symbol;
}

class SummaryBand extends StatelessWidget {
  const SummaryBand({
    super.key,
    this.leadLabel,
    this.leadAmount,
    this.leadKind,
    this.leadSymbol = true,
    this.cells = const [],
  });

  final String? leadLabel;

  final Decimal? leadAmount;

  final AmountKind? leadKind;

  final bool leadSymbol;

  final List<SummaryBandCell> cells;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final leadLabel = this.leadLabel;
    final leadAmount = this.leadAmount;
    final lead = leadLabel != null && leadAmount != null
        ? _LeadAmount(
            label: leadLabel,
            amount: leadAmount,
            kind: leadKind,
            symbol: leadSymbol,
          )
        : null;
    final cellRow = cells.isEmpty
        ? null
        : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final cell in cells)
                Expanded(child: _CellAmount(cell: cell)),
            ],
          );

    final content = <Widget>[];
    if (lead != null) content.add(lead);
    if (cellRow != null) content.add(cellRow);

    final decoration = BoxDecoration(
      color: colors.surface,
      border: Border.all(color: colors.edge),
      borderRadius: BorderRadius.circular(14),
    );
    return Container(
      decoration: decoration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      ),
    );
  }
}

Color _amountColor(BuildContext context, AmountKind? kind, Decimal value) {
  return AmountStyle.of(context, kind: kind, signedValue: value).color;
}

class _LeadAmount extends StatelessWidget {
  const _LeadAmount({
    required this.label,
    required this.amount,
    required this.kind,
    required this.symbol,
  });

  final String label;

  final Decimal amount;

  final AmountKind? kind;

  final bool symbol;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labelText = Text(
      label,
      style: TextStyle(fontSize: 10, color: colors.subtext),
    );
    final amountText = Text(
      formatSignedMoney(amount, kind: kind, symbol: symbol),
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.3,
        color: _amountColor(context, kind, amount),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [labelText, amountText],
    );
  }
}

class _CellAmount extends StatelessWidget {
  const _CellAmount({required this.cell});

  final SummaryBandCell cell;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labelText = Text(
      cell.label,
      style: TextStyle(fontSize: 10, color: colors.subtext),
    );
    final amountText = Text(
      formatSignedMoney(cell.amount, kind: cell.kind, symbol: cell.symbol),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _amountColor(context, cell.kind, cell.amount),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [labelText, const SizedBox(height: 2), amountText],
    );
  }
}
