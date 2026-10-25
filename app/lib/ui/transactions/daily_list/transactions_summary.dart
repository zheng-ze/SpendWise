import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

const _summaryPageHorizontalInset = 14.0;
const _summaryRadius = 14.0;
const _summaryBorderWidth = 1.0;
const _summaryHorizontalPadding = 12.0;
const _summaryVerticalPadding = 10.0;
const _summaryColumnGap = 6.0;
const _summaryStackGap = 4.0;
const _summaryLabelFontSize = 10.0;
const _summaryLabelAmountGap = 2.0;
const _summaryAmountFontSize = 12.0;
const _summaryAmountWeight = FontWeight.w600;
const _summaryLeadFontSize = 18.0;
const _summaryLeadWeight = FontWeight.w500;
const _summaryLeadLetterSpacing = -0.3;
const _summaryFlexScale = 100.0;
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
  });

  final Decimal net;
  final Decimal expenses;
  final Decimal income;
  final bool wideComposition;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _summaryMetric(
        context,
        label: _netLabel,
        amount: net,
        kind: null,
        isLead: true,
      ),
      _summaryMetric(
        context,
        label: _spentLabel,
        amount: expenses,
        kind: AmountKind.expense,
      ),
      _summaryMetric(
        context,
        label: _incomeLabel,
        amount: income,
        kind: AmountKind.income,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _summaryPageHorizontalInset,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth =
              constraints.maxWidth -
              (_summaryHorizontalPadding * 2) -
              (_summaryBorderWidth * 2);
          final widths = metrics
              .map((metric) => _metricRequiredWidth(context, metric))
              .toList();
          final allFit = _rowFits(
            widths,
            availableWidth,
            gap: _summaryColumnGap,
          );
          final supportingValuesFit = _rowFits(
            widths.skip(1).toList(),
            availableWidth,
            gap: _summaryColumnGap,
          );
          final content = _totalsContent(
            metrics,
            widths,
            wideComposition && allFit,
            supportingValuesFit,
          );
          return Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border.all(
                color: context.colors.edge,
                width: _summaryBorderWidth,
              ),
              borderRadius: BorderRadius.circular(_summaryRadius),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: _summaryHorizontalPadding,
              vertical: _summaryVerticalPadding,
            ),
            child: content,
          );
        },
      ),
    );
  }
}

typedef _SummaryMetricData = ({String label, String value, TextStyle style});

_SummaryMetricData _summaryMetric(
  BuildContext context, {
  required String label,
  required Decimal amount,
  required AmountKind? kind,
  bool isLead = false,
}) {
  final style = TextStyle(
    fontSize: isLead ? _summaryLeadFontSize : _summaryAmountFontSize,
    fontWeight: isLead ? _summaryLeadWeight : _summaryAmountWeight,
    letterSpacing: isLead ? _summaryLeadLetterSpacing : null,
    color: AmountStyle.of(context, kind: kind, signedValue: amount).color,
  );
  return (
    label: label,
    value: formatSignedMoney(amount, kind: kind),
    style: style,
  );
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.metric});

  final _SummaryMetricData metric;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      metric.label,
      style: TextStyle(
        fontSize: _summaryLabelFontSize,
        color: context.colors.subtext,
      ),
    );
    final value = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text(
        metric.value,
        maxLines: 1,
        softWrap: false,
        style: metric.style,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label,
        SizedBox(height: _summaryLabelAmountGap),
        value,
      ],
    );
  }
}

List<Widget> _metricRow(List<_SummaryMetricData> metrics, List<double> widths) {
  return [
    for (var index = 0; index < metrics.length; index++) ...[
      if (index > 0) SizedBox(width: _summaryColumnGap),
      Expanded(
        flex: (widths[index] * _summaryFlexScale).round(),
        child: _SummaryMetric(metric: metrics[index]),
      ),
    ],
  ];
}

Widget _totalsContent(
  List<_SummaryMetricData> metrics,
  List<double> widths,
  bool useWideRow,
  bool supportingValuesFit,
) {
  if (useWideRow) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: _metricRow(metrics, widths),
    );
  }
  if (!supportingValuesFit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          if (index > 0) SizedBox(height: _summaryStackGap),
          _SummaryMetric(metric: metrics[index]),
        ],
      ],
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SummaryMetric(metric: metrics.first),
      SizedBox(height: _summaryStackGap),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _metricRow(metrics.skip(1).toList(), widths.skip(1).toList()),
      ),
    ],
  );
}

double _metricRequiredWidth(BuildContext context, _SummaryMetricData metric) {
  final labelWidth = _textWidth(
    context,
    metric.label,
    TextStyle(fontSize: _summaryLabelFontSize, color: context.colors.subtext),
  );
  final valueWidth = _textWidth(context, metric.value, metric.style);
  return labelWidth > valueWidth ? labelWidth : valueWidth;
}

double _textWidth(BuildContext context, String value, TextStyle style) {
  final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
  final painter = TextPainter(
    text: TextSpan(text: value, style: effectiveStyle),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return painter.width;
}

bool _rowFits(
  List<double> widths,
  double availableWidth, {
  required double gap,
}) {
  final requiredWidth =
      widths.fold<double>(0, (total, width) => total + width) +
      gap * (widths.length - 1);
  return requiredWidth <= availableWidth;
}
