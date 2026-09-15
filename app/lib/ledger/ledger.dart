import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:sync/sync.dart';

import 'package:spendwise/ledger/event_bus.dart';

typedef PlanErrorHandler = void Function(List<PlanFailure> failures);

/// The sync row a decided change touches: accounts and pockets share the
/// money-sources table, and every other change maps to its own table's
/// collection.
SyncRowID _syncRowID(LedgerChange change) => switch (change) {
  UpsertAccount(:final account) => SyncRowID.of(
    SyncCollection.moneySources,
    account.id,
  ),
  UpsertPocket(:final pocket) => SyncRowID.of(
    SyncCollection.moneySources,
    pocket.id,
  ),
  UpsertCategory(:final category) => SyncRowID.of(
    SyncCollection.categories,
    category.id,
  ),
  UpsertEntry(:final entry) => SyncRowID.of(SyncCollection.entries, entry.id),
  UpsertPlan(:final plan) => SyncRowID.of(SyncCollection.plans, plan.id),
  UpsertBudget(:final budget) => SyncRowID.of(
    SyncCollection.budgets,
    budget.id,
  ),
  DeleteMoneySource(:final id) => SyncRowID.of(SyncCollection.moneySources, id),
  DeleteCategory(:final id) => SyncRowID.of(SyncCollection.categories, id),
  DeleteEntry(:final id) => SyncRowID.of(SyncCollection.entries, id),
  DeletePlan(:final id) => SyncRowID.of(SyncCollection.plans, id),
  DeleteBudget(:final id) => SyncRowID.of(SyncCollection.budgets, id),
};

/// The only object allowed to hold a mutable [LedgerState], so no change can
/// reach storage or the screen without passing through [_mutate] (local
/// mutations) or [applySyncBatch] (decided remote batches) and being
/// announced on the bus.
class Ledger extends ChangeNotifier {
  Ledger({LedgerState? state, EventBus? bus})
    : _state = state ?? LedgerState(),
      bus = bus ?? EventBus();

  final LedgerState _state;

  final EventBus bus;

  /// Reported after resolution commits and publishes, never during it.
  PlanErrorHandler? onPlanError;

  LedgerState get state => _state;

  // A throw from the mutator leaves every later step unrun, so a rejected
  // mutation neither publishes nor notifies.
  List<LedgerChange> _mutate(List<LedgerChange> Function(LedgerState) mutator) {
    // Ahead of publish, or a torn-down collaborator throws first and hides this.
    assert(ChangeNotifier.debugAssertNotDisposed(this));

    final changes = mutator(_state);
    assert(() {
      _state.assertInvariants();
      return true;
    }());
    bus.publish(changes);
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

  /// Applies an already-decided remote batch: the coordinator owns
  /// classification and reconciliation, so this takes the decided [changes]
  /// plus the complete per-row [stamps] at face value.
  ///
  /// [stamps] must cover exactly the rows [changes] touches, no more and no
  /// less; anything else throws [ArgumentError] before anything is mutated.
  ///
  /// Copy-validates first: builds a candidate from the five live tables,
  /// applies [changes] to the candidate, and runs the structural invariants
  /// unconditionally, outside `assert` and without mutator clause 12
  /// lifecycle monotonicity, so a legitimate remote transition this device
  /// never observed still passes. Only then adopts the candidate into the
  /// live state (keeping the same [LedgerState] object), publishes one
  /// stamped publication, and notifies once.
  ///
  /// A validation failure throws before any of those happen, so the live
  /// tables, the bus, and the listeners are all untouched.
  List<LedgerChange> applySyncBatch(
    List<LedgerChange> changes,
    Map<SyncRowID, VersionVector> stamps,
  ) {
    assert(ChangeNotifier.debugAssertNotDisposed(this));

    final covered = <SyncRowID>{
      for (final change in changes) _syncRowID(change),
    };
    // Set == is identity, so compare by content: same size and mutual
    // containment.
    final stamped = stamps.keys.toSet();
    if (stamped.length != covered.length || !stamped.containsAll(covered)) {
      throw ArgumentError.value(
        stamps.keys.toList(),
        'stamps',
        'must cover exactly the rows the batch touches',
      );
    }

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
    bus.publish(changes, stamps: stamps);
    notifyListeners();
    return changes;
  }

  /// [now] must be a UTC instant. A device-local one would make occurrence
  /// identity vary by timezone.
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
