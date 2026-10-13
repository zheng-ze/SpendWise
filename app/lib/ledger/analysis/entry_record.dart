import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

// MARK: - Record

@immutable
class EntryRecord {
  const EntryRecord({
    required this.entry,
    required this.category,
    required this.parentCategory,
    required this.sourceName,
    required this.destinationName,
  });

  final Entry entry;
  final TransactionCategory? category;
  final TransactionCategory? parentCategory;
  final String? sourceName;
  final String? destinationName;

  @override
  bool operator ==(Object other) {
    return other is EntryRecord &&
        other.entry == entry &&
        other.category == category &&
        other.parentCategory == parentCategory &&
        other.sourceName == sourceName &&
        other.destinationName == destinationName;
  }

  @override
  int get hashCode =>
      Object.hash(entry, category, parentCategory, sourceName, destinationName);
}

EntryRecord entryRecord(LedgerState ledger, Entry entry) {
  final category = entry.categoryID == null
      ? null
      : ledger.categories[entry.categoryID];
  final parentID = category?.parentID;
  return EntryRecord(
    entry: entry,
    category: category,
    parentCategory: parentID == null ? null : ledger.categories[parentID],
    sourceName: ledger.sourceName(entry.sourceID),
    destinationName: ledger.sourceName(entry.destinationID),
  );
}
