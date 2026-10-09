import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/entry_record.dart';

@immutable
class WeekTotal {
  const WeekTotal({
    required this.range,
    required this.effectiveWindow,
    required this.spent,
    required this.expenseItemCount,
  });

  final DateRange range;
  final DateRange effectiveWindow;
  final Decimal spent;
  final int expenseItemCount;

  @override
  bool operator ==(Object other) {
    return other is WeekTotal &&
        other.range == range &&
        other.effectiveWindow == effectiveWindow &&
        other.spent == spent &&
        other.expenseItemCount == expenseItemCount;
  }

  @override
  int get hashCode =>
      Object.hash(range, effectiveWindow, spent, expenseItemCount);
}

List<WeekTotal> weekTotals({
  required LedgerState ledger,
  required List<AnalysisItem> items,
  required DateRange window,
  Set<String>? sourceIDs,
}) {
  final range = normalizedWindow(window);
  if (range.end == range.start) return const [];
  final scope = normalizedScope(sourceIDs);
  final complete = ledger.moneySources.keys.toSet();
  final totals = <WeekTotal>[];
  var weekStart = _mondayOf(range.start);
  while (weekStart.isBefore(range.end)) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    final effective = DateRange(weekStart, weekEnd);
    var spent = Decimal.zero;
    var count = 0;
    if (scope == null) {
      for (final item in items) {
        if (item.kind == CategoryKind.expense &&
            effective.contains(item.date)) {
          spent += item.amount;
          count++;
        }
      }
    } else {
      for (final entry in ledger.entries.values) {
        if (!entry.lifecycle.isActive) continue;
        if (!effective.contains(entry.date)) continue;
        if (!entry.touches(scope)) continue;
        for (final item in Accounting.classify(entry, complete, ledger)) {
          if (item.kind == CategoryKind.expense) {
            spent += item.amount;
            count++;
          }
        }
      }
    }
    totals.add(
      WeekTotal(
        range: DateRange(weekStart, weekEnd),
        effectiveWindow: effective,
        spent: spent,
        expenseItemCount: count,
      ),
    );
    weekStart = weekEnd;
  }
  return List.unmodifiable(totals);
}

DateTime _mondayOf(DateTime date) {
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}
