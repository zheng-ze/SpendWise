part of '../../sync.dart';

// MARK: - Change Collection Mapping

/// Maps a [LedgerChange] to its [SyncCollection]. Total across every variant.
SyncCollection collectionFor(LedgerChange change) {
  switch (change) {
    case UpsertAccount() || UpsertPocket() || DeleteMoneySource():
      return SyncCollection.moneySources;
    case UpsertCategory() || DeleteCategory():
      return SyncCollection.categories;
    case UpsertEntry() || DeleteEntry():
      return SyncCollection.entries;
    case UpsertPlan() || DeletePlan():
      return SyncCollection.plans;
    case UpsertBudget() || DeleteBudget():
      return SyncCollection.budgets;
  }
}

// MARK: - Tombstone Mapping

/// Builds the payload-free delete change for a tombstone envelope.
LedgerChange deleteFor(SyncCollection collection, String rowID) =>
    switch (collection) {
      SyncCollection.moneySources => DeleteMoneySource(normalizedID(rowID)),
      SyncCollection.categories => DeleteCategory(normalizedID(rowID)),
      SyncCollection.entries => DeleteEntry(normalizedID(rowID)),
      SyncCollection.plans => DeletePlan(normalizedID(rowID)),
      SyncCollection.budgets => DeleteBudget(normalizedID(rowID)),
    };
