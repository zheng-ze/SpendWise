part of '../ledger_state.dart';

extension LedgerStateEntryValidation on LedgerState {
  // MARK: - Queries

  Entry? resolvedEntryOrNull(Entry entry) {
    try {
      return _validated(entry);
    } on LedgerError {
      return null;
    }
  }

  // MARK: - Validation

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
