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
