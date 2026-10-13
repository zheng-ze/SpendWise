import 'package:domain/domain.dart';

import 'package:spendwise/ledger/analysis/entry_record.dart';
import 'package:spendwise/ledger/analysis/scope.dart';

// MARK: - Recent

List<EntryRecord> recentEntries({
  required LedgerState ledger,
  required DateTime today,
  int limit = 4,
  Set<String>? sourceIDs,
}) {
  if (limit < 0) {
    throw ArgumentError.value(limit, 'limit', 'Limit is negative.');
  }
  if (limit == 0) return const [];
  final horizon = startOfDayUtc(today).add(const Duration(days: 1));
  final scope = normalizedScope(sourceIDs);
  final candidates = [
    for (final entry in ledger.entries.values)
      if (entry.lifecycle.isActive &&
          inScope(entry, scope) &&
          entry.date.isBefore(horizon))
        entry,
  ];
  candidates.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    return b.id.compareTo(a.id);
  });
  return List.unmodifiable([
    for (final entry in candidates.take(limit)) entryRecord(ledger, entry),
  ]);
}
