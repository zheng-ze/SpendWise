import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/step_emitting.dart';
import 'package:spendwise/ui/stats/budget_spend.dart';
import 'package:spendwise/ui/stats/stats_window.dart';
import 'package:spendwise/ui/stats/trend.dart';

sealed class BudgetDetailStep {}

class BudgetLimitEditRequested extends BudgetDetailStep {}

/// A month series aligned with [BudgetDetailViewState.months], one value per
/// month, built by [forMonth] from that month's [YearMonth].
List<T> monthSeries<T>(
  List<DateTime> months,
  T Function(YearMonth month) forMonth,
) => [for (final month in months) forMonth(YearMonth(month.year, month.month))];

/// The chart's Y axis extends 15% past the largest spend or limit bar, so the
/// tallest bar never touches the chart's top edge.
double chartMaxY(List<Decimal> spend, List<Decimal> limit) {
  final maxAmount = [
    ...spend,
    ...limit,
  ].fold(Decimal.zero, (max, amount) => amount > max ? amount : max);
  return maxAmount > Decimal.one ? maxAmount.toDouble() * 1.15 : 1.0;
}

class BudgetDetailViewState
    implements HasStep<BudgetDetailViewState, BudgetDetailStep> {
  const BudgetDetailViewState({
    required this.budget,
    required this.ledgerState,
    required this.items,
    required this.displayedYear,
    required this.selectedMonth,
    required this.months,
    this.step,
  });

  final Budget? budget;
  final LedgerState ledgerState;
  final List<AnalysisItem> items;
  final DateTime displayedYear;
  final DateTime selectedMonth;
  final List<DateTime> months;
  @override
  final BudgetDetailStep? step;

  YearMonth get selectedYearMonth =>
      YearMonth(selectedMonth.year, selectedMonth.month);

  List<Decimal> get spendSeries {
    final currentBudget = budget;
    if (currentBudget == null) return const [];
    return monthSeries(
      months,
      (month) => budgetSpend(currentBudget, month, items, ledgerState),
    );
  }

  List<Decimal> get limitSeries {
    final currentBudget = budget;
    if (currentBudget == null) return const [];
    return monthSeries(months, (month) => effectiveLimit(currentBudget, month));
  }

  double get chartMaxYValue => chartMaxY(spendSeries, limitSeries);

  DateRange get selectedMonthWindow => monthWindow(selectedMonth);

  Set<String>? get scopedBucketIDs {
    final currentBudget = budget;
    if (currentBudget == null) return const {};
    return budgetBucketIDs(currentBudget, ledgerState);
  }

  String get title {
    final categoryID = budget?.categoryID;
    if (categoryID == null) return 'Overall';
    return ledgerState.categories[categoryID]?.name ?? '(category deleted)';
  }

  BudgetDetailViewState copyWith({
    Budget? budget,
    LedgerState? ledgerState,
    List<AnalysisItem>? items,
    DateTime? displayedYear,
    DateTime? selectedMonth,
    List<DateTime>? months,
    BudgetDetailStep? Function()? step,
  }) {
    return BudgetDetailViewState(
      budget: budget ?? this.budget,
      ledgerState: ledgerState ?? this.ledgerState,
      items: items ?? this.items,
      displayedYear: displayedYear ?? this.displayedYear,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      months: months ?? this.months,
      step: step == null ? this.step : step(),
    );
  }

  @override
  BudgetDetailViewState withStep(BudgetDetailStep? Function() step) =>
      copyWith(step: step);
}

abstract class BudgetDetailViewModel {
  void selectMonth(DateTime month);
  void changeYear(DateTime year);
  void requestLimitEdit();
  void clearStep();
}

class BudgetDetailNotifier extends AsyncNotifier<BudgetDetailViewState>
    with LedgerBackedNotifier<BudgetDetailViewState>
    implements BudgetDetailViewModel {
  BudgetDetailNotifier(this._budgetID);

  final String _budgetID;

  // read, not watch: this notifier already tracks the cache through its own
  // addListener/_onChanged wiring below, so watching it too would rebuild
  // this provider on every cache refresh, which would call refresh() again
  // and loop.
  AnalysisCache get _cache => ref.read(analysisCacheProvider);

  // Kept outside state.value so a cache notification arriving before
  // build()'s own return has been installed (the cache's compute can finish
  // and call back before that happens) still has values to rebuild from,
  // instead of being dropped on the floor.
  late DateTime _displayedYear;
  late DateTime _selectedMonth;
  BudgetDetailStep? _step;

  // Captured once instead of read through the ledger getter (which watches):
  // _onChanged runs outside build(), and ref.watch from there corrupts this
  // provider's state instead of throwing, so _buildState must never reach
  // the getter either, since it also runs from inside _onChanged.
  late Ledger _ledger;

  @override
  Future<BudgetDetailViewState> build() async {
    final currentLedger = ledger;
    final cache = _cache;
    _ledger = currentLedger;
    currentLedger.addListener(_onChanged);
    cache.addListener(_onChanged);
    ref.onDispose(() => currentLedger.removeListener(_onChanged));
    ref.onDispose(() => cache.removeListener(_onChanged));

    // Set before the refresh below, since that refresh's own completion can
    // call _onChanged synchronously (through notifyListeners), and
    // _onChanged reads these fields.
    final now = startOfDayUtc(DateTime.now());
    _displayedYear = DateTime.utc(now.year);
    _selectedMonth = DateTime.utc(now.year, now.month);

    // Awaited so the state build() returns already has the cache's items,
    // rather than the empty pre-compute list: a later notifyListeners() from
    // this same refresh would otherwise race build()'s own return value and
    // could lose to it once Riverpod installs that return value as state.
    await cache.refresh(currentLedger.state);

    return _buildState(
      displayedYear: _displayedYear,
      selectedMonth: _selectedMonth,
    );
  }

  void _onChanged() {
    unawaited(_cache.refresh(_ledger.state));
    state = AsyncData(
      _buildState(
        displayedYear: _displayedYear,
        selectedMonth: _selectedMonth,
        step: _step,
      ),
    );
  }

  BudgetDetailViewState _buildState({
    required DateTime displayedYear,
    required DateTime selectedMonth,
    BudgetDetailStep? step,
  }) {
    final ledgerState = _ledger.state;
    return BudgetDetailViewState(
      budget: ledgerState.budgets[_budgetID],
      ledgerState: ledgerState,
      items: _cache.items,
      displayedYear: displayedYear,
      selectedMonth: selectedMonth,
      months: trendMonths(displayedYear, isYearRange: true),
      step: step,
    );
  }

  @override
  void selectMonth(DateTime month) {
    _selectedMonth = month;
    updateState(
      (s) => _buildState(displayedYear: s.displayedYear, selectedMonth: month),
    );
  }

  @override
  void changeYear(DateTime year) {
    final current = state.value;
    if (current == null) return;
    final newDisplayedYear = DateTime.utc(year.year);
    final newSelectedMonth = DateTime.utc(
      year.year,
      current.selectedMonth.month,
    );
    _displayedYear = newDisplayedYear;
    _selectedMonth = newSelectedMonth;
    updateState(
      (s) => _buildState(
        displayedYear: newDisplayedYear,
        selectedMonth: newSelectedMonth,
      ),
    );
  }

  @override
  void requestLimitEdit() {
    _step = BudgetLimitEditRequested();
    updateState((s) => s.copyWith(step: () => BudgetLimitEditRequested()));
  }

  @override
  void clearStep() {
    _step = null;
    updateState((s) => s.copyWith(step: () => null));
  }
}

final budgetDetailViewModelProvider =
    AsyncNotifierProvider.family<
      BudgetDetailNotifier,
      BudgetDetailViewState,
      String
    >(BudgetDetailNotifier.new);
