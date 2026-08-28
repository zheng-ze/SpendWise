import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/ledger_backed_notifier.dart';
import 'package:spendwise/ui/stats/slices.dart';

enum StatsTab { income, expense, budgets }

enum StatsRangeMode { month, year }

sealed class StatsStep {}

class CategoryDetailRequested extends StatsStep {
  CategoryDetailRequested({
    required this.mainID,
    required this.kind,
    required this.isYearRange,
    required this.initialDate,
  });

  final String mainID;
  final CategoryKind kind;
  final bool isYearRange;
  final DateTime initialDate;
}

class BudgetDetailRequested extends StatsStep {
  BudgetDetailRequested(this.budgetID);

  final String budgetID;
}

class BudgetFormRequested extends StatsStep {}

/// Groups a subcategory's budget under its parent's name, so the two sort
/// next to each other even when only the child carries a budget.
(String groupName, bool isSubcategory, String ownName) budgetSortKey(
  Budget budget,
  LedgerState state,
) {
  final categoryID = budget.categoryID;
  if (categoryID == null) return ('', false, '');
  final category = state.categories[categoryID];
  if (category == null) {
    return ('(category deleted)', false, '(category deleted)');
  }
  final parentID = category.parentID;
  if (parentID == null) return (category.name, false, category.name);
  final parentName = state.categories[parentID]?.name ?? category.name;
  return (parentName, true, category.name);
}

List<Budget> sortedBudgets(LedgerState state) {
  final budgets = state.budgets.values.toList()
    ..sort((a, b) {
      final aKey = budgetSortKey(a, state);
      final bKey = budgetSortKey(b, state);
      final groupCompare = aKey.$1.compareTo(bKey.$1);
      if (groupCompare != 0) return groupCompare;
      if (aKey.$2 != bKey.$2) return aKey.$2 ? 1 : -1;
      return aKey.$3.compareTo(bKey.$3);
    });
  return budgets;
}

class StatsRootViewState {
  const StatsRootViewState({
    required this.tab,
    required this.range,
    required this.ledgerState,
    required this.items,
    required this.budgets,
    this.step,
  });

  final StatsTab tab;
  final StatsRangeMode range;
  final LedgerState ledgerState;
  final List<AnalysisItem> items;
  final List<Budget> budgets;
  final StatsStep? step;

  bool isSubcategoryBudget(Budget budget) =>
      budgetSortKey(budget, ledgerState).$2;

  StatsRootViewState copyWith({
    StatsTab? tab,
    StatsRangeMode? range,
    LedgerState? ledgerState,
    List<AnalysisItem>? items,
    List<Budget>? budgets,
    StatsStep? Function()? step,
  }) {
    return StatsRootViewState(
      tab: tab ?? this.tab,
      range: range ?? this.range,
      ledgerState: ledgerState ?? this.ledgerState,
      items: items ?? this.items,
      budgets: budgets ?? this.budgets,
      step: step == null ? this.step : step(),
    );
  }
}

abstract class StatsRootViewModel {
  void setTab(StatsTab tab);
  void setRange(StatsRangeMode range);
  void requestCategoryDetail({
    required CategoryKind kind,
    required String mainID,
    required bool isYearRange,
    required DateTime initialDate,
  });
  void requestBudgetDetail(String budgetID);
  void requestNewBudget();

  /// Deletes without asking again: [SwipeToDeleteRow] already confirmed.
  void deleteBudget(String id);
  void clearStep();
}

class StatsRootNotifier extends AsyncNotifier<StatsRootViewState>
    with LedgerBackedNotifier<StatsRootViewState>
    implements StatsRootViewModel {
  // read, not watch: this notifier already tracks the cache through its own
  // addListener/_onChanged wiring below, so watching it too would rebuild
  // this provider on every cache refresh, which would call refresh() again
  // and loop.
  AnalysisCache get _cache => ref.read(analysisCacheProvider);

  // Kept outside state.value so a cache notification arriving before
  // build()'s own return has been installed (the cache's compute can finish
  // and call back before that happens) rebuilds from the user's actual
  // selection instead of resetting to these defaults.
  StatsTab _tab = StatsTab.expense;
  StatsRangeMode _range = StatsRangeMode.month;
  StatsStep? _step;

  // Captured once instead of read through the ledger getter (which watches):
  // _onChanged runs outside build(), and ref.watch from there corrupts this
  // provider's state instead of throwing, so _buildState must never reach
  // the getter either, since it also runs from inside _onChanged.
  late Ledger _ledger;

  @override
  Future<StatsRootViewState> build() async {
    final currentLedger = ledger;
    final cache = _cache;
    _ledger = currentLedger;
    currentLedger.addListener(_onChanged);
    cache.addListener(_onChanged);
    ref.onDispose(() => currentLedger.removeListener(_onChanged));
    ref.onDispose(() => cache.removeListener(_onChanged));
    // Awaited so the state build() returns already has the cache's items,
    // rather than the empty pre-compute list: a later notifyListeners() from
    // this same refresh would otherwise race build()'s own return value and
    // could lose to it once Riverpod installs that return value as state.
    await cache.refresh(currentLedger.state);
    return _buildState(tab: _tab, range: _range);
  }

  void _onChanged() {
    unawaited(_cache.refresh(_ledger.state));
    state = AsyncData(_buildState(tab: _tab, range: _range, step: _step));
  }

  StatsRootViewState _buildState({
    required StatsTab tab,
    required StatsRangeMode range,
    StatsStep? step,
  }) {
    final ledgerState = _ledger.state;
    return StatsRootViewState(
      tab: tab,
      range: range,
      ledgerState: ledgerState,
      items: _cache.items,
      budgets: sortedBudgets(ledgerState),
      step: step,
    );
  }

  @override
  void setTab(StatsTab tab) {
    _tab = tab;
    updateState((s) => s.copyWith(tab: tab));
  }

  @override
  void setRange(StatsRangeMode range) {
    _range = range;
    updateState((s) => s.copyWith(range: range));
  }

  @override
  void requestCategoryDetail({
    required CategoryKind kind,
    required String mainID,
    required bool isYearRange,
    required DateTime initialDate,
  }) => _emitStep(
    CategoryDetailRequested(
      mainID: mainID,
      kind: kind,
      isYearRange: isYearRange,
      initialDate: initialDate,
    ),
  );

  @override
  void requestBudgetDetail(String budgetID) =>
      _emitStep(BudgetDetailRequested(budgetID));

  @override
  void requestNewBudget() => _emitStep(BudgetFormRequested());

  @override
  void deleteBudget(String id) => ledger.deleteBudget(id);

  void _emitStep(StatsStep step) {
    _step = step;
    updateState((s) => s.copyWith(step: () => step));
  }

  @override
  void clearStep() {
    _step = null;
    updateState((s) => s.copyWith(step: () => null));
  }
}

final statsRootViewModelProvider =
    AsyncNotifierProvider<StatsRootNotifier, StatsRootViewState>(
      StatsRootNotifier.new,
    );

List<Slice> statsSlices(
  StatsRootViewState state,
  CategoryKind kind,
  DateRange window,
) => slices(state.items, kind, window, state.ledgerState);
