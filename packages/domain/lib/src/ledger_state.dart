import 'package:decimal/decimal.dart';
import 'package:domain/src/account.dart';
import 'package:domain/src/account_type.dart';
import 'package:domain/src/entry.dart';
import 'package:domain/src/ledger_change.dart';
import 'package:domain/src/ledger_error.dart';
import 'package:domain/src/lifecycle_state.dart';
import 'package:domain/src/money_source.dart';
import 'package:domain/src/sub_pocket.dart';
import 'package:domain/src/transaction_category.dart';

part 'ledger_state_queries.dart';

class LedgerState {
  LedgerState({
    Map<String, MoneySource>? moneySources,
    Map<String, Entry>? entries,
    Map<String, TransactionCategory>? categories,
  }) : moneySources = moneySources ?? {},
       entries = entries ?? {},
       categories = categories ?? {};

  /// Accounts and pockets share this table and one id space.
  final Map<String, MoneySource> moneySources;

  final Map<String, Entry> entries;
  final Map<String, TransactionCategory> categories;

  List<LedgerChange> addAccount(Account account) {
    if (moneySources.containsKey(account.id)) {
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
    moneySources[stored.id] = AccountSource(stored);
    return [UpsertAccount(stored)];
  }

  List<LedgerChange> updateAccount(Account account) {
    final existing = moneySources[account.id]?.asAccount;
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
    moneySources[stored.id] = AccountSource(stored);
    return [UpsertAccount(stored)];
  }

  List<LedgerChange> addPocket(SubPocket pocket, String accountID) {
    final parent = moneySources[accountID]?.asAccount;
    if (parent == null) throw UnknownAccount(accountID);
    if (moneySources.containsKey(pocket.id)) throw IdCollision(pocket.id);

    final linked = parent.addSubPocket(pocket.id);
    moneySources[pocket.id] = PocketSource(pocket);
    moneySources[linked.id] = AccountSource(linked);
    return [UpsertPocket(pocket), UpsertAccount(linked)];
  }

  List<LedgerChange> updatePocket(SubPocket pocket) {
    if (moneySources[pocket.id]?.asPocket == null) {
      throw UnknownHolder(pocket.id);
    }
    moneySources[pocket.id] = PocketSource(pocket);
    return [UpsertPocket(pocket)];
  }

  List<LedgerChange> addEntry(Entry entry) {
    if (entries.containsKey(entry.id)) throw IdCollision(entry.id);

    final stored = _validated(entry);
    entries[stored.id] = stored;
    return [UpsertEntry(stored)];
  }

  List<LedgerChange> updateEntry(Entry entry) {
    final previous = entries[entry.id];
    if (previous == null) throw UnknownEntry(entry.id);

    final stored = _validated(entry, previous: previous);
    entries[stored.id] = stored;

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
    String holderID, {
    DateTime? date,
  }) {
    if (!moneySources.containsKey(holderID)) throw UnknownHolder(holderID);
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

  List<LedgerChange> deleteEntry(String id) {
    final removed = entries.remove(id);
    if (removed == null) return [];

    return [
      DeleteEntry(id),
      ..._tombstoneDereferenced(removed.holderIDs, removed.categoryID),
    ];
  }

  List<LedgerChange> addCategory(TransactionCategory category) {
    if (categories.containsKey(category.id)) throw IdCollision(category.id);

    _validateParent(category);
    categories[category.id] = category;
    return [UpsertCategory(category)];
  }

  List<LedgerChange> updateCategory(TransactionCategory category) {
    if (!categories.containsKey(category.id)) {
      throw UnknownCategory(category.id);
    }

    _validateParent(category);
    categories[category.id] = category;
    return [UpsertCategory(category)];
  }

  List<LedgerChange> deleteAccount(String id) {
    final account = moneySources[id]?.asAccount;
    if (account == null || !account.lifecycle.isActive) return [];

    final archived = account.settingLifecycle(LifecycleState.archived);
    moneySources[id] = AccountSource(archived);
    final changes = <LedgerChange>[UpsertAccount(archived)];

    // Links are kept so restore can find the pockets again.
    for (final pocketID in archived.subPocketIDs) {
      final pocket = moneySources[pocketID]?.asPocket;
      if (pocket == null || !pocket.lifecycle.isActive) continue;

      final archivedPocket = pocket.settingLifecycle(LifecycleState.archived);
      moneySources[pocketID] = PocketSource(archivedPocket);
      changes.add(UpsertPocket(archivedPocket));
    }
    return changes;
  }

  List<LedgerChange> deletePocket(String id) {
    final pocket = moneySources[id]?.asPocket;
    if (pocket == null || !pocket.lifecycle.isActive) return [];

    final archived = pocket.settingLifecycle(LifecycleState.archived);
    moneySources[id] = PocketSource(archived);
    return [UpsertPocket(archived)];
  }

  List<LedgerChange> deleteCategory(String id) {
    final category = categories[id];
    if (category == null || !category.lifecycle.isActive) return [];

    final archived = category.settingLifecycle(LifecycleState.archived);
    categories[id] = archived;
    final changes = <LedgerChange>[UpsertCategory(archived)];

    for (final child in _children(id)) {
      if (!child.lifecycle.isActive) continue;

      final archivedChild = child.settingLifecycle(LifecycleState.archived);
      categories[child.id] = archivedChild;
      changes.add(UpsertCategory(archivedChild));
    }
    return changes;
  }

  List<LedgerChange> restoreAccount(String id) {
    final account = moneySources[id]?.asAccount;
    if (account == null || account.lifecycle != LifecycleState.archived) {
      return [];
    }

    final restored = account.settingLifecycle(LifecycleState.active);
    moneySources[id] = AccountSource(restored);
    final changes = <LedgerChange>[UpsertAccount(restored)];

    // referenceOnly pockets stay put, having left the bin permanently.
    for (final pocketID in restored.subPocketIDs) {
      final pocket = moneySources[pocketID]?.asPocket;
      if (pocket == null || pocket.lifecycle != LifecycleState.archived) {
        continue;
      }

      final restoredPocket = pocket.settingLifecycle(LifecycleState.active);
      moneySources[pocketID] = PocketSource(restoredPocket);
      changes.add(UpsertPocket(restoredPocket));
    }
    return changes;
  }

  List<LedgerChange> restorePocket(String id) {
    final pocket = moneySources[id]?.asPocket;
    if (pocket == null || pocket.lifecycle != LifecycleState.archived) {
      return [];
    }
    // A pocket may never outlive its parent, so any inactive parent blocks it.
    if (_owningAccount(id)?.lifecycle.isActive == false) return [];

    final restored = pocket.settingLifecycle(LifecycleState.active);
    moneySources[id] = PocketSource(restored);
    return [UpsertPocket(restored)];
  }

  List<LedgerChange> restoreCategory(String id) {
    final category = categories[id];
    if (category == null || category.lifecycle != LifecycleState.archived) {
      return [];
    }
    final parentID = category.parentID;
    if (parentID != null &&
        categories[parentID]?.lifecycle == LifecycleState.archived) {
      return [];
    }

    final restored = category.settingLifecycle(LifecycleState.active);
    categories[id] = restored;
    final changes = <LedgerChange>[UpsertCategory(restored)];

    for (final child in _children(id)) {
      if (child.lifecycle != LifecycleState.archived) continue;

      final restoredChild = child.settingLifecycle(LifecycleState.active);
      categories[child.id] = restoredChild;
      changes.add(UpsertCategory(restoredChild));
    }
    return changes;
  }

  List<TransactionCategory> _children(String parentID) => categories.values
      .where((category) => category.parentID == parentID)
      .toList();

  /// Parent lifecycle is unchecked. Orphaned children are handled by the
  /// lifecycle cascades instead, so an active child under an archived parent is
  /// reachable and purgeCategory sweeps children regardless of lifecycle.
  void _validateParent(TransactionCategory category) {
    final parentID = category.parentID;
    if (parentID == null) return;

    final parent = categories[parentID];
    if (parent == null) throw UnknownCategory(parentID);
    if (parent.parentID != null) throw const CategoryTooDeep();
    if (parent.kind != category.kind) throw const CategoryKindMismatch();
  }

  /// A literal top-to-bottom sequence, since the check order is observable.
  Entry _validated(Entry entry, {Entry? previous}) {
    if (entry.amount == Decimal.zero) throw const ZeroAmount();

    final source = moneySources[entry.sourceID];
    if (source == null) throw UnknownHolder(entry.sourceID);

    final priorRefs = previous?.holderIDs ?? const <String>{};
    if (!priorRefs.contains(entry.sourceID) && !source.lifecycle.isActive) {
      throw InactiveReference(entry.sourceID);
    }

    final categoryID = entry.categoryID;
    if (categoryID != null) {
      final category = categories[categoryID];
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

    final destination = moneySources[destinationID];
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

  List<LedgerChange> _tombstoneDereferenced(
    Set<String> holders,
    String? category,
  ) {
    return [];
  }
}
