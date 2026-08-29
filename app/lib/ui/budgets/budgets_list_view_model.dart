import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail_view_model.dart';
import 'package:spendwise/ui/common/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/step_emitting.dart';

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

class BudgetsListViewState
    implements HasStep<BudgetsListViewState, BudgetsStep> {
  const BudgetsListViewState({
    required this.ledgerState,
    required this.items,
    required this.budgets,
    this.step,
  });

  final LedgerState ledgerState;
  final List<AnalysisItem> items;
  final List<Budget> budgets;
  @override
  final BudgetsStep? step;

  bool isSubcategoryBudget(Budget budget) =>
      budgetSortKey(budget, ledgerState).$2;

  BudgetsListViewState copyWith({
    LedgerState? ledgerState,
    List<AnalysisItem>? items,
    List<Budget>? budgets,
    BudgetsStep? Function()? step,
  }) {
    return BudgetsListViewState(
      ledgerState: ledgerState ?? this.ledgerState,
      items: items ?? this.items,
      budgets: budgets ?? this.budgets,
      step: step == null ? this.step : step(),
    );
  }

  @override
  BudgetsListViewState withStep(BudgetsStep? Function() step) =>
      copyWith(step: step);
}

abstract class BudgetsListViewModel {
  void requestBudgetDetail(String budgetID);
  void requestNewBudget();

  /// Deletes without asking again: [SwipeToDeleteRow] already confirmed.
  void deleteBudget(String id);
  void clearStep();
}

class BudgetsListNotifier extends AsyncNotifier<BudgetsListViewState>
    with
        LedgerBackedNotifier<BudgetsListViewState>,
        StepEmitting<BudgetsListViewState, BudgetsStep>
    implements BudgetsListViewModel {
  // read, not watch: this notifier already tracks the cache through its own
  // addListener/_onChanged wiring below, so watching it too would rebuild
  // this provider on every cache refresh, which would call refresh() again
  // and loop.
  AnalysisCache get _cache => ref.read(analysisCacheProvider);

  BudgetsStep? _step;

  // Captured once instead of read through the ledger getter (which watches):
  // _onChanged runs outside build(), and ref.watch from there corrupts this
  // provider's state instead of throwing, so _buildState must never reach
  // the getter either, since it also runs from inside _onChanged.
  late Ledger _ledger;

  @override
  Future<BudgetsListViewState> build() async {
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
    return _buildState();
  }

  void _onChanged() {
    unawaited(_cache.refresh(_ledger.state));
    state = AsyncData(_buildState(step: _step));
  }

  BudgetsListViewState _buildState({BudgetsStep? step}) {
    final ledgerState = _ledger.state;
    return BudgetsListViewState(
      ledgerState: ledgerState,
      items: _cache.items,
      budgets: sortedBudgets(ledgerState),
      step: step,
    );
  }

  @override
  void requestBudgetDetail(String budgetID) {
    _step = BudgetDetailRequested(budgetID);
    emitStep(BudgetDetailRequested(budgetID));
  }

  @override
  void requestNewBudget() {
    _step = BudgetFormRequested();
    emitStep(BudgetFormRequested());
  }

  @override
  void deleteBudget(String id) => ledger.deleteBudget(id);

  @override
  void clearStep() {
    _step = null;
    super.clearStep();
  }
}

final budgetsListViewModelProvider =
    AsyncNotifierProvider<BudgetsListNotifier, BudgetsListViewState>(
      BudgetsListNotifier.new,
    );
