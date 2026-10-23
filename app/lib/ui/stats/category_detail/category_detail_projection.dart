import 'package:decimal/decimal.dart';
import 'package:domain/domain.dart';

import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/breakdowns/analysis_category_scope.dart';
import 'package:spendwise/ledger/analysis/category_detail/category_detail.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_args.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_body.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_intent.dart';
import 'package:spendwise/ui/stats/category_detail/category_scope.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/transactions/daily_list/day_sections.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

const _shareDigits = 1;
const _shareScale = 8;
const _entryDateSeparator = ' / ';
final _percentFactor = Decimal.fromInt(100);

class CategoryDetailViewState {
  const CategoryDetailViewState({
    required this.detailDate,
    required this.scope,
    required this.kind,
    required this.isYearRange,
    required this.subtitle,
    required this.body,
    this.trendContext,
  });

  final DateTime detailDate;
  final CategoryScope scope;
  final CategoryKind kind;
  final bool isYearRange;
  final String subtitle;
  final CategoryDetailBody body;
  final TrendsContext? trendContext;
}

AnalysisCategoryScope categoryDetailAnalysisScope(CategoryScope scope) {
  return switch (scope) {
    AllScope() => const AllCategoryScope(),
    DirectScope() => const DirectCategoryScope(),
    SubScope(:final subID) =>
      subID == null ? const AllCategoryScope() : SubCategoryScope(subID),
  };
}

CategoryScope _presentationScope(AnalysisCategoryScope scope) {
  return switch (scope) {
    AllCategoryScope() => const AllScope(),
    DirectCategoryScope() => const DirectScope(),
    SubCategoryScope(:final subID) => SubScope(subID),
  };
}

CategoryDetailViewState categoryDetailUnreadyState(
  CategoryDetailArgs args,
  CategoryScope scope, {
  CategoryDetailBody body = const CategoryDetailLoadingBody(),
}) {
  final date = args.isYearRange
      ? DateTime.utc(args.initialDate.year)
      : DateTime.utc(args.initialDate.year, args.initialDate.month);
  return CategoryDetailViewState(
    detailDate: date,
    scope: scope,
    kind: args.kind,
    isYearRange: args.isYearRange,
    subtitle: args.isYearRange
        ? formatYearLabel(date)
        : formatMonthNameYear(date),
    body: body,
  );
}

CategoryDetailViewState projectCategoryDetail({
  required AnalysisQueryResult<CategoryDetailPeriod> result,
  required int ledgerRevision,
  required LedgerState ledgerState,
  required CategoryDetailArgs args,
  CategoryScope scope = const AllScope(),
}) {
  if (result.state == AnalysisQueryState.failed) {
    return categoryDetailUnreadyState(
      args,
      scope,
      body: const CategoryDetailErrorBody(),
    );
  }
  final period = result.value;
  if (result.state != AnalysisQueryState.ready ||
      period == null ||
      result.sourceRevision != ledgerRevision) {
    return categoryDetailUnreadyState(args, scope);
  }
  final effectiveScope = _presentationScope(period.scope);
  final base = categoryDetailUnreadyState(args, effectiveScope);
  final body = _readyBody(period, ledgerState, ledgerRevision);
  return CategoryDetailViewState(
    detailDate: base.detailDate,
    scope: effectiveScope,
    kind: args.kind,
    isYearRange: args.isYearRange,
    subtitle: base.subtitle,
    body: body,
  );
}

CategoryDetailViewState projectCategoryDetailWithTrend({
  required AnalysisQueryResult<CategoryDetailPeriod> periodResult,
  required AnalysisQueryResult<CategoryDetailSpread> spreadResult,
  required int ledgerRevision,
  required LedgerState ledgerState,
  required CategoryDetailArgs args,
  required CategoryDetailIntent intent,
  required TrendsContext trendContext,
  required TrendsBasis basis,
  required DateTime today,
}) {
  final base = projectCategoryDetail(
    result: periodResult,
    ledgerRevision: ledgerRevision,
    ledgerState: ledgerState,
    args: args,
    scope: intent.scope,
  );
  if (base.body is! CategoryDetailReadyBody) {
    return _withTrendContext(base, trendContext);
  }
  if (spreadResult.state == AnalysisQueryState.failed) {
    return _unreadyWithScope(
      args,
      base.scope,
      trendContext,
      const CategoryDetailErrorBody(),
    );
  }
  final spread = spreadResult.value;
  if (spreadResult.state != AnalysisQueryState.ready ||
      spread == null ||
      spreadResult.sourceRevision != ledgerRevision ||
      spread.today != today) {
    return _unreadyWithScope(args, base.scope, trendContext);
  }
  final period = periodResult.value!;
  final trend = _trendBody(
    spread: spread,
    period: period,
    state: ledgerState,
    args: args,
    intent: intent,
    basis: basis,
    context: trendContext,
  );
  return CategoryDetailViewState(
    detailDate: base.detailDate,
    scope: base.scope,
    kind: base.kind,
    isYearRange: base.isYearRange,
    subtitle: base.subtitle,
    body: _readyBody(period, ledgerState, ledgerRevision, trend: trend),
    trendContext: trendContext,
  );
}

CategoryDetailViewState _withTrendContext(
  CategoryDetailViewState state,
  TrendsContext context,
) {
  return CategoryDetailViewState(
    detailDate: state.detailDate,
    scope: state.scope,
    kind: state.kind,
    isYearRange: state.isYearRange,
    subtitle: state.subtitle,
    body: state.body,
    trendContext: context,
  );
}

CategoryDetailViewState _unreadyWithScope(
  CategoryDetailArgs args,
  CategoryScope scope,
  TrendsContext context, [
  CategoryDetailBody body = const CategoryDetailLoadingBody(),
]) {
  final unready = categoryDetailUnreadyState(args, scope, body: body);
  return _withTrendContext(unready, context);
}

CategoryDetailTrendBody _trendBody({
  required CategoryDetailSpread spread,
  required CategoryDetailPeriod period,
  required LedgerState state,
  required CategoryDetailArgs args,
  required CategoryDetailIntent intent,
  required TrendsBasis basis,
  required TrendsContext context,
}) {
  final mode = intent.trend.mode;
  final selectedPeriod = mode == TrendsMode.month
      ? monthStartOf(basis.selected)
      : DateTime.utc(basis.selected);
  final incoming = mode == TrendsMode.month
      ? monthSerial(args.initialDate)
      : args.initialDate.year;
  final selectedIndex = _slotIndex(
    spread.slots,
    intent.hasExplicitSelection ? basis.selected : incoming,
    mode,
  );
  final bars = spread.slots.map((slot) {
    final label = mode == TrendsMode.month
        ? formatMonthInitial(slot.period)
        : formatYearLabel(slot.period);
    final semanticLabel = mode == TrendsMode.month
        ? formatMonthNameYear(slot.period)
        : formatYearLabel(slot.period);
    return TrendsBar(
      label: label,
      semanticLabel: semanticLabel,
      value: slot.total.toDouble(),
    );
  }).toList();
  final periodRow = _trendPeriodRow(spread.slots, mode, basis, context);
  final selection = intent.hasExplicitSelection && spread.selection != null
      ? _trendSelection(
          period: selectedPeriod,
          mode: mode,
          categoryPeriod: period,
          selection: spread.selection!,
          scope: _presentationScope(period.scope),
          state: state,
        )
      : null;
  return CategoryDetailTrendBody(
    mode: mode,
    period: periodRow,
    bars: List.unmodifiable(bars),
    selectedIndex: selectedIndex,
    selection: selection,
  );
}

int _slotIndex(List<CategoryDetailSlot> slots, int selected, TrendsMode mode) {
  final target = mode == TrendsMode.month
      ? monthStartOf(selected)
      : DateTime.utc(selected);
  return slots.indexWhere((slot) => slot.period == target);
}

TrendsPeriodRow _trendPeriodRow(
  List<CategoryDetailSlot> slots,
  TrendsMode mode,
  TrendsBasis basis,
  TrendsContext context,
) {
  final first = slots.first.period;
  final last = slots.last.period;
  final startLabel = mode == TrendsMode.month
      ? formatMonthLabel(first)
      : formatYearLabel(first);
  final endLabel = mode == TrendsMode.month
      ? formatMonthLabel(last)
      : formatYearLabel(last);
  final grid = context.grid(mode);
  return TrendsPeriodRow(
    rangeLabel: '$startLabel - $endLabel',
    previousEnabled: grid.canPage(basis.end, -1),
    nextEnabled: grid.canPage(basis.end, 1),
  );
}

CategoryDetailTrendSelection _trendSelection({
  required DateTime period,
  required TrendsMode mode,
  required CategoryDetailPeriod categoryPeriod,
  required CategoryDetailSelection selection,
  required CategoryScope scope,
  required LedgerState state,
}) {
  final title = mode == TrendsMode.month
      ? formatMonthNameYear(period)
      : formatYearLabel(period);
  final scopeName = _scopeName(categoryPeriod, scope, state);
  final amountKind = categoryPeriod.kind == CategoryKind.income
      ? AmountKind.income
      : AmountKind.expense;
  final headline = TrendsHeadline(
    title: title,
    sublabel: scopeName,
    amountKind: amountKind,
    amount: formatSignedMoney(selection.total, kind: amountKind),
  );
  final rows = <TransactionRow>[];
  for (final id in selection.entryIDs) {
    final entry = state.entries[id];
    if (entry == null) continue;
    rows.add(
      _entryRow(
        entry,
        state,
        categoryPeriod.mainID,
        categoryPeriod.mainCategory?.name ?? 'Uncategorized',
        dated: true,
      ),
    );
  }
  return CategoryDetailTrendSelection(headline: headline, rows: rows);
}

String _scopeName(
  CategoryDetailPeriod period,
  CategoryScope scope,
  LedgerState state,
) {
  return switch (scope) {
    AllScope() || DirectScope() => period.mainCategory?.name ?? 'Uncategorized',
    SubScope(:final subID) => state.categories[subID]?.name ?? 'Uncategorized',
  };
}

CategoryDetailReadyBody _readyBody(
  CategoryDetailPeriod period,
  LedgerState state,
  int revision, {
  CategoryDetailTrendBody? trend,
}) {
  final title = period.mainCategory?.name ?? 'Uncategorized';
  final children = period.children.toList();
  children.sort((a, b) => _compareChildren(a, b, period));
  final rows = children
      .map((child) => _childRow(child, period, title))
      .toList();
  if (period.totals.directTotal > Decimal.zero) {
    rows.add(_directRow(period, title));
  }
  rows.sort(_compareRows);
  final sections = _entrySections(period, state, title);
  return CategoryDetailReadyBody(
    sourceRevision: revision,
    mainCategory: period.mainCategory,
    title: title,
    amountKind: period.kind == CategoryKind.income
        ? AmountKind.income
        : AmountKind.expense,
    children: children,
    totals: period.totals,
    chips: _chips(period, children, title),
    breakdown: rows,
    sections: sections,
    firstRecord: period.firstRecord,
    showSubcategories: children.isNotEmpty && period.scope is AllCategoryScope,
    trend: trend,
  );
}

int _compareChildren(
  TransactionCategory a,
  TransactionCategory b,
  CategoryDetailPeriod period,
) {
  final amounts = period.totals.childTotals;
  final byAmount = (amounts[b.id] ?? Decimal.zero).compareTo(
    amounts[a.id] ?? Decimal.zero,
  );
  if (byAmount != 0) return byAmount;
  final byName = a.name.compareTo(b.name);
  return byName != 0 ? byName : a.id.compareTo(b.id);
}

int _compareRows(CategoryDetailBreakdownRow a, CategoryDetailBreakdownRow b) {
  final byAmount = b.total.compareTo(a.total);
  if (byAmount != 0) return byAmount;
  final byName = a.label.compareTo(b.label);
  return byName != 0 ? byName : a.id.compareTo(b.id);
}

String _share(Decimal total, Decimal parent, String name) {
  final share = parent == Decimal.zero
      ? Decimal.zero
      : (total * _percentFactor / parent).toDecimal(
          scaleOnInfinitePrecision: _shareScale,
        );
  return '${share.toStringAsFixed(_shareDigits)}% of $name';
}

CategoryDetailBreakdownRow _childRow(
  TransactionCategory child,
  CategoryDetailPeriod period,
  String title,
) {
  final total = period.totals.childTotals[child.id] ?? Decimal.zero;
  return CategoryDetailBreakdownRow(
    id: child.id,
    label: child.name,
    scope: SubScope(child.id),
    total: total,
    shareLabel: _share(total, period.totals.mainTotal, title),
    savedHex: child.colorHex,
  );
}

CategoryDetailBreakdownRow _directRow(
  CategoryDetailPeriod period,
  String title,
) {
  final total = period.totals.directTotal;
  return CategoryDetailBreakdownRow(
    id: period.mainID,
    label: 'Direct to $title',
    scope: const DirectScope(),
    total: total,
    shareLabel: _share(total, period.totals.mainTotal, title),
    savedHex: period.mainCategory?.colorHex,
  );
}

List<CategoryDetailScopeChip> _chips(
  CategoryDetailPeriod period,
  List<TransactionCategory> children,
  String title,
) {
  if (children.isEmpty) return const [];
  final scope = period.scope;
  final chips = <CategoryDetailScopeChip>[
    CategoryDetailScopeChip(
      label: 'All $title',
      scope: const AllScope(),
      selected: scope is AllCategoryScope,
    ),
  ];
  for (final child in children) {
    chips.add(
      CategoryDetailScopeChip(
        label: child.name,
        scope: SubScope(child.id),
        selected: scope is SubCategoryScope && scope.subID == child.id,
      ),
    );
  }
  chips.add(
    CategoryDetailScopeChip(
      label: 'Direct to $title',
      scope: const DirectScope(),
      selected: scope is DirectCategoryScope,
    ),
  );
  return List.unmodifiable(chips);
}

List<DaySection> _entrySections(
  CategoryDetailPeriod period,
  LedgerState state,
  String title,
) {
  final byDay = <DateTime, List<TransactionRow>>{};
  final income = <DateTime, Decimal>{};
  final expenses = <DateTime, Decimal>{};
  for (final id in period.entryIDs) {
    final entry = state.entries[id];
    if (entry == null) continue;
    final day = startOfDayUtc(entry.date);
    final row = _entryRow(entry, state, period.mainID, title);
    (byDay[day] ??= []).add(row);
    final totals = row.amountKind == AmountKind.income ? income : expenses;
    totals[day] = (totals[day] ?? Decimal.zero) + entry.amount.abs();
  }
  return List.unmodifiable(
    byDay.entries.map((day) {
      return DaySection(
        date: day.key,
        rows: List.unmodifiable(day.value),
        income: income[day.key] ?? Decimal.zero,
        expenses: expenses[day.key] ?? Decimal.zero,
      );
    }),
  );
}

TransactionRow _entryRow(
  Entry entry,
  LedgerState state,
  String mainID,
  String title, {
  bool dated = false,
}) {
  final base = transactionRow(entry, state);
  final category = state.categories[entry.categoryID];
  final categoryLabel = entry.categoryID == mainID
      ? 'Direct to $title'
      : category?.name ?? 'Uncategorized';
  final categoryAccount = '$categoryLabel / ${base.accountLine}';
  final accountLine = dated
      ? '${formatDayMonthShort(entry.date)}$_entryDateSeparator$categoryAccount'
      : categoryAccount;
  return TransactionRow(
    id: entry.id,
    title: entry.name,
    note: '',
    accountLine: accountLine,
    symbolName: base.symbolName,
    color: base.color,
    amount: base.amount,
    amountKind: base.amountKind,
  );
}
