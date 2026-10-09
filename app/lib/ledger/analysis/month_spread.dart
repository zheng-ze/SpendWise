import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/completeness.dart';

@immutable
class MonthSlot {
  const MonthSlot({
    required this.month,
    required this.window,
    required this.total,
    required this.itemCount,
  });

  final DateTime month;

  final DateRange window;

  final Decimal total;

  final int itemCount;

  @override
  bool operator ==(Object other) {
    return other is MonthSlot &&
        other.month == month &&
        other.window == window &&
        other.total == total &&
        other.itemCount == itemCount;
  }

  @override
  int get hashCode => Object.hash(month, window, total, itemCount);
}

@immutable
class MonthSpread {
  const MonthSpread({
    required this.endMonth,
    required this.kind,
    required this.firstRecordMonth,
    required this.currentMonth,
    required this.earliestSpreadEndMonth,
    required this.slots,
  });

  final DateTime endMonth;

  final CategoryKind kind;

  final DateTime? firstRecordMonth;

  final DateTime currentMonth;

  final DateTime earliestSpreadEndMonth;

  final List<MonthSlot> slots;

  @override
  bool operator ==(Object other) {
    if (other is! MonthSpread) return false;
    if (other.endMonth != endMonth ||
        other.kind != kind ||
        other.firstRecordMonth != firstRecordMonth ||
        other.currentMonth != currentMonth ||
        other.earliestSpreadEndMonth != earliestSpreadEndMonth ||
        other.slots.length != slots.length) {
      return false;
    }
    for (var i = 0; i < slots.length; i++) {
      if (other.slots[i] != slots[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    endMonth,
    kind,
    firstRecordMonth,
    currentMonth,
    earliestSpreadEndMonth,
    Object.hashAll(slots),
  );
}

MonthSpread monthSpread({
  required Iterable<AnalysisItem> items,
  required DateTime endMonth,
  required CategoryKind kind,
  required DateTime? firstRecordMonth,
  required DateTime today,
}) {
  final end = monthWindow(endMonth).start;
  final day = startOfDayUtc(today);
  final currentMonth = monthWindow(day).start;
  final first = firstRecordMonth == null
      ? null
      : DateTime.utc(firstRecordMonth.year, firstRecordMonth.month, 1);
  final earliestSpreadEndMonth = _earliestEnd(
    firstRecordMonth: first,
    currentMonth: currentMonth,
  );
  final ofKind = items.where((item) => item.kind == kind).toList();
  final slots = <MonthSlot>[];
  for (var back = 11; back >= 0; back--) {
    final month = DateTime.utc(end.year, end.month - back, 1);
    final window = monthWindow(month);
    var total = Decimal.zero;
    var count = 0;
    for (final item in ofKind) {
      if (!window.contains(item.date)) continue;
      total += item.amount;
      count++;
    }
    slots.add(
      MonthSlot(month: month, window: window, total: total, itemCount: count),
    );
  }
  return MonthSpread(
    endMonth: end,
    kind: kind,
    firstRecordMonth: first,
    currentMonth: currentMonth,
    earliestSpreadEndMonth: earliestSpreadEndMonth,
    slots: List.unmodifiable(slots),
  );
}

DateTime _earliestEnd({
  required DateTime? firstRecordMonth,
  required DateTime currentMonth,
}) {
  if (firstRecordMonth == null || firstRecordMonth.isAfter(currentMonth)) {
    return currentMonth;
  }
  final distance =
      (currentMonth.year - firstRecordMonth.year) * 12 +
      (currentMonth.month - firstRecordMonth.month);
  final back = 12 * (distance ~/ 12);
  return DateTime.utc(currentMonth.year, currentMonth.month - back, 1);
}
