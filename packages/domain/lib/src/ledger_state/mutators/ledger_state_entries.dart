part of '../ledger_state.dart';

extension LedgerStateEntries on LedgerState {
  // MARK: - Queries

  Entry? resolvedEntryOrNull(Entry entry) => _resolvedEntryOrNull(entry);

  // MARK: - Mutators

  List<LedgerChange> addEntry(Entry entry) {
    if (_entries.containsKey(entry.id) ||
        _binnedEntries.containsKey(entry.id)) {
      throw IdCollision(entry.id);
    }

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
    final removed = _entries.remove(id) ?? _binnedEntries.remove(id);
    if (removed == null) return _checked([]);

    return _checked([
      DeleteEntry(id),
      ..._tombstoneDereferenced(removed.holderIDs, removed.categoryID),
    ]);
  }

  // MARK: - Archive and restore

  List<LedgerChange> archiveEntry(String rawID) {
    final id = normalizedID(rawID);
    final existing = _entries[id];
    if (existing == null || existing.systemKind != null) {
      return _checked([]);
    }

    final binned = existing.settingLifecycle(LifecycleState.archived);
    _entries.remove(id);
    _binnedEntries[id] = binned;
    return _checked([UpsertEntry(binned)]);
  }

  List<LedgerChange> restoreEntry(String rawID) {
    final id = normalizedID(rawID);
    final existing = _binnedEntries.remove(id);
    if (existing == null) return _checked([]);

    final restored = existing.settingLifecycle(LifecycleState.active);
    _entries[id] = restored;
    return _checked([UpsertEntry(restored)]);
  }

  // MARK: - Purge

  List<LedgerChange> purgeEntry(String rawID) {
    final id = normalizedID(rawID);
    final removed = _binnedEntries.remove(id);
    if (removed == null) return _checked([]);

    return _checked([
      DeleteEntry(id),
      ..._tombstoneDereferenced(removed.holderIDs, removed.categoryID),
    ]);
  }
}
