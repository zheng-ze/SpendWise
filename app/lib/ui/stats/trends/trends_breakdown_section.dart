import 'package:flutter/material.dart';

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/common/charts/category_map.dart';
import 'package:spendwise/ui/common/charts/donut_chart.dart';
import 'package:spendwise/ui/common/lists/breakdown_row.dart';
import 'package:spendwise/ui/common/feedback/empty_state.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown.dart';
import 'package:spendwise/ui/stats/trends/trends_period_card.dart';
import 'package:spendwise/ui/stats/trends/trends_whole_period.dart';
import 'package:spendwise/ui/theme/category_palette.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

const _captionSeparator = ' / ';
const _sectionGap = 12.0;
const _headingGap = 4.0;
const _headingPadding = 0.0;
const _chartPadding = EdgeInsets.only(top: 4, bottom: 6);
const _rowGap = 8.0;
const _emptyIcon = Icons.attach_money;
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
        _breakdownRow(
          rows[index],
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
    final heading = TrayHeader(title: title, bottomPadding: _headingPadding);
    final caption = Text(
      subtitle,
      style: context.text.caption.copyWith(color: context.colors.subtext),
    );
    final totalText = total == null
        ? null
        : Text(
            total!,
            style: context.text.title.copyWith(
              fontWeight: SpendWiseText.semibold,
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
      style: context.text.caption.copyWith(color: context.colors.subtext),
    );
    final totalText = AmountText.formatted(
      text: total,
      kind: amountKind,
      size: AmountTextSize.row,
      textAlign: _totalLineAlignment,
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

BreakdownRow _breakdownRow(
  _ColoredRow entry, {
  required AmountKind amountKind,
  required bool divided,
  required VoidCallback? onTap,
}) {
  final row = entry.row;
  final parent = row.parentContext;
  final caption = parent == null
      ? row.formattedShare
      : '${row.formattedShare}$_captionSeparator$parent';
  return BreakdownRow(
    swatchColor: entry.color,
    name: row.name,
    caption: caption,
    amount: row.formattedAmount,
    amountKind: amountKind,
    divided: divided,
    onTap: onTap,
  );
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
