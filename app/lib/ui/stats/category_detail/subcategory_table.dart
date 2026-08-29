import 'package:decimal/decimal.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/category_detail/category_scope.dart';

const _directSymbol = 'radio_button_checked';

class _SubcategoryRowData {
  const _SubcategoryRowData({
    required this.scope,
    required this.name,
    required this.symbolName,
    required this.color,
    required this.amount,
  });

  final CategoryScope scope;
  final String name;
  final String symbolName;
  final Color color;
  final Decimal amount;
}

class SubcategoryTable extends StatelessWidget {
  const SubcategoryTable({
    super.key,
    required this.mainCategory,
    required this.mainTotal,
    required this.children,
    required this.childTotals,
    required this.directTotal,
    required this.scope,
    required this.onSelectScope,
  });

  final TransactionCategory? mainCategory;
  final Decimal mainTotal;
  final List<TransactionCategory> children;
  final Map<String, Decimal> childTotals;
  final Decimal directTotal;
  final CategoryScope scope;
  final void Function(CategoryScope scope) onSelectScope;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final category in children)
        _SubcategoryRowData(
          scope: SubScope(category.id),
          name: category.name,
          symbolName: category.symbol,
          color: parseColorHex(category.colorHex),
          amount: childTotals[category.id] ?? Decimal.zero,
        ),
      if (directTotal > Decimal.zero)
        _SubcategoryRowData(
          scope: const DirectScope(),
          name: 'Direct',
          symbolName: _directSymbol,
          color: mainCategory == null
              ? colorHexFallback
              : parseColorHex(mainCategory!.colorHex),
          amount: directTotal,
        ),
    ];
    rows.sort((a, b) => b.amount.compareTo(a.amount));

    return Column(
      children: [
        const Divider(height: 1),
        _SubcategoryRow(
          name: 'All ${mainCategory?.name ?? ''}',
          symbolName: mainCategory?.symbol ?? 'help_outline',
          color: mainCategory == null
              ? colorHexFallback
              : parseColorHex(mainCategory!.colorHex),
          amount: mainTotal,
          fraction: Decimal.one,
          selected: scope is AllScope,
          onTap: () => onSelectScope(const AllScope()),
        ),
        for (final row in rows)
          _SubcategoryRow(
            name: row.name,
            symbolName: row.symbolName,
            color: row.color,
            amount: row.amount,
            fraction: mainTotal == Decimal.zero
                ? Decimal.zero
                : (row.amount / mainTotal).toDecimal(
                    scaleOnInfinitePrecision: 4,
                  ),
            selected: row.scope == scope,
            onTap: () => onSelectScope(row.scope),
          ),
      ],
    );
  }
}

class _SubcategoryRow extends StatelessWidget {
  const _SubcategoryRow({
    required this.name,
    required this.symbolName,
    required this.color,
    required this.amount,
    required this.fraction,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String symbolName;
  final Color color;
  final Decimal amount;
  final Decimal fraction;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = selected
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
        : Colors.transparent;

    return Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _SubcategoryRowContent(
            name: name,
            symbolName: symbolName,
            color: color,
            amount: amount,
            fraction: fraction,
            selected: selected,
            theme: theme,
          ),
        ),
      ),
    );
  }
}

class _SubcategoryRowContent extends StatelessWidget {
  const _SubcategoryRowContent({
    required this.name,
    required this.symbolName,
    required this.color,
    required this.amount,
    required this.fraction,
    required this.selected,
    required this.theme,
  });

  final String name;
  final String symbolName;
  final Color color;
  final Decimal amount;
  final Decimal fraction;
  final bool selected;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CategoryIcon(symbolName: symbolName, color: color, size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          formatPercent(fraction.toDouble()),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          formatCurrency(amount),
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
