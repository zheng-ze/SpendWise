import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

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

Set<String>? normalizedScope(Set<String>? sourceIDs) {
  if (sourceIDs == null) return null;
  return sourceIDs.map(normalizedID).toSet();
}

DateRange normalizedWindow(DateRange window) {
  final start = startOfDayUtc(window.start);
  final end = startOfDayUtc(window.end);
  if (end.isBefore(start)) {
    throw ArgumentError.value(window, 'window', 'End is before start.');
  }
  return DateRange(start, end);
}

bool inScope(HolderReferencing holder, Set<String>? scope) {
  return scope == null || holder.touches(scope);
}
