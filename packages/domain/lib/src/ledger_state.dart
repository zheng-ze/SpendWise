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

part 'ledger_state_invariants.dart';
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

  /// Previous settled lifecycles, for the one check that judges a transition
  /// rather than a state. Written only from inside an `assert`.
  Map<String, LifecycleState>? _lifecycleAtLastCheck;

  /// The closure form keeps the check out of release builds entirely.
  List<LedgerChange> _checked(List<LedgerChange> changes) {
    assert(() {
      _assertChecked();
      return true;
    }());
    return changes;
  }

  PlanResolution _checkedResolution(PlanResolution resolution) {
    assert(() {
      _assertChecked();
      return true;
    }());
    return resolution;
  }

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
      statementDay: _statementDayFor(account.type, account.statementDay),
      lifecycle: account.lifecycle,
    );
    _moneySources[stored.id] = AccountSource(stored);
    return _checked([UpsertAccount(stored)]);
  }

  /// Clamped rather than rejected, since a value reaching here came from a
  /// drift row or an import, and dropping the row would lose more. 28 is the
  /// ceiling so every month has the day.
  int? _statementDayFor(AccountType type, int? statementDay) {
    if (type != AccountType.card || statementDay == null) return null;

    return statementDay.clamp(1, 28);
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
      statementDay: _statementDayFor(account.type, account.statementDay),
      lifecycle: _editableLifecycle(account.lifecycle, existing.lifecycle),
    );
    _moneySources[stored.id] = AccountSource(stored);
    return _checked([UpsertAccount(stored), ..._demotePocketsBelow(stored)]);
  }

  /// A pocket may never be more alive than its account. The pocket write path
  /// enforces that by judging the child, so an edit that moves the parent
  /// instead has to carry its pockets down itself.
  List<LedgerChange> _demotePocketsBelow(Account account) {
    final changes = <LedgerChange>[];
    for (final pocketID in account.subPocketIDs) {
      final pocket = _moneySources[pocketID]?.asPocket;
      if (pocket == null ||
          account.lifecycle.isAtLeastAsAliveAs(pocket.lifecycle)) {
        continue;
      }

      final demoted = pocket.settingLifecycle(account.lifecycle);
      _moneySources[pocketID] = PocketSource(demoted);
      changes.add(UpsertPocket(demoted));
    }
    return changes;
  }

  List<LedgerChange> addPocket(SubPocket pocket, String rawAccountID) {
    final accountID = canonicalID(rawAccountID);
    final parent = _moneySources[accountID]?.asAccount;
    if (parent == null) throw UnknownAccount(accountID);
    if (_moneySources.containsKey(pocket.id)) throw IdCollision(pocket.id);
    if (!parent.lifecycle.isActive) throw InactiveReference(accountID);

    final linked = parent.addSubPocket(pocket.id);
    _moneySources[pocket.id] = PocketSource(pocket);
    _moneySources[linked.id] = AccountSource(linked);
    return _checked([UpsertPocket(pocket), UpsertAccount(linked)]);
  }

  List<LedgerChange> updatePocket(SubPocket pocket) {
    final existing = _moneySources[pocket.id]?.asPocket;
    if (existing == null) throw UnknownHolder(pocket.id);

    final requested = pocket.settingLifecycle(
      _editableLifecycle(pocket.lifecycle, existing.lifecycle),
    );
    final stored = _willOutliveParentAccount(requested)
        ? requested.settingLifecycle(existing.lifecycle)
        : requested;
    _moneySources[stored.id] = PocketSource(stored);
    return _checked([UpsertPocket(stored)]);
  }

  /// An edit carries whatever lifecycle it was handed, so it never moves a row:
  /// the delete, purge and restore mutators own those transitions and each has
  /// its own precondition. Keeps `referenceOnly` terminal and `tombstoned`
  /// unwritable through the public API.
  LifecycleState _editableLifecycle(
    LifecycleState incoming,
    LifecycleState stored,
  ) {
    if (incoming == LifecycleState.tombstoned) return stored;

    return incoming.isAtLeastAsAliveAs(stored) && incoming != stored
        ? stored
        : incoming;
  }

  bool _willOutliveParentAccount(SubPocket pocket) {
    final parent = _owningAccount(pocket.id);
    if (parent == null) return true;

    return !parent.lifecycle.isAtLeastAsAliveAs(pocket.lifecycle);
  }

  List<LedgerChange> addEntry(Entry entry) {
    if (_entries.containsKey(entry.id)) throw IdCollision(entry.id);

    final stored = _validated(entry);
    _entries[stored.id] = stored;
    return _checked([UpsertEntry(stored)]);
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
    return _checked([
      UpsertEntry(stored),
      ..._tombstoneDereferenced(droppedHolders, droppedCategory),
    ]);
  }

  List<LedgerChange> setOpeningBalance(
    Decimal amount,
    String rawHolderID, {
    DateTime? date,
  }) {
    final holderID = canonicalID(rawHolderID);
    if (!_moneySources.containsKey(holderID)) throw UnknownHolder(holderID);
    if (amount == Decimal.zero) return _checked([]);

    return _checked(
      addEntry(
        Entry(
          date: date,
          amount: amount,
          name: 'Opening balance',
          sourceID: holderID,
          includeInAnalysis: false,
        ),
      ),
    );
  }

  List<LedgerChange> deleteEntry(String rawID) {
    final id = canonicalID(rawID);
    final removed = _entries.remove(id);
    if (removed == null) return _checked([]);

    return _checked([
      DeleteEntry(id),
      ..._tombstoneDereferenced(removed.holderIDs, removed.categoryID),
    ]);
  }

  List<LedgerChange> addCategory(TransactionCategory category) {
    if (_categories.containsKey(category.id)) throw IdCollision(category.id);

    _validateParent(category);
    _categories[category.id] = category;
    return _checked([UpsertCategory(category)]);
  }

  List<LedgerChange> updateCategory(TransactionCategory category) {
    final existing = _categories[category.id];
    if (existing == null) throw UnknownCategory(category.id);

    // Kind is fixed at creation: a swap would strand both the entries whose
    // sign it contradicts and the children that inherit it.
    if (existing.kind != category.kind) throw const CategoryKindMismatch();

    _validateParent(category);

    final requested = category.settingLifecycle(
      _editableLifecycle(category.lifecycle, existing.lifecycle),
    );
    final stored = _willOutliveParentCategory(requested)
        ? requested.settingLifecycle(existing.lifecycle)
        : requested;
    _categories[stored.id] = stored;

    // A parent held up solely by this child's link is re-judged once it moves.
    final droppedParent = existing.parentID == stored.parentID
        ? null
        : existing.parentID;
    return _checked([
      UpsertCategory(stored),
      if (droppedParent != null) ..._sweepCategory(droppedParent),
    ]);
  }

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
    return _checked([UpsertPlan(plan)]);
  }

  List<LedgerChange> updatePlan(RecurringPlan plan) {
    if (!_plans.containsKey(plan.id)) throw UnknownPlan(plan.id);

    _validatePlan(plan);
    _plans[plan.id] = plan;
    return _checked([UpsertPlan(plan)]);
  }

  List<LedgerChange> deletePlan(String rawID) {
    final id = canonicalID(rawID);
    if (_plans.remove(id) == null) return _checked([]);

    return _checked([DeletePlan(id)]);
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

    return _checkedResolution(
      PlanResolution(changes: changes, failures: failures),
    );
  }

  List<LedgerChange> deleteAccount(String rawID) {
    final id = canonicalID(rawID);
    final account = _moneySources[id]?.asAccount;
    if (account == null || !account.lifecycle.isActive) return _checked([]);

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
    return _checked(changes);
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

  List<LedgerChange> _removePlansCategorized(String categoryID) {
    final removed = _plans.values
        .where((plan) => plan.template.categoryID == categoryID)
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
    if (pocket == null || !pocket.lifecycle.isActive) return _checked([]);

    // No plan cascade: archiving freezes plans so a restore is not lossy. Their
    // occurrences fail validation meanwhile, and resolving reports that.
    final archived = pocket.settingLifecycle(LifecycleState.archived);
    _moneySources[id] = PocketSource(archived);
    return _checked([UpsertPocket(archived)]);
  }

  List<LedgerChange> deleteCategory(String rawID) {
    final id = canonicalID(rawID);
    final category = _categories[id];
    if (category == null || !category.lifecycle.isActive) return _checked([]);

    final archived = category.settingLifecycle(LifecycleState.archived);
    _categories[id] = archived;
    final changes = <LedgerChange>[UpsertCategory(archived)];

    // Archiving freezes plans rather than dropping them, as for a pocket.
    for (final child in _children(id)) {
      if (!child.lifecycle.isActive) continue;

      final archivedChild = child.settingLifecycle(LifecycleState.archived);
      _categories[child.id] = archivedChild;
      changes.add(UpsertCategory(archivedChild));
    }
    return _checked(changes);
  }

  List<LedgerChange> restoreAccount(String rawID) {
    final id = canonicalID(rawID);
    final account = _moneySources[id]?.asAccount;
    if (account == null || account.lifecycle != LifecycleState.archived) {
      return _checked([]);
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
    return _checked(changes);
  }

  List<LedgerChange> restorePocket(String rawID) {
    final id = canonicalID(rawID);
    final pocket = _moneySources[id]?.asPocket;
    if (pocket == null || pocket.lifecycle != LifecycleState.archived) {
      return _checked([]);
    }
    final restored = pocket.settingLifecycle(LifecycleState.active);
    if (_willOutliveParentAccount(restored)) return _checked([]);

    _moneySources[id] = PocketSource(restored);
    return _checked([UpsertPocket(restored)]);
  }

  List<LedgerChange> restoreCategory(String rawID) {
    final id = canonicalID(rawID);
    final category = _categories[id];
    if (category == null || category.lifecycle != LifecycleState.archived) {
      return _checked([]);
    }
    final parentID = category.parentID;
    if (parentID != null &&
        _categories[parentID]?.lifecycle == LifecycleState.archived) {
      return _checked([]);
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
    return _checked(changes);
  }

  List<TransactionCategory> _children(String parentID) => _categories.values
      .where((category) => category.parentID == parentID)
      .toList();

  /// An archived parent is allowed, since purgeCategory sweeps children
  /// regardless of lifecycle. A `referenceOnly` one is not: the dereference
  /// sweep deletes it without looking for children, orphaning the child.
  void _validateParent(TransactionCategory category) {
    final parentID = category.parentID;
    if (parentID == null) return;

    final parent = _categories[parentID];
    if (parent == null) throw UnknownCategory(parentID);
    if (parent.parentID != null) throw const CategoryTooDeep();
    if (parent.kind != category.kind) throw const CategoryKindMismatch();
    if (!parent.lifecycle.isAtLeastAsAliveAs(LifecycleState.archived)) {
      throw InactiveReference(parentID);
    }
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
      return _checked([]);
    }

    final changes = <LedgerChange>[];
    for (final pocketID in account.subPocketIDs.toList()) {
      final pocket = _moneySources[pocketID]?.asPocket;
      if (pocket == null) continue;

      changes.addAll(_purgeHolder(pocketID));
    }

    return _checked([...changes, ..._purgeHolder(id)]);
  }

  List<LedgerChange> purgePocket(String rawID) {
    final id = canonicalID(rawID);
    final pocket = _moneySources[id]?.asPocket;
    if (pocket == null || pocket.lifecycle != LifecycleState.archived) {
      return _checked([]);
    }
    return _checked(_purgeHolder(id));
  }

  List<LedgerChange> _purgeHolder(String holderID) {
    if (!_isHolderReferenced(holderID)) {
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

  /// The parent upsert precedes the deletion, so a consumer replaying the
  /// changes never sees the link outlive the row.
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
      return _checked([]);
    }

    // Children go regardless of lifecycle, unlike the archive and restore
    // cascades, so an active child cannot outlive the row it hangs from. They
    // sweep first so a survivor is visible when the parent is judged, but emit
    // after it.
    final childChanges = [
      for (final child in _children(id)) ..._purgeCategoryRow(child),
    ];
    return _checked([..._purgeCategoryRow(category), ...childChanges]);
  }

  List<LedgerChange> _purgeCategoryRow(TransactionCategory category) {
    if (_isCategoryReferenced(category.id)) {
      final kept = category.settingLifecycle(LifecycleState.referenceOnly);
      _categories[kept.id] = kept;
      return [UpsertCategory(kept)];
    }

    _categories.remove(category.id);
    return [
      DeleteCategory(category.id),
      ..._removePlansCategorized(category.id),
    ];
  }

  bool _isCategoryReferenced(String id, [Set<String>? seen]) {
    final visited = seen ?? <String>{};
    if (!visited.add(id)) return false;
    if (!_categories.containsKey(id)) return false;
    if (entryCountReferencing(id) > 0) return true;

    return _children(
      id,
    ).any((child) => _isCategoryReferenced(child.id, visited));
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

    return [...changes, ..._sweepCategory(category)];
  }

  List<LedgerChange> _sweepCategory(String categoryID) {
    final stored = _categories[categoryID];
    if (stored == null ||
        stored.lifecycle != LifecycleState.referenceOnly ||
        _isCategoryReferenced(categoryID)) {
      return [];
    }

    final parentID = stored.parentID;
    _categories.remove(categoryID);
    final changes = <LedgerChange>[
      DeleteCategory(categoryID),
      ..._removePlansCategorized(categoryID),
    ];
    if (parentID == null) return changes;

    return [...changes, ..._sweepCategory(parentID)];
  }

  List<LedgerChange> _sweepHolder(String holderID) {
    final source = _moneySources[holderID];
    if (source == null ||
        source.lifecycle != LifecycleState.referenceOnly ||
        _isHolderReferenced(holderID)) {
      return [];
    }

    if (source.asPocket == null) {
      _moneySources.remove(holderID);
      return [
        DeleteMoneySource(holderID),
        ..._removePlansReferencing({holderID}),
      ];
    }

    // Read before the detach below, which clears the link.
    final parent = _owningAccount(holderID);
    final changes = [
      ..._detachAndTombstonePocket(holderID),
      ..._removePlansReferencing({holderID}),
    ];
    if (parent == null) return changes;

    return [...changes, ..._sweepHolder(parent.id)];
  }
}
