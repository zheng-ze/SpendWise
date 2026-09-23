import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:sync/sync.dart';

import 'package:spendwise/ledger/event_bus.dart';

typedef PlanErrorHandler = void Function(List<PlanFailure> failures);

class Ledger extends ChangeNotifier {
  Ledger({LedgerState? state, EventBus? bus})
    : _state = state ?? LedgerState(),
      bus = bus ?? EventBus();

  final LedgerState _state;

  final EventBus bus;

  PlanErrorHandler? onPlanError;

  LedgerState get state => _state;

  List<LedgerChange> _mutate(List<LedgerChange> Function(LedgerState) mutator) {
    assert(ChangeNotifier.debugAssertNotDisposed(this));

    final changes = mutator(_state);
    assert(() {
      _state.assertInvariants();
      return true;
    }());
    return _commit(changes);
  }

  List<LedgerChange> _commit(
    List<LedgerChange> changes, {
    Map<SyncRowID, VersionVector>? stamps,
  }) {
    bus.publish(changes, stamps: stamps);
    notifyListeners();
    return changes;
  }

  List<LedgerChange> addAccount(Account account) =>
      _mutate((state) => state.addAccount(account));

  List<LedgerChange> updateAccount(Account account) =>
      _mutate((state) => state.updateAccount(account));

  List<LedgerChange> deleteAccount(String rawID) =>
      _mutate((state) => state.deleteAccount(rawID));

  List<LedgerChange> restoreAccount(String rawID) =>
      _mutate((state) => state.restoreAccount(rawID));

  List<LedgerChange> purgeAccount(String rawID) =>
      _mutate((state) => state.purgeAccount(rawID));

  List<LedgerChange> addPocket(SubPocket pocket, String rawAccountID) =>
      _mutate((state) => state.addPocket(pocket, rawAccountID));

  List<LedgerChange> updatePocket(SubPocket pocket) =>
      _mutate((state) => state.updatePocket(pocket));

  List<LedgerChange> deletePocket(String rawID) =>
      _mutate((state) => state.deletePocket(rawID));

  List<LedgerChange> restorePocket(String rawID) =>
      _mutate((state) => state.restorePocket(rawID));

  List<LedgerChange> purgePocket(String rawID) =>
      _mutate((state) => state.purgePocket(rawID));

  List<LedgerChange> addEntry(Entry entry) =>
      _mutate((state) => state.addEntry(entry));

  List<LedgerChange> updateEntry(Entry entry) =>
      _mutate((state) => state.updateEntry(entry));

  List<LedgerChange> setOpeningBalance(
    Decimal amount,
    String rawHolderID, {
    DateTime? date,
  }) => _mutate(
    (state) => state.setOpeningBalance(amount, rawHolderID, date: date),
  );

  List<LedgerChange> deleteEntry(String rawID) =>
      _mutate((state) => state.deleteEntry(rawID));

  List<LedgerChange> addCategory(TransactionCategory category) =>
      _mutate((state) => state.addCategory(category));

  List<LedgerChange> updateCategory(TransactionCategory category) =>
      _mutate((state) => state.updateCategory(category));

  List<LedgerChange> deleteCategory(String rawID) =>
      _mutate((state) => state.deleteCategory(rawID));

  List<LedgerChange> restoreCategory(String rawID) =>
      _mutate((state) => state.restoreCategory(rawID));

  List<LedgerChange> purgeCategory(String rawID) =>
      _mutate((state) => state.purgeCategory(rawID));

  List<LedgerChange> addPlan(RecurringPlan plan) =>
      _mutate((state) => state.addPlan(plan));

  List<LedgerChange> updatePlan(RecurringPlan plan) =>
      _mutate((state) => state.updatePlan(plan));

  List<LedgerChange> deletePlan(String rawID) =>
      _mutate((state) => state.deletePlan(rawID));

  List<LedgerChange> addBudget(
    String? categoryID,
    Decimal initialAmount, {
    required DateTime now,
  }) =>
      _mutate((state) => state.addBudget(categoryID, initialAmount, now: now));

  List<LedgerChange> updateBudgetAmount(
    String rawBudgetID,
    Decimal newAmount,
    YearMonth effectiveFromMonth,
  ) => _mutate(
    (state) =>
        state.updateBudgetAmount(rawBudgetID, newAmount, effectiveFromMonth),
  );

  List<LedgerChange> setBudgetMonthOverride(
    String rawBudgetID,
    YearMonth month,
    Decimal value,
  ) => _mutate(
    (state) => state.setBudgetMonthOverride(rawBudgetID, month, value),
  );

  List<LedgerChange> deleteBudget(String rawID) =>
      _mutate((state) => state.deleteBudget(rawID));

  List<LedgerChange> applySyncBatch(
    List<LedgerChange> changes,
    Map<SyncRowID, VersionVector> stamps,
  ) {
    assert(ChangeNotifier.debugAssertNotDisposed(this));

    final candidate = LedgerState(
      moneySources: _state.moneySources,
      entries: _state.entries,
      categories: _state.categories,
      plans: _state.plans,
      budgets: _state.budgets,
    );
    candidate.apply(changes);
    candidate.assertInvariants();
    _state.adopt(candidate);
    return _commit(changes, stamps: stamps);
  }

  void resolvePlans(DateTime now) {
    late final PlanResolution resolution;
    _mutate((state) {
      resolution = state.resolvePlans(now);
      return resolution.changes;
    });

    if (resolution.failures.isEmpty) return;

    onPlanError?.call(resolution.failures);
  }

  List<TransactionCategory> categories(CategoryKind kind) =>
      _state.categoriesGroupedByParent(kind);
}
