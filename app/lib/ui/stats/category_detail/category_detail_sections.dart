import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_body.dart';
import 'package:spendwise/ui/stats/category_detail/category_scope.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

const _headlinePadding = EdgeInsets.only(bottom: 12);
const _chipsPadding = EdgeInsets.only(bottom: 12);
const _chipGap = 6.0;
const _chipPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 5);
const _chipRadius = 20.0;
const _chipFontSize = 12.0;
const _mediumWeight = FontWeight.w600;
const _borderWidth = 1.0;
const _markerSize = 8.0;
const _markerRadius = 2.0;
const _rowGap = 8.0;
const _rowPadding = EdgeInsets.symmetric(vertical: 7);
const _rowTitleSize = 12.0;
const _rowCaptionSize = 11.0;

class CategoryDetailHeadline extends StatelessWidget {
  const CategoryDetailHeadline({
    super.key,
    required this.amount,
    required this.kind,
  });

  final Decimal amount;
  final AmountKind kind;

  @override
  Widget build(BuildContext context) {
    final style = AmountStyle.of(context, kind: kind);
    final text = Text(
      formatSignedMoney(amount, kind: kind),
      style: context.text.headline.copyWith(color: style.color),
    );
    return Padding(padding: _headlinePadding, child: text);
  }
}

class CategoryDetailScopeChips extends StatelessWidget {
  const CategoryDetailScopeChips({
    super.key,
    required this.chips,
    required this.onSelect,
  });

  final List<CategoryDetailScopeChip> chips;
  final ValueChanged<CategoryScope> onSelect;

  @override
  Widget build(BuildContext context) {
    final children = chips.map((chip) {
      return _ScopeChip(chip: chip, onSelect: onSelect);
    }).toList();
    final content = Wrap(
      spacing: _chipGap,
      runSpacing: _chipGap,
      children: children,
    );
    return Padding(padding: _chipsPadding, child: content);
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.chip, required this.onSelect});

  final CategoryDetailScopeChip chip;
  final ValueChanged<CategoryScope> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fill = chip.selected ? colors.tint : colors.surface;
    final foreground = chip.selected ? colors.action : colors.subtext;
    final border = Border.all(color: colors.edge, width: _borderWidth);
    final radius = BorderRadius.circular(_chipRadius);
    final label = Text(
      chip.label,
      style: TextStyle(
        fontSize: _chipFontSize,
        color: foreground,
        fontWeight: _mediumWeight,
      ),
    );
    final padded = Padding(padding: _chipPadding, child: label);
    final tap = InkWell(
      borderRadius: radius,
      onTap: () => onSelect(chip.scope),
      child: padded,
    );
    final face = Material(
      color: fill,
      shape: RoundedRectangleBorder(borderRadius: radius, side: border.top),
      child: tap,
    );
    return Semantics(button: true, selected: chip.selected, child: face);
  }
}

class CategoryDetailSubcategories extends StatelessWidget {
  const CategoryDetailSubcategories({
    super.key,
    required this.rows,
    required this.kind,
    required this.onSelect,
  });

  final List<CategoryDetailBreakdownRow> rows;
  final AmountKind kind;
  final ValueChanged<CategoryScope> onSelect;

  @override
  Widget build(BuildContext context) {
    final children = rows.map((row) {
      return _BreakdownRow(row: row, kind: kind, onSelect: onSelect);
    }).toList();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    return Tray(title: 'Subcategories', child: content);
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.row,
    required this.kind,
    required this.onSelect,
  });

  final CategoryDetailBreakdownRow row;
  final AmountKind kind;
  final ValueChanged<CategoryScope> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final savedHex = row.savedHex;
    final markerColor = savedHex == null
        ? colorHexFallback
        : parseColorHex(savedHex);
    final markerDecoration = BoxDecoration(
      color: markerColor,
      borderRadius: BorderRadius.circular(_markerRadius),
    );
    final marker = Container(
      width: _markerSize,
      height: _markerSize,
      decoration: markerDecoration,
    );
    final title = Text(
      row.label,
      style: const TextStyle(
        fontSize: _rowTitleSize,
        fontWeight: _mediumWeight,
      ),
    );
    final caption = Text(
      row.shareLabel,
      style: TextStyle(fontSize: _rowCaptionSize, color: colors.subtext),
    );
    final labels = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [title, caption],
    );
    final amountStyle = AmountStyle.of(context, kind: kind);
    final amount = Text(
      formatSignedMoney(row.total, kind: kind, symbol: false),
      style: context.text.row.copyWith(color: amountStyle.color),
    );
    final content = Row(
      children: [
        marker,
        const SizedBox(width: _rowGap),
        Expanded(child: labels),
        const SizedBox(width: _rowGap),
        amount,
      ],
    );
    final padded = Padding(padding: _rowPadding, child: content);
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.edge, width: _borderWidth),
        ),
      ),
      child: padded,
    );
    return InkWell(onTap: () => onSelect(row.scope), child: decorated);
  }
}
