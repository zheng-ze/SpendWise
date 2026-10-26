import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/lists/responsive_summary_card.dart';
import 'package:spendwise/ui/format/money_format.dart';

const _summaryPageHorizontalInset = 14.0;
const _netLabel = 'Net';
const _spentLabel = 'Spent';
const _incomeLabel = 'Income';

class TransactionsSummary extends StatelessWidget {
  const TransactionsSummary({
    super.key,
    required this.net,
    required this.expenses,
    required this.income,
    required this.wideComposition,
    required this.bottomSpacing,
  });

  final Decimal net;
  final Decimal expenses;
  final Decimal income;
  final bool wideComposition;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      SummaryMetric(
        label: _netLabel,
        amount: net,
        emphasis: SummaryMetricEmphasis.primary,
      ),
      SummaryMetric(
        label: _spentLabel,
        amount: expenses,
        kind: AmountKind.expense,
      ),
      SummaryMetric(
        label: _incomeLabel,
        amount: income,
        kind: AmountKind.income,
      ),
    ];
    final card = ResponsiveSummaryCard(
      metrics: metrics,
      wideComposition: wideComposition,
    );

    return Padding(
      padding: EdgeInsets.only(
        left: _summaryPageHorizontalInset,
        right: _summaryPageHorizontalInset,
        bottom: bottomSpacing,
      ),
      child: card,
    );
  }
}
