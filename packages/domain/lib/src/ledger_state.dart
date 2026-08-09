import 'dart:collection';

import 'package:decimal/decimal.dart';
import 'package:domain/src/account.dart';
import 'package:domain/src/account_type.dart';
import 'package:domain/src/entry.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/ledger_change.dart';
import 'package:domain/src/ledger_error.dart';
import 'package:domain/src/lifecycle_state.dart';
import 'package:domain/src/money_source.dart';
import 'package:domain/src/plan_failure.dart';
import 'package:domain/src/plan_resolution.dart';
import 'package:domain/src/recurring_plan.dart';
import 'package:domain/src/sub_pocket.dart';
import 'package:domain/src/transaction_category.dart';

part 'ledger_state_queries.dart';

class LedgerState {
  LedgerState({
    Map<String, MoneySource>? moneySources,
    Map<String, Entry>? entries,
    Map<String, TransactionCategory>? categories,
    Map<String, RecurringPlan>? plans,
  }) : _moneySources = {...?moneySources},
       _entries = {...?entries},
       _categories = {...?categories},
       _plans = {...?plans};

  /// Accounts and pockets share this table and one id space.
  final Map<String, MoneySource> _moneySources;

  final Map<String, Entry> _entries;
  final Map<String, TransactionCategory> _categories;
  final Map<String, RecurringPlan> _plans;

  /// Views, not the tables. Every write goes through a mutator, so the guards
  /// cannot be walked around and the invariants have a single choke point.
  Map<String, MoneySource> get moneySources =>
      UnmodifiableMapView(_moneySources);

  Map<String, Entry> get entries => UnmodifiableMapView(_entries);

  Map<String, TransactionCategory> get categories =>
      UnmodifiableMapView(_categories);

  Map<String, RecurringPlan> get plans => UnmodifiableMapView(_plans);

  List<LedgerChange> addAccount(Account account) {
    if (_moneySources.containsKey(account.id)) {
      throw IdCollision(account.id);
    }
    final stored = Account(
      id: account.id,
      name: account.name,
      type: account.type,
      incomingTransfersAsExpenses: account.incomingTransfersAsExpenses,
      includeInNetWorth: account.includeInNetWorth,
      statementDay: account.statementDay,
      lifecycle: account.lifecycle,
    );
    _moneySources[stored.id] = AccountSource(stored);
    return [UpsertAccount(stored)];
  }

  List<LedgerChange> updateAccount(Account account) {
    final existing = _moneySources[account.id]?.asAccount;
    if (existing == null) throw UnknownAccount(account.id);

    final stored = Account(
      id: account.id,
      name: account.name,
      type: account.type,
      subPocketIDs: existing.subPocketIDs,
      incomingTransfersAsExpenses: account.incomingTransfersAsExpenses,
      includeInNetWorth: account.includeInNetWorth,
      statementDay: account.type == AccountType.card
          ? account.statementDay
          : null,
      lifecycle: account.lifecycle,
    );
    _moneySources[stored.id] = AccountSource(stored);
    return [UpsertAccount(stored)];
  }

  List<LedgerChange> addPocket(SubPocket pocket, String rawAccountID) {
    final accountID = canonicalID(rawAccountID);
    final parent = _moneySources[accountID]?.asAccount;
    if (parent == null) throw UnknownAccount(accountID);
    if (_moneySources.containsKey(pocket.id)) throw IdCollision(pocket.id);

    final linked = parent.addSubPocket(pocket.id);
    // A new pocket may not start out more alive than the account taking it.
    final stored = parent.lifecycle.isAtLeastAsAliveAs(pocket.lifecycle)
        ? pocket
        : pocket.settingLifecycle(parent.lifecycle);
    _moneySources[stored.id] = PocketSource(stored);
    _moneySources[linked.id] = AccountSource(linked);
    return [UpsertPocket(stored), UpsertAccount(linked)];
  }

  List<LedgerChange> updatePocket(SubPocket pocket) {
    final existing = _moneySources[pocket.id]?.asPocket;
    if (existing == null) throw UnknownHolder(pocket.id);

    // The edit surface may not outrank the parent, so a lifecycle it is not
    // entitled to falls back to the stored one.
    final stored = _willOutliveParentAccount(pocket)
        ? pocket.settingLifecycle(existing.lifecycle)
        : pocket;
    _moneySources[stored.id] = PocketSource(stored);
    return [UpsertPocket(stored)];
  }

  /// True when the pocket outranks its parent, and when no account claims it.
  bool _willOutliveParentAccount(SubPocket pocket) {
    final parent = _owningAccount(pocket.id);
    if (parent == null) return true;

    return !parent.lifecycle.isAtLeastAsAliveAs(pocket.lifecycle);
  }

  List<LedgerChange> addEntry(Entry entry) {
    if (_entries.containsKey(entry.id)) throw IdCollision(entry.id);

    final stored = _validated(entry);
    _entries[stored.id] = stored;
    return [UpsertEntry(stored)];
  }

  List<LedgerChange> updateEntry(Entry entry) {
    final previous = _entries[entry.id];
    if (previous == null) throw UnknownEntry(entry.id);

    final stored = _validated(entry, previous: previous);
    _entries[stored.id] = stored;

    final droppedHolders = previous.holderIDs.difference(stored.holderIDs);
    final droppedCategory = previous.categoryID == stored.categoryID
        ? null
        : previous.categoryID;
    return [
      UpsertEntry(stored),
      ..._tombstoneDereferenced(droppedHolders, droppedCategory),
    ];
  }

  List<LedgerChange> setOpeningBalance(
    Decimal amount,
    String rawHolderID, {
    DateTime? date,
  }) {
    final holderID = canonicalID(rawHolderID);
    if (!_moneySources.containsKey(holderID)) throw UnknownHolder(holderID);
    if (amount == Decimal.zero) return [];

    return addEntry(
      Entry(
        date: date,
        amount: amount,
        name: 'Opening balance',
        sourceID: holderID,
        includeInAnalysis: false,
      ),
    );
  }

  List<LedgerChange> deleteEntry(String rawID) {
    final id = canonicalID(rawID);
    final removed = _entries.remove(id);
    if (removed == null) return [];

    return [
      DeleteEntry(id),
      ..._tombstoneDereferenced(removed.holderIDs, removed.categoryID),
    ];
  }

  List<LedgerChange> addCategory(TransactionCategory category) {
    if (_categories.containsKey(category.id)) throw IdCollision(category.id);

    _validateParent(category);
    _categories[category.id] = category;
    return [UpsertCategory(category)];
  }

  List<LedgerChange> updateCategory(TransactionCategory category) {
    final existing = _categories[category.id];
    if (existing == null) throw UnknownCategory(category.id);

    _validateParent(category);

    // The edit surface may not outrank the parent, so a lifecycle it is not
    // entitled to falls back to the stored one.
    final stored = _willOutliveParentCategory(category)
        ? category.settingLifecycle(existing.lifecycle)
        : category;
    _categories[stored.id] = stored;
    return [UpsertCategory(stored)];
  }

  /// The incoming parent is judged, so reparenting cannot smuggle a lifecycle
  /// past the new parent.
  bool _willOutliveParentCategory(TransactionCategory category) {
    final parentID = category.parentID;
    if (parentID == null) return false;

    final parent = _categories[parentID];
    if (parent == null) return false;

    return !parent.lifecycle.isAtLeastAsAliveAs(category.lifecycle);
  }

  List<LedgerChange> addPlan(RecurringPlan plan) {
    if (_plans.containsKey(plan.id)) throw IdCollision(plan.id);

    _validatePlan(plan);
    _plans[plan.id] = plan;
    return [UpsertPlan(plan)];
  }

  List<LedgerChange> updatePlan(RecurringPlan plan) {
    if (!_plans.containsKey(plan.id)) throw UnknownPlan(plan.id);

    _validatePlan(plan);
    _plans[plan.id] = plan;
    return [UpsertPlan(plan)];
  }

  List<LedgerChange> deletePlan(String rawID) {
    final id = canonicalID(rawID);
    if (_plans.remove(id) == null) return [];

    return [DeletePlan(id)];
  }

  void _validatePlan(RecurringPlan plan) {
    final template = plan.template;
    final source = _moneySources[template.sourceID];
    if (source == null) throw UnknownHolder(template.sourceID);
    if (!source.lifecycle.isActive) throw InactiveReference(template.sourceID);

    final destinationID = template.destinationID;
    if (destinationID != null) {
      final destination = _moneySources[destinationID];
      if (destination == null) throw UnknownHolder(destinationID);
      if (!destination.lifecycle.isActive) {
        throw InactiveReference(destinationID);
      }
    }

    final categoryID = template.categoryID;
    if (categoryID != null) {
      final category = _categories[categoryID];
      if (category == null) throw UnknownCategory(categoryID);
      final expected = template.expectedCategoryKind;
      if (expected == null) throw const CategoryKindMismatch();
      if (category.kind != expected) throw const CategoryKindMismatch();
      if (!category.lifecycle.isActive) throw InactiveReference(categoryID);
    }

    final endDate = plan.endDate;
    if (endDate != null && !plan.lastResolvedDate.isBefore(endDate)) {
      throw ExhaustedPlan(plan.id);
    }
  }

  PlanResolution resolvePlans(DateTime now) {
    final changes = <LedgerChange>[];
    final failures = <PlanFailure>[];

    // Sorted so the emitted change list is reproducible.
    final planIDs = _plans.keys.toList()..sort();
    for (final planID in planIDs) {
      final plan = _plans[planID]!;
      final due = plan.occurrences(after: plan.lastResolvedDate, upTo: now);

      for (final date in due) {
        final entry = plan.template.makeEntry(plan.id, date);
        if (_entries.containsKey(entry.id)) continue;

        try {
          final stored = _validated(entry);
          _entries[stored.id] = stored;
          changes.add(UpsertEntry(stored));
        } on LedgerError catch (error) {
          failures.add(
            PlanFailure(planID: plan.id, occurrence: date, error: error),
          );
        }
      }

      final advanced = plan.resolvedAt(now);
      if (advanced.isExhausted(asOf: now)) {
        _plans.remove(plan.id);
        changes.add(DeletePlan(plan.id));
      } else if (due.isNotEmpty) {
        _plans[plan.id] = advanced;
        changes.add(UpsertPlan(advanced));
      }
      // An idle plan is left alone: a stale cursor only gates past
      // occurrences, so replaying yields the same empty result.
    }

    return PlanResolution(changes: changes, failures: failures);
  }

  List<LedgerChange> deleteAccount(String rawID) {
    final id = canonicalID(rawID);
    final account = _moneySources[id]?.asAccount;
    if (account == null || !account.lifecycle.isActive) return [];

    final archived = account.settingLifecycle(LifecycleState.archived);
    _moneySources[id] = AccountSource(archived);
    final changes = <LedgerChange>[UpsertAccount(archived)];

    // Links are kept so restore can find the pockets again.
    for (final pocketID in archived.subPocketIDs) {
      final pocket = _moneySources[pocketID]?.asPocket;
      if (pocket == null || !pocket.lifecycle.isActive) continue;

      final archivedPocket = pocket.settingLifecycle(LifecycleState.archived);
      _moneySources[pocketID] = PocketSource(archivedPocket);
      changes.add(UpsertPocket(archivedPocket));
    }

    changes.addAll(_removePlansReferencing({id, ...archived.subPocketIDs}));
    return changes;
  }

  List<LedgerChange> _removePlansReferencing(Set<String> ids) {
    // Materialized before the removal loop: mutating _plans mid-iteration throws.
    final removed = _plans.values
        .where((plan) => plan.template.touches(ids))
        .map((plan) => plan.id)
        .toList();
    for (final planID in removed) {
      _plans.remove(planID);
    }
    return removed.map(DeletePlan.new).toList();
  }

  List<LedgerChange> deletePocket(String rawID) {
    final id = canonicalID(rawID);
    final pocket = _moneySources[id]?.asPocket;
    if (pocket == null || !pocket.lifecycle.isActive) return [];

    final archived = pocket.settingLifecycle(LifecycleState.archived);
    _moneySources[id] = PocketSource(archived);
    return [UpsertPocket(archived)];
  }

  List<LedgerChange> deleteCategory(String rawID) {
    final id = canonicalID(rawID);
    final category = _categories[id];
    if (category == null || !category.lifecycle.isActive) return [];

    final archived = category.settingLifecycle(LifecycleState.archived);
    _categories[id] = archived;
    final changes = <LedgerChange>[UpsertCategory(archived)];

    for (final child in _children(id)) {
      if (!child.lifecycle.isActive) continue;

      final archivedChild = child.settingLifecycle(LifecycleState.archived);
      _categories[child.id] = archivedChild;
      changes.add(UpsertCategory(archivedChild));
    }
    return changes;
  }

  List<LedgerChange> restoreAccount(String rawID) {
    final id = canonicalID(rawID);
    final account = _moneySources[id]?.asAccount;
    if (account == null || account.lifecycle != LifecycleState.archived) {
      return [];
    }

    final restored = account.settingLifecycle(LifecycleState.active);
    _moneySources[id] = AccountSource(restored);
    final changes = <LedgerChange>[UpsertAccount(restored)];

    // referenceOnly pockets stay put, having left the bin permanently.
    for (final pocketID in restored.subPocketIDs) {
      final pocket = _moneySources[pocketID]?.asPocket;
      if (pocket == null || pocket.lifecycle != LifecycleState.archived) {
        continue;
      }

      final restoredPocket = pocket.settingLifecycle(LifecycleState.active);
      _moneySources[pocketID] = PocketSource(restoredPocket);
      changes.add(UpsertPocket(restoredPocket));
    }
    return changes;
  }

  List<LedgerChange> restorePocket(String rawID) {
    final id = canonicalID(rawID);
    final pocket = _moneySources[id]?.asPocket;
    if (pocket == null || pocket.lifecycle != LifecycleState.archived) {
      return [];
    }
    final restored = pocket.settingLifecycle(LifecycleState.active);
    if (_willOutliveParentAccount(restored)) return [];

    _moneySources[id] = PocketSource(restored);
    return [UpsertPocket(restored)];
  }

  List<LedgerChange> restoreCategory(String rawID) {
    final id = canonicalID(rawID);
    final category = _categories[id];
    if (category == null || category.lifecycle != LifecycleState.archived) {
      return [];
    }
    final parentID = category.parentID;
    if (parentID != null &&
        _categories[parentID]?.lifecycle == LifecycleState.archived) {
      return [];
    }

    final restored = category.settingLifecycle(LifecycleState.active);
    _categories[id] = restored;
    final changes = <LedgerChange>[UpsertCategory(restored)];

    for (final child in _children(id)) {
      if (child.lifecycle != LifecycleState.archived) continue;

      final restoredChild = child.settingLifecycle(LifecycleState.active);
      _categories[child.id] = restoredChild;
      changes.add(UpsertCategory(restoredChild));
    }
    return changes;
  }

  List<TransactionCategory> _children(String parentID) => _categories.values
      .where((category) => category.parentID == parentID)
      .toList();

  /// Parent lifecycle is unchecked. Orphaned children are handled by the
  /// lifecycle cascades instead, so an active child under an archived parent is
  /// reachable and purgeCategory sweeps children regardless of lifecycle.
  void _validateParent(TransactionCategory category) {
    final parentID = category.parentID;
    if (parentID == null) return;

    final parent = _categories[parentID];
    if (parent == null) throw UnknownCategory(parentID);
    if (parent.parentID != null) throw const CategoryTooDeep();
    if (parent.kind != category.kind) throw const CategoryKindMismatch();
  }

  /// A literal top-to-bottom sequence, since the check order is observable.
  Entry _validated(Entry entry, {Entry? previous}) {
    if (entry.amount == Decimal.zero) throw const ZeroAmount();

    final source = _moneySources[entry.sourceID];
    if (source == null) throw UnknownHolder(entry.sourceID);

    final priorRefs = previous?.holderIDs ?? const <String>{};
    if (!priorRefs.contains(entry.sourceID) && !source.lifecycle.isActive) {
      throw InactiveReference(entry.sourceID);
    }

    final categoryID = entry.categoryID;
    if (categoryID != null) {
      final category = _categories[categoryID];
      if (category == null) throw UnknownCategory(categoryID);
      final expected = entry.expectedCategoryKind;
      if (expected == null) throw const CategoryKindMismatch();
      if (category.kind != expected) throw const CategoryKindMismatch();
      if (previous?.categoryID != categoryID && !category.lifecycle.isActive) {
        throw InactiveReference(categoryID);
      }
    }

    final destinationID = entry.destinationID;
    if (destinationID == null) return entry;

    final destination = _moneySources[destinationID];
    if (destination == null) throw UnknownHolder(destinationID);
    if (destinationID == entry.sourceID) throw const SelfTransfer();
    if (!priorRefs.contains(destinationID) && !destination.lifecycle.isActive) {
      throw InactiveReference(destinationID);
    }

    if (entry.amount >= Decimal.zero) return entry;

    return Entry(
      id: entry.id,
      date: entry.date,
      amount: -entry.amount,
      name: entry.name,
      categoryID: entry.categoryID,
      sourceID: destinationID,
      destinationID: entry.sourceID,
      includeInAnalysis: entry.includeInAnalysis,
      lifecycle: entry.lifecycle,
    );
  }

  /// Pockets settle first so the account sees their survival when it judges its
  /// own referencedness.
  List<LedgerChange> purgeAccount(String rawID) {
    final id = canonicalID(rawID);
    final account = _moneySources[id]?.asAccount;
    if (account == null || account.lifecycle != LifecycleState.archived) {
      return [];
    }

    final changes = <LedgerChange>[];
    for (final pocketID in account.subPocketIDs.toList()) {
      final pocket = _moneySources[pocketID]?.asPocket;
      if (pocket == null) continue;

      changes.addAll(_purgeHolder(pocketID));
    }

    return [...changes, ..._purgeHolder(id)];
  }

  List<LedgerChange> purgePocket(String rawID) {
    final id = canonicalID(rawID);
    final pocket = _moneySources[id]?.asPocket;
    if (pocket == null || pocket.lifecycle != LifecycleState.archived) {
      return [];
    }
    return _purgeHolder(id);
  }

  /// Expects an already-canonical id naming a stored holder.
  List<LedgerChange> _purgeHolder(String holderID) {
    if (!_isReferenced(holderID)) {
      final pocket = _moneySources[holderID]?.asPocket;
      if (pocket != null) return _detachAndTombstonePocket(holderID);

      _moneySources.remove(holderID);
      return [DeleteMoneySource(holderID)];
    }

    switch (_moneySources[holderID]!) {
      case AccountSource(:final account):
        final kept = account.settingLifecycle(LifecycleState.referenceOnly);
        _moneySources[holderID] = AccountSource(kept);
        return [UpsertAccount(kept)];
      case PocketSource(:final pocket):
        final kept = pocket.settingLifecycle(LifecycleState.referenceOnly);
        _moneySources[holderID] = PocketSource(kept);
        return [UpsertPocket(kept)];
    }
  }

  /// Expects an already-canonical id. The parent upsert precedes the deletion,
  /// so a consumer replaying the changes never sees the link outlive the row.
  List<LedgerChange> _detachAndTombstonePocket(String pocketID) {
    final parent = _owningAccount(pocketID);
    final changes = <LedgerChange>[];

    if (parent != null) {
      final detached = parent.removeSubPocket(pocketID);
      _moneySources[detached.id] = AccountSource(detached);
      changes.add(UpsertAccount(detached));
    }

    _moneySources.remove(pocketID);
    changes.add(DeleteMoneySource(pocketID));
    return changes;
  }

  List<LedgerChange> purgeCategory(String rawID) {
    final id = canonicalID(rawID);
    final category = _categories[id];
    if (category == null || category.lifecycle != LifecycleState.archived) {
      return [];
    }

    // Children go regardless of lifecycle, unlike the archive and restore
    // cascades, so an active child cannot outlive the row it hangs from.
    final doomed = [category, ..._children(id)];
    return [for (final row in doomed) ..._purgeCategoryRow(row)];
  }

  List<LedgerChange> _purgeCategoryRow(TransactionCategory category) {
    if (entryCountReferencing(category.id) > 0) {
      final kept = category.settingLifecycle(LifecycleState.referenceOnly);
      _categories[kept.id] = kept;
      return [UpsertCategory(kept)];
    }

    _categories.remove(category.id);
    return [DeleteCategory(category.id)];
  }

  /// The only referenceOnly to tombstoned path. Holders sweep before the
  /// category so a holder losing its last reference cannot be missed.
  List<LedgerChange> _tombstoneDereferenced(
    Set<String> holders,
    String? category,
  ) {
    final changes = <LedgerChange>[];
    for (final holderID in holders) {
      changes.addAll(_sweepHolder(holderID));
    }

    if (category == null) return changes;

    final stored = _categories[category];
    if (stored == null ||
        stored.lifecycle != LifecycleState.referenceOnly ||
        entryCountReferencing(category) > 0) {
      return changes;
    }

    _categories.remove(category);
    return [...changes, DeleteCategory(category)];
  }

  List<LedgerChange> _sweepHolder(String holderID) {
    final source = _moneySources[holderID];
    if (source == null ||
        source.lifecycle != LifecycleState.referenceOnly ||
        _isReferenced(holderID)) {
      return [];
    }

    if (source.asPocket == null) {
      _moneySources.remove(holderID);
      return [DeleteMoneySource(holderID)];
    }

    // The parent may have been held up solely by this pocket, so it is
    // re-judged once the pocket is gone.
    final parent = _owningAccount(holderID);
    final changes = _detachAndTombstonePocket(holderID);
    if (parent == null) return changes;

    return [...changes, ..._sweepHolder(parent.id)];
  }
}
