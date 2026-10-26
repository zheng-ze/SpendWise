import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

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
const _summaryPrimaryFontSize = 18.0;
const _summaryPrimaryWeight = FontWeight.w500;
const _summaryPrimaryLetterSpacing = -0.3;
const _summaryFlexScale = 100.0;
const _summaryMetricCount = 3;

enum SummaryMetricEmphasis { primary, supporting }

@immutable
class SummaryMetric {
  const SummaryMetric({
    required this.label,
    required this.amount,
    this.kind,
    this.emphasis = SummaryMetricEmphasis.supporting,
  });

  final String label;
  final Decimal amount;
  final AmountKind? kind;
  final SummaryMetricEmphasis emphasis;
}

class ResponsiveSummaryCard extends StatelessWidget {
  const ResponsiveSummaryCard({
    super.key,
    required this.metrics,
    required this.wideComposition,
  }) : assert(metrics.length == _summaryMetricCount);

  final List<SummaryMetric> metrics;
  final bool wideComposition;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: context.colors.surface,
      border: Border.all(
        color: context.colors.edge,
        width: _summaryBorderWidth,
      ),
      borderRadius: BorderRadius.circular(_summaryRadius),
    );
    const padding = EdgeInsets.symmetric(
      horizontal: _summaryHorizontalPadding,
      vertical: _summaryVerticalPadding,
    );
    final metricViews = [
      for (final metric in metrics)
        _SummaryMetricView(metric: _summaryMetric(context, metric)),
    ];

    final layout = LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth -
            (_summaryHorizontalPadding * 2) -
            (_summaryBorderWidth * 2);
        final widths = metrics
            .map((metric) => _metricRequiredWidth(context, metric))
            .toList();
        final allFit = _rowFits(widths, availableWidth, gap: _summaryColumnGap);
        final supportingValuesFit = _rowFits(
          widths.skip(1).toList(),
          availableWidth,
          gap: _summaryColumnGap,
        );
        final content = _summaryContent(
          metricViews,
          widths,
          wideComposition && allFit,
          supportingValuesFit,
        );
        return Container(
          decoration: decoration,
          padding: padding,
          child: content,
        );
      },
    );

    return layout;
  }
}

typedef _SummaryMetricData = ({String label, String value, TextStyle style});

_SummaryMetricData _summaryMetric(BuildContext context, SummaryMetric metric) {
  final primary = metric.emphasis == SummaryMetricEmphasis.primary;
  final style = TextStyle(
    fontSize: primary ? _summaryPrimaryFontSize : _summaryAmountFontSize,
    fontWeight: primary ? _summaryPrimaryWeight : _summaryAmountWeight,
    letterSpacing: primary ? _summaryPrimaryLetterSpacing : null,
    color: AmountStyle.of(
      context,
      kind: metric.kind,
      signedValue: metric.amount,
    ).color,
  );
  return (
    label: metric.label,
    value: formatSignedMoney(metric.amount, kind: metric.kind),
    style: style,
  );
}

class _SummaryMetricView extends StatelessWidget {
  const _SummaryMetricView({required this.metric});

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

List<Widget> _metricRow(List<_SummaryMetricView> metrics, List<double> widths) {
  return [
    for (var index = 0; index < metrics.length; index++) ...[
      if (index > 0) SizedBox(width: _summaryColumnGap),
      Expanded(
        flex: (widths[index] * _summaryFlexScale).round(),
        child: metrics[index],
      ),
    ],
  ];
}

Widget _summaryContent(
  List<_SummaryMetricView> metrics,
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
    final children = <Widget>[];
    for (var index = 0; index < metrics.length; index++) {
      if (index > 0) children.add(SizedBox(height: _summaryStackGap));
      children.add(metrics[index]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
  final supportingMetrics = metrics.skip(1).toList();
  final supportingWidths = widths.skip(1).toList();
  final supportingRow = Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: _metricRow(supportingMetrics, supportingWidths),
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      metrics.first,
      SizedBox(height: _summaryStackGap),
      supportingRow,
    ],
  );
}

double _metricRequiredWidth(BuildContext context, SummaryMetric metric) {
  final primary = metric.emphasis == SummaryMetricEmphasis.primary;
  final style = TextStyle(
    fontSize: primary ? _summaryPrimaryFontSize : _summaryAmountFontSize,
    fontWeight: primary ? _summaryPrimaryWeight : _summaryAmountWeight,
    letterSpacing: primary ? _summaryPrimaryLetterSpacing : null,
  );
  final labelWidth = _textWidth(
    context,
    metric.label,
    TextStyle(fontSize: _summaryLabelFontSize, color: context.colors.subtext),
  );
  final valueWidth = _textWidth(
    context,
    formatSignedMoney(metric.amount, kind: metric.kind),
    style,
  );
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
