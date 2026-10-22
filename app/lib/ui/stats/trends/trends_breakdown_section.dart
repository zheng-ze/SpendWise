import 'package:flutter/material.dart';

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/common/charts/category_map.dart';
import 'package:spendwise/ui/common/charts/donut_chart.dart';
import 'package:spendwise/ui/common/feedback/empty_state.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown.dart';
import 'package:spendwise/ui/stats/trends/trends_period_card.dart';
import 'package:spendwise/ui/stats/trends/trends_whole_period.dart';
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
const _chevron = Icons.chevron_right;
const _chevronSize = 14.0;
const _chevronPadding = EdgeInsets.only(left: 4);
const _percentFactor = 100;
const _regularDonutSize = 132.0;
const _totalLineAlignment = TextAlign.end;
const _scopeControlGap = 8.0;
const _scopeTotalGap = 4.0;

typedef _ColoredRow = ({TrendsBreakdownRow row, Color color});

class TrendsBreakdownSection extends StatelessWidget {
  const TrendsBreakdownSection({
    super.key,
    required this.breakdown,
    required this.amountKind,
    required this.onOpenCategory,
    this.header,
    this.scopeControl,
  });

  final TrendsBreakdown breakdown;
  final AmountKind amountKind;
  final ValueChanged<int> onOpenCategory;
  final TrendsBreakdownHeader? header;
  final Widget? scopeControl;

  @override
  Widget build(BuildContext context) => _BreakdownCard(section: this);
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.section});

  final TrendsBreakdownSection section;

  @override
  Widget build(BuildContext context) {
    final breakdown = section.breakdown;
    final amountKind = section.amountKind;
    final onOpenCategory = section.onOpenCategory;
    final header = section.header;
    final scopeControl = section.scopeControl;
    assert(scopeControl == null || header != null);
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
    final income = amountKind == AmountKind.income;
    final heading = _BreakdownHeading(
      title:
          header?.title ?? (income ? 'Income breakdown' : 'Expense breakdown'),
      subtitle: scopeControl == null
          ? header?.range ?? _levelLabel(breakdown.level)
          : _levelLabel(breakdown.level),
      total: scopeControl == null ? header?.total : null,
    );
    final chart = _BreakdownChart(
      rows: rows,
      chart: breakdown.chart,
      onSelect: onOpenCategory,
    );
    final rowWidgets = [
      for (var index = 0; index < rows.length; index++)
        _BreakdownRow(
          entry: rows[index],
          amountKind: amountKind,
          divided: index < rows.length - 1,
          onTap: _opener(rows[index].row, index, onOpenCategory),
        ),
    ];
    final empty = _EmptyBreakdown(income: amountKind == AmountKind.income);
    final content = rows.isEmpty ? [empty] : [chart, ...rowWidgets];
    final scopeContent = <Widget>[];
    if (scopeControl != null && header != null) {
      scopeContent.addAll([
        const SizedBox(height: _scopeControlGap),
        scopeControl,
        const SizedBox(height: _scopeTotalGap),
        _BreakdownTotalLine(
          label: header.range,
          total: header.total,
          amountKind: amountKind,
        ),
      ]);
    }
    final card = TrendsCard(
      children: [
        heading,
        ...scopeContent,
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

String _levelLabel(BreakdownLevel level) => switch (level) {
  BreakdownLevel.categories => 'By category',
  BreakdownLevel.subcategories => 'By subcategory',
};

VoidCallback? _opener(
  TrendsBreakdownRow row,
  int index,
  ValueChanged<int> open,
) => row.navigationTarget == null ? null : () => open(index);

class _BreakdownHeading extends StatelessWidget {
  const _BreakdownHeading({
    required this.title,
    required this.subtitle,
    required this.total,
  });

  final String title;
  final String subtitle;
  final String? total;

  @override
  Widget build(BuildContext context) {
    final heading = Text(
      title,
      style: const TextStyle(fontSize: _headingSize, fontWeight: _semiBold),
    );
    final caption = Text(
      subtitle,
      style: TextStyle(fontSize: _captionSize, color: context.colors.subtext),
    );
    final totalText = total == null
        ? null
        : Text(
            total!,
            style: const TextStyle(
              fontSize: _headingSize,
              fontWeight: _semiBold,
            ),
          );
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: _rowGap,
      runSpacing: _headingGap,
      children: [heading, caption, ?totalText],
    );
  }
}

class _BreakdownTotalLine extends StatelessWidget {
  const _BreakdownTotalLine({
    required this.label,
    required this.total,
    required this.amountKind,
  });

  final String label;
  final String total;
  final AmountKind amountKind;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label,
      style: TextStyle(fontSize: _captionSize, color: context.colors.subtext),
    );
    final totalText = Text(
      total,
      textAlign: _totalLineAlignment,
      style: context.text.small.copyWith(
        fontSize: _headingSize,
        fontWeight: _semiBold,
        color: AmountStyle.of(context, kind: amountKind).color,
      ),
    );
    return Row(
      children: [
        Expanded(child: labelText),
        totalText,
      ],
    );
  }
}

List<DonutSegment> _donutSegments(List<_ColoredRow> rows) {
  return [
    for (final entry in rows)
      DonutSegment(
        label: entry.row.name,
        value: entry.row.amount.toDouble(),
        color: entry.color,
      ),
  ];
}

List<CategoryMapTile> _mapTiles(List<_ColoredRow> rows) {
  return [
    for (final entry in rows)
      CategoryMapTile(
        label: entry.row.name,
        share: entry.row.sharePercent.toDouble() / _percentFactor,
        color: entry.color,
      ),
  ];
}

class _BreakdownChart extends StatelessWidget {
  const _BreakdownChart({
    required this.rows,
    required this.chart,
    required this.onSelect,
  });

  final List<_ColoredRow> rows;
  final BreakdownChart chart;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final Widget visual;
    switch (chart) {
      case BreakdownChart.donut:
        visual = Center(
          child: DonutChart(
            size: _regularDonutSize,
            segments: _donutSegments(rows),
            centerLabel: rows.first.row.formattedShare,
            centerValue: rows.first.row.name,
            onSelect: onSelect,
          ),
        );
      case BreakdownChart.categoryMap:
        visual = CategoryMap(tiles: _mapTiles(rows), onSelect: onSelect);
    }
    return Padding(padding: _chartPadding, child: visual);
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.entry,
    required this.amountKind,
    required this.divided,
    required this.onTap,
  });

  final _ColoredRow entry;
  final AmountKind amountKind;
  final bool divided;
  final VoidCallback? onTap;

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
    final captionStyle = TextStyle(
      fontSize: _captionSize,
      color: colors.subtext,
    );
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.name,
          style: const TextStyle(fontSize: _nameSize, fontWeight: _semiBold),
        ),
        const SizedBox(height: _captionGap),
        Text(caption, style: captionStyle),
      ],
    );
    final amountText = Text(
      row.formattedAmount,
      textAlign: TextAlign.end,
      style: context.text.small.copyWith(
        color: AmountStyle.of(context, kind: amountKind).color,
      ),
    );
    final chevron = onTap == null
        ? null
        : Padding(
            padding: _chevronPadding,
            child: Icon(_chevron, size: _chevronSize, color: colors.subtext),
          );
    final content = Row(
      children: [
        swatch,
        const SizedBox(width: _rowGap),
        Expanded(child: label),
        const SizedBox(width: _rowGap),
        amountText,
        ?chevron,
      ],
    );
    final border = divided
        ? Border(
            bottom: BorderSide(color: colors.edge, width: _dividerWidth),
          )
        : null;
    final surface = Container(
      padding: _rowPadding,
      decoration: BoxDecoration(border: border),
      child: content,
    );
    return onTap == null ? surface : InkWell(onTap: onTap, child: surface);
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
