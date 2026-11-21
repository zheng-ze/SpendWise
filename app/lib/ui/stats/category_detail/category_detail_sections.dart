import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/lists/breakdown_row.dart';
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
      final savedHex = row.savedHex;
      return BreakdownRow(
        swatchColor: savedHex == null
            ? colorHexFallback
            : parseColorHex(savedHex),
        name: row.label,
        caption: row.shareLabel,
        amount: formatSignedMoney(row.total, kind: kind, symbol: false),
        amountKind: kind,
        divided: true,
        onTap: () => onSelect(row.scope),
      );
    }).toList();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    return Tray(title: 'Subcategories', child: content);
  }
}
