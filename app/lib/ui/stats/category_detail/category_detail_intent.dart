import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart' show immutable;

import 'package:spendwise/ui/stats/category_detail/category_detail_args.dart';
import 'package:spendwise/ui/stats/category_detail/category_scope.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';

@immutable
class CategoryDetailIntent {
  const CategoryDetailIntent({
    required this.scope,
    required this.trend,
    required this.hasExplicitSelection,
  });

  factory CategoryDetailIntent.initial(CategoryDetailArgs args) {
    final period = args.isYearRange
        ? DateTime.utc(args.initialDate.year)
        : DateTime.utc(args.initialDate.year, args.initialDate.month);
    final mode = args.isYearRange ? TrendsMode.year : TrendsMode.month;
    final selected = args.isYearRange ? period.year : monthSerial(period);
    return CategoryDetailIntent(
      scope: const AllScope(),
      trend: TrendsIntent(
        kind: args.kind == CategoryKind.income
            ? TrendsKind.income
            : TrendsKind.expense,
        mode: mode,
        spreadEnd: selected,
        selected: selected,
        rememberedMonth: period.month,
        followsCurrent: false,
      ),
      hasExplicitSelection: false,
    );
  }

  final CategoryScope scope;
  final TrendsIntent trend;
  final bool hasExplicitSelection;

  CategoryDetailIntent withScope(CategoryScope next) {
    if (_sameScope(scope, next)) return this;
    return CategoryDetailIntent(
      scope: next,
      trend: trend,
      hasExplicitSelection: hasExplicitSelection,
    );
  }

  CategoryDetailIntent withMode(TrendsMode mode, TrendsContext context) {
    final next = trend.withMode(mode, context);
    if (identical(next, trend)) return this;
    return CategoryDetailIntent(
      scope: scope,
      trend: next,
      hasExplicitSelection: false,
    );
  }

  CategoryDetailIntent previousPage(TrendsContext context) =>
      _page(trend.pagedPrevious(context));

  CategoryDetailIntent nextPage(TrendsContext context) =>
      _page(trend.pagedNext(context));

  CategoryDetailIntent selectSlot(int index, TrendsContext context) {
    final next = trend.withSlot(index, context);
    if (identical(next, trend)) return this;
    return CategoryDetailIntent(
      scope: scope,
      trend: next,
      hasExplicitSelection: true,
    );
  }

  CategoryDetailIntent _page(TrendsIntent next) {
    if (identical(next, trend)) return this;
    return CategoryDetailIntent(
      scope: scope,
      trend: next,
      hasExplicitSelection: false,
    );
  }

  static bool _sameScope(CategoryScope first, CategoryScope second) {
    return switch ((first, second)) {
      (AllScope(), AllScope()) || (DirectScope(), DirectScope()) => true,
      (SubScope(:final subID), SubScope(subID: final otherID)) =>
        subID == otherID,
      _ => false,
    };
  }
}
