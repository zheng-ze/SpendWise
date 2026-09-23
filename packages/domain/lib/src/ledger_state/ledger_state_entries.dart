part of 'ledger_state.dart';

extension LedgerStateEntries on LedgerState {
  List<LedgerChange> addEntry(Entry entry) {
    if (_entries.containsKey(entry.id)) throw IdCollision(entry.id);

    final stored = _validated(entry);
    _entries[stored.id] = stored;
    return _checked([UpsertEntry(stored)]);
  }

  List<LedgerChange> updateEntry(Entry entry) {
    final previous = _entries[entry.id];
    if (previous == null) throw UnknownEntry(entry.id);

    if (previous.systemKind != null &&
        (entry.name != previous.name ||
            entry.categoryID != previous.categoryID ||
            entry.includeInAnalysis != previous.includeInAnalysis)) {
      throw SystemEntryLocked(entry.id);
    }

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
    final holderID = normalizedID(rawHolderID);
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
          systemKind: SystemEntryKind.openingBalance,
        ),
      ),
    );
  }

  List<LedgerChange> deleteEntry(String rawID) {
    final id = normalizedID(rawID);
    final existing = _entries[id];
    if (existing == null) return _checked([]);

    final removed = _entries.remove(id);
    if (removed == null) return _checked([]);

    return _checked([
      DeleteEntry(id),
      ..._tombstoneDereferenced(removed.holderIDs, removed.categoryID),
    ]);
  }

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
      systemKind: entry.systemKind,
    );
  }
}
