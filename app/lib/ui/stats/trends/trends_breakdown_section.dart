import 'package:flutter/material.dart';

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/common/charts/category_map.dart';
import 'package:spendwise/ui/common/charts/donut_chart.dart';
import 'package:spendwise/ui/common/feedback/empty_state.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown.dart';
import 'package:spendwise/ui/stats/trends/trends_period_card.dart';
import 'package:spendwise/ui/theme/category_palette.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

const _captionSeparator = ' / ';
const _headingSize = 14.0;
const _nameSize = 12.0;
const _captionSize = 10.0;
const _semiBold = FontWeight.w600;
const _sectionGap = 12.0;
const _headingGap = 4.0;
const _chartPadding = EdgeInsets.only(top: 4, bottom: 6);
const _rowPadding = EdgeInsets.symmetric(vertical: 7);
const _rowGap = 8.0;
const _captionGap = 2.0;
const _swatchSize = 10.0;
const _swatchRadius = 3.0;
const _dividerWidth = 1.0;
const _emptyIcon = Icons.attach_money;
const _percentFactor = 100;

typedef _ColoredRow = ({TrendsBreakdownRow row, Color color});

class TrendsBreakdownSection extends StatelessWidget {
  const TrendsBreakdownSection({
    super.key,
    required this.breakdown,
    required this.amountKind,
  });

  final TrendsBreakdown breakdown;
  final AmountKind amountKind;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rows = [
      for (var i = 0; i < breakdown.rows.length; i++)
        (
          row: breakdown.rows[i],
          color: CategoryPalette.resolve(
            savedHex: breakdown.rows[i].savedHex,
            rank: i,
            mode: breakdown.colours,
            colors: colors,
          ),
        ),
    ];
    final heading = _BreakdownHeading(
      income: amountKind == AmountKind.income,
      level: breakdown.level,
    );
    final content = rows.isEmpty
        ? [_EmptyBreakdown(income: amountKind == AmountKind.income)]
        : <Widget>[
            _BreakdownChart(rows: rows, chart: breakdown.chart),
            for (var i = 0; i < rows.length; i++)
              _BreakdownRow(
                entry: rows[i],
                amountKind: amountKind,
                divided: i < rows.length - 1,
              ),
          ];
    final card = TrendsCard(
      children: [
        heading,
        const SizedBox(height: _headingGap),
        ...content,
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: _sectionGap),
      child: card,
    );
  }
}

class _BreakdownHeading extends StatelessWidget {
  const _BreakdownHeading({required this.income, required this.level});

  final bool income;
  final BreakdownLevel level;

  @override
  Widget build(BuildContext context) {
    final heading = Text(
      income ? 'Income breakdown' : 'Expense breakdown',
      style: const TextStyle(fontSize: _headingSize, fontWeight: _semiBold),
    );
    final subtitle = Text(
      level == BreakdownLevel.categories ? 'By category' : 'By subcategory',
      style: TextStyle(fontSize: _captionSize, color: context.colors.subtext),
    );
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: _rowGap,
      runSpacing: _headingGap,
      children: [heading, subtitle],
    );
  }
}

class _BreakdownChart extends StatelessWidget {
  const _BreakdownChart({required this.rows, required this.chart});

  final List<_ColoredRow> rows;
  final BreakdownChart chart;

  @override
  Widget build(BuildContext context) {
    final Widget visual;
    switch (chart) {
      case BreakdownChart.donut:
        final segments = [
          for (final entry in rows)
            DonutSegment(
              label: entry.row.name,
              value: entry.row.amount.toDouble(),
              color: entry.color,
            ),
        ];
        visual = Center(
          child: DonutChart(
            segments: segments,
            centerLabel: rows.first.row.formattedShare,
            centerValue: rows.first.row.name,
          ),
        );
      case BreakdownChart.categoryMap:
        final tiles = [
          for (final entry in rows)
            CategoryMapTile(
              label: entry.row.name,
              share: entry.row.sharePercent.toDouble() / _percentFactor,
              color: entry.color,
            ),
        ];
        visual = CategoryMap(tiles: tiles);
    }
    return Padding(padding: _chartPadding, child: visual);
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.entry,
    required this.amountKind,
    required this.divided,
  });

  final _ColoredRow entry;
  final AmountKind amountKind;
  final bool divided;

  @override
  Widget build(BuildContext context) {
    final row = entry.row;
    final colors = context.colors;
    final parent = row.parentContext;
    final caption = parent == null
        ? row.formattedShare
        : '${row.formattedShare}$_captionSeparator$parent';
    final swatch = Container(
      width: _swatchSize,
      height: _swatchSize,
      decoration: BoxDecoration(
        color: entry.color,
        borderRadius: BorderRadius.circular(_swatchRadius),
      ),
    );
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.name,
          style: const TextStyle(fontSize: _nameSize, fontWeight: _semiBold),
        ),
        const SizedBox(height: _captionGap),
        Text(
          caption,
          style: TextStyle(fontSize: _captionSize, color: colors.subtext),
        ),
      ],
    );
    final amount = Text(
      row.formattedAmount,
      style: context.text.small.copyWith(
        color: AmountStyle.of(context, kind: amountKind).color,
      ),
    );
    final content = Row(
      children: [
        swatch,
        const SizedBox(width: _rowGap),
        Expanded(child: label),
        const SizedBox(width: _rowGap),
        amount,
      ],
    );
    final border = divided
        ? Border(
            bottom: BorderSide(color: colors.edge, width: _dividerWidth),
          )
        : null;
    return Container(
      padding: _rowPadding,
      decoration: BoxDecoration(border: border),
      child: content,
    );
  }
}

class _EmptyBreakdown extends StatelessWidget {
  const _EmptyBreakdown({required this.income});

  final bool income;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: _emptyIcon,
      title: income ? 'No income recorded' : 'No expenses recorded',
      body: income
          ? 'Income entries in this period will appear here.'
          : 'Expense entries in this period will appear here.',
    );
  }
}
