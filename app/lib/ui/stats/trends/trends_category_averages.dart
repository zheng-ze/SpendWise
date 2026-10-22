import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/trends/trends_average_comparison.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_period_card.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

const trendsCategoryAveragesStackedWidth = 300.0;
const _sectionGap = 12.0;
const _headingGap = 8.0;
const _rowGap = 8.0;
const _rowPadding = EdgeInsets.symmetric(vertical: 7);
const _captionGap = 2.0;
const _dividerWidth = 1.0;
const _headingSize = 14.0;
const _nameSize = 12.0;
const _captionSize = 10.0;
const _amountColumnWidth = 72.0;
const _averageColumnWidth = 76.0;
const _captionSeparator = ': ';
const _categoryAveragesTitle = 'Category averages';
const _semiBold = FontWeight.w600;
const _trailingTextAlign = TextAlign.end;
const _rowValuesMainAxisSize = MainAxisSize.min;
const _startCrossAxisAlignment = CrossAxisAlignment.start;

class TrendsCategoryAverages extends StatelessWidget {
  const TrendsCategoryAverages({
    super.key,
    required this.breakdown,
    required this.averageComparison,
    required this.onOpenCategory,
  });

  final TrendsBreakdown breakdown;
  final TrendsAverageComparison averageComparison;
  final ValueChanged<int> onOpenCategory;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _CategoryAveragesTable(
      breakdown: breakdown,
      averageComparison: averageComparison,
      onOpenCategory: onOpenCategory,
      stacked: constraints.maxWidth < trendsCategoryAveragesStackedWidth,
    ),
  );
}

class _CategoryAveragesTable extends StatelessWidget {
  const _CategoryAveragesTable({
    required this.breakdown,
    required this.averageComparison,
    required this.onOpenCategory,
    required this.stacked,
  });

  final TrendsBreakdown breakdown;
  final TrendsAverageComparison averageComparison;
  final ValueChanged<int> onOpenCategory;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    assert(averageComparison.rows.length == breakdown.rows.length);
    final rows = [
      for (var index = 0; index < breakdown.rows.length; index++)
        _CategoryAverageRow(
          row: breakdown.rows[index],
          comparison: averageComparison.rows[index],
          averageLabel: averageComparison.header,
          amountKind: breakdown.kind == CategoryKind.income
              ? AmountKind.income
              : AmountKind.expense,
          divided: index < breakdown.rows.length - 1,
          stacked: stacked,
          onTap: breakdown.rows[index].navigationTarget == null
              ? null
              : () => onOpenCategory(index),
        ),
    ];
    final title = const Text(
      _categoryAveragesTitle,
      style: TextStyle(fontSize: _headingSize, fontWeight: _semiBold),
    );
    final header = _CategoryAveragesHeader(
      period: _periodLabel(breakdown.mode, breakdown.period),
      average: averageComparison.header,
      stacked: stacked,
    );
    final card = TrendsCard(
      children: [
        title,
        const SizedBox(height: _headingGap),
        header,
        ...rows,
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: _sectionGap),
      child: card,
    );
  }
}

String _periodLabel(TrendsMode mode, DateTime period) => switch (mode) {
  TrendsMode.month => formatMonthLabel(period),
  TrendsMode.year => formatYearLabel(period),
};

class _CategoryAveragesHeader extends StatelessWidget {
  const _CategoryAveragesHeader({
    required this.period,
    required this.average,
    required this.stacked,
  });

  final String period;
  final String average;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: _captionSize,
      color: context.colors.subtext,
    );
    final columns = [
      SizedBox(
        width: _amountColumnWidth,
        child: Text(period, textAlign: _trailingTextAlign, style: style),
      ),
      if (!stacked) const SizedBox(width: _rowGap),
      if (!stacked)
        SizedBox(
          width: _averageColumnWidth,
          child: Text(average, textAlign: _trailingTextAlign, style: style),
        ),
    ];
    return Row(children: [const Spacer(), ...columns]);
  }
}

class _CategoryAverageRow extends StatelessWidget {
  const _CategoryAverageRow({
    required this.row,
    required this.comparison,
    required this.averageLabel,
    required this.amountKind,
    required this.divided,
    required this.stacked,
    required this.onTap,
  });

  final TrendsBreakdownRow row;
  final TrendsAverageComparisonRow comparison;
  final String averageLabel;
  final AmountKind amountKind;
  final bool divided;
  final bool stacked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = _CategoryAverageMetadata(
      row: row,
      comparison: comparison,
      averageLabel: averageLabel,
      stacked: stacked,
    );
    final amount = SizedBox(
      width: _amountColumnWidth,
      child: Text(
        row.formattedAmount,
        textAlign: _trailingTextAlign,
        style: context.text.small.copyWith(
          color: AmountStyle.of(context, kind: amountKind).color,
        ),
      ),
    );
    final average = stacked
        ? null
        : SizedBox(
            width: _averageColumnWidth,
            child: Text(
              comparison.formattedMean,
              textAlign: _trailingTextAlign,
              style: context.text.small.copyWith(
                color: AmountStyle.of(context, kind: amountKind).color,
              ),
            ),
          );
    final values = Row(
      mainAxisSize: _rowValuesMainAxisSize,
      children: [
        amount,
        if (average != null) ...[const SizedBox(width: _rowGap), average],
      ],
    );
    final content = Row(
      children: [
        Expanded(child: label),
        const SizedBox(width: _rowGap),
        values,
      ],
    );
    final border = divided
        ? Border(
            bottom: BorderSide(
              color: context.colors.edge,
              width: _dividerWidth,
            ),
          )
        : null;
    final surface = Padding(
      padding: _rowPadding,
      child: DecoratedBox(
        decoration: BoxDecoration(border: border),
        child: content,
      ),
    );
    return onTap == null ? surface : InkWell(onTap: onTap, child: surface);
  }
}

class _CategoryAverageMetadata extends StatelessWidget {
  const _CategoryAverageMetadata({
    required this.row,
    required this.comparison,
    required this.averageLabel,
    required this.stacked,
  });

  final TrendsBreakdownRow row;
  final TrendsAverageComparisonRow comparison;
  final String averageLabel;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final name = Text(
      row.name,
      style: const TextStyle(fontSize: _nameSize, fontWeight: _semiBold),
    );
    final parent = row.parentContext;
    final captionStyle = TextStyle(
      fontSize: _captionSize,
      color: context.colors.subtext,
    );
    final parentText = parent == null
        ? null
        : Text(parent, style: captionStyle);
    final averageText = stacked
        ? Text(
            '$averageLabel$_captionSeparator${comparison.formattedMean}',
            style: captionStyle,
          )
        : null;
    return Column(
      crossAxisAlignment: _startCrossAxisAlignment,
      children: [
        name,
        if (parentText != null) ...[
          const SizedBox(height: _captionGap),
          parentText,
        ],
        if (averageText != null) ...[
          const SizedBox(height: _captionGap),
          averageText,
        ],
      ],
    );
  }
}
