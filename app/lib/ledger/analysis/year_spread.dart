import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

@immutable
class YearSlot {
  const YearSlot({
    required this.year,
    required this.window,
    required this.total,
    required this.itemCount,
  });

  final int year;

  final DateRange window;

  final Decimal total;

  final int itemCount;

  @override
  bool operator ==(Object other) {
    return other is YearSlot &&
        other.year == year &&
        other.window == window &&
        other.total == total &&
        other.itemCount == itemCount;
  }

  @override
  int get hashCode => Object.hash(year, window, total, itemCount);
}

@immutable
class YearSpread {
  const YearSpread({
    required this.endYear,
    required this.kind,
    required this.currentYear,
    required this.earliestSpreadEndYear,
    required this.slots,
  });

  final int endYear;

  final CategoryKind kind;

  final int currentYear;

  final int earliestSpreadEndYear;

  final List<YearSlot> slots;

  @override
  bool operator ==(Object other) {
    return other is YearSpread &&
        other.endYear == endYear &&
        other.kind == kind &&
        other.currentYear == currentYear &&
        other.earliestSpreadEndYear == earliestSpreadEndYear &&
        listEquals(other.slots, slots);
  }

  @override
  int get hashCode => Object.hash(
    endYear,
    kind,
    currentYear,
    earliestSpreadEndYear,
    Object.hashAll(slots),
  );
}

YearSpread yearSpread({
  required Iterable<AnalysisItem> items,
  required int endYear,
  required CategoryKind kind,
  required DateTime? firstRecordMonth,
  required DateTime today,
}) {
  final currentYear = startOfDayUtc(today).year;
  final earliestSpreadEndYear = _earliestEnd(
    firstRecordYear: firstRecordMonth?.year,
    currentYear: currentYear,
  );
  final ofKind = items.where((item) => item.kind == kind).toList();
  final slots = <YearSlot>[];
  for (var year = endYear - 2; year <= endYear; year++) {
    final window = DateRange(
      DateTime.utc(year, 1, 1),
      DateTime.utc(year + 1, 1, 1),
    );
    var total = Decimal.zero;
    var count = 0;
    for (final item in ofKind) {
      if (!window.contains(item.date)) continue;
      total += item.amount;
      count++;
    }
    slots.add(
      YearSlot(year: year, window: window, total: total, itemCount: count),
    );
  }
  return YearSpread(
    endYear: endYear,
    kind: kind,
    currentYear: currentYear,
    earliestSpreadEndYear: earliestSpreadEndYear,
    slots: List.unmodifiable(slots),
  );
}

int _earliestEnd({required int? firstRecordYear, required int currentYear}) {
  if (firstRecordYear == null || firstRecordYear > currentYear) {
    return currentYear;
  }
  final back = 3 * ((currentYear - firstRecordYear) ~/ 3);
  return currentYear - back;
}
