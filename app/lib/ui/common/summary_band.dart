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

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.edge),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      ),
    );
  }
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: colors.subtext)),
        Text(
          formatSignedMoney(amount, kind: kind, symbol: symbol),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
            color: AmountStyle.of(
              context,
              kind: kind,
              signedValue: amount,
            ).color,
          ),
        ),
      ],
    );
  }
}

class _CellAmount extends StatelessWidget {
  const _CellAmount({required this.cell});

  final SummaryBandCell cell;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(cell.label, style: TextStyle(fontSize: 10, color: colors.subtext)),
        const SizedBox(height: 2),
        Text(
          formatSignedMoney(cell.amount, kind: cell.kind, symbol: cell.symbol),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AmountStyle.of(
              context,
              kind: cell.kind,
              signedValue: cell.amount,
            ).color,
          ),
        ),
      ],
    );
  }
}
