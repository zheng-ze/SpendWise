import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/breakdowns/category_breakdown.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/top_categories_view_model.dart';

// MARK: - Constants
const _soFarSuffix = ' so far';
const _topCategoriesRowLimit = 3;

// MARK: - Types
@immutable
class OverviewTopCategories {
  OverviewTopCategories({
    required this.caption,
    required List<OverviewTopCategoryRow> rows,
  }) : rows = List.unmodifiable(rows);

  final String caption;
  final List<OverviewTopCategoryRow> rows;

  @override
  bool operator ==(Object other) {
    return other is OverviewTopCategories &&
        other.caption == caption &&
        listEquals(other.rows, rows);
  }

  @override
  int get hashCode => Object.hash(caption, Object.hashAll(rows));
}

@immutable
class OverviewTopCategoryRow {
  const OverviewTopCategoryRow({
    required this.name,
    required this.symbolName,
    required this.savedHex,
    required this.amount,
    required this.barRatio,
  });

  final String name;
  final String symbolName;
  final String? savedHex;
  final String amount;
  final double barRatio;

  @override
  bool operator ==(Object other) {
    return other is OverviewTopCategoryRow &&
        other.name == name &&
        other.symbolName == symbolName &&
        other.savedHex == savedHex &&
        other.amount == amount &&
        other.barRatio == barRatio;
  }

  @override
  int get hashCode => Object.hash(name, symbolName, savedHex, amount, barRatio);
}

// MARK: - Top categories
OverviewTopCategories overviewTopCategories(
  PeriodBreakdown breakdown,
  LedgerState state,
  DateTime monthStart,
) {
  final shown = breakdown.rows.take(_topCategoriesRowLimit).toList();
  final topAmount = shown.isEmpty ? Decimal.zero : shown.first.amount;
  return OverviewTopCategories(
    caption: '${formatMonthName(monthStart)}$_soFarSuffix',
    rows: [for (final row in shown) _topCategoryRow(row, state, topAmount)],
  );
}

OverviewTopCategoryRow _topCategoryRow(
  BreakdownRow row,
  LedgerState state,
  Decimal topAmount,
) {
  final label = topCategoryLabel(row.bucketID, state.categories);
  return OverviewTopCategoryRow(
    name: label.name,
    symbolName: label.symbolName,
    savedHex: label.savedHex,
    amount: formatSignedMoney(-row.amount, symbol: false),
    barRatio: (row.amount / topAmount).toDouble(),
  );
}
