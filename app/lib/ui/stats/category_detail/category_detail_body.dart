import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart' show immutable;

import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/category_detail/category_scope.dart';
import 'package:spendwise/ui/stats/category_detail/category_totals.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/transactions/daily_list/day_sections.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

@immutable
sealed class CategoryDetailBody {
  const CategoryDetailBody();
}

class CategoryDetailLoadingBody extends CategoryDetailBody {
  const CategoryDetailLoadingBody();
}

class CategoryDetailErrorBody extends CategoryDetailBody {
  const CategoryDetailErrorBody();
}

class CategoryDetailReadyBody extends CategoryDetailBody {
  CategoryDetailReadyBody({
    required this.sourceRevision,
    required this.mainCategory,
    required this.title,
    required this.amountKind,
    required Iterable<TransactionCategory> children,
    required this.totals,
    required Iterable<CategoryDetailScopeChip> chips,
    required Iterable<CategoryDetailBreakdownRow> breakdown,
    required Iterable<DaySection> sections,
    required this.firstRecord,
    required this.showSubcategories,
    this.trend,
  }) : children = List.unmodifiable(children),
       chips = List.unmodifiable(chips),
       breakdown = List.unmodifiable(breakdown),
       sections = List.unmodifiable(sections);

  final int sourceRevision;
  final TransactionCategory? mainCategory;
  final String title;
  final AmountKind amountKind;
  final List<TransactionCategory> children;
  final CategoryTotals totals;
  final List<CategoryDetailScopeChip> chips;
  final List<CategoryDetailBreakdownRow> breakdown;
  final List<DaySection> sections;
  final DateTime? firstRecord;
  final bool showSubcategories;
  final CategoryDetailTrendBody? trend;
}

@immutable
class CategoryDetailTrendBody {
  const CategoryDetailTrendBody({
    required this.mode,
    required this.period,
    required this.bars,
    required this.selectedIndex,
    required this.selection,
  });

  final TrendsMode mode;
  final TrendsPeriodRow period;
  final List<TrendsBar> bars;
  final int selectedIndex;
  final CategoryDetailTrendSelection? selection;
}

@immutable
class CategoryDetailTrendSelection {
  CategoryDetailTrendSelection({
    required this.headline,
    required Iterable<TransactionRow> rows,
  }) : rows = List.unmodifiable(rows);

  final TrendsHeadline headline;
  final List<TransactionRow> rows;
}

@immutable
class CategoryDetailScopeChip {
  const CategoryDetailScopeChip({
    required this.label,
    required this.scope,
    required this.selected,
  });

  final String label;
  final CategoryScope scope;
  final bool selected;
}

@immutable
class CategoryDetailBreakdownRow {
  const CategoryDetailBreakdownRow({
    required this.id,
    required this.label,
    required this.scope,
    required this.total,
    required this.shareLabel,
    required this.savedHex,
  });

  final String id;
  final String label;
  final CategoryScope scope;
  final Decimal total;
  final String shareLabel;
  final String? savedHex;
}
