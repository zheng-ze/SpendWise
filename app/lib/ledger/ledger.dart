import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/event_bus.dart';

typedef PlanErrorHandler = void Function(List<PlanFailure> failures);

/// The only object allowed to hold a mutable [LedgerState], so no change can
/// reach storage or the screen without passing through [_mutate] and being
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
