import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

@immutable
class TodaySummary {
  const TodaySummary({
    required this.day,
    required this.spent,
    required this.dailyGuide,
    required this.monthlyCap,
  });

  final DateTime day;

  final Decimal spent;

  final Decimal? dailyGuide;

  final Decimal? monthlyCap;

  @override
  bool operator ==(Object other) {
    return other is TodaySummary &&
        other.day == day &&
        other.spent == spent &&
        other.dailyGuide == dailyGuide &&
        other.monthlyCap == monthlyCap;
  }

  @override
  int get hashCode => Object.hash(day, spent, dailyGuide, monthlyCap);
}

TodaySummary todaySummary({
  required LedgerState ledger,
  required List<AnalysisItem> items,
  required DateTime today,
}) {
  final day = startOfDayUtc(today);
  var spent = Decimal.zero;
  for (final item in items) {
    if (item.kind == CategoryKind.expense && item.date == day) {
      spent += item.amount;
    }
  }
  return TodaySummary(
    day: day,
    spent: spent,
    dailyGuide: _dailyGuide(ledger, day),
    monthlyCap: _monthlyCap(ledger, day),
  );
}

Decimal? _dailyGuide(LedgerState ledger, DateTime day) {
  final limit = _monthlyCap(ledger, day);
  if (limit == null) return null;
  final days = DateTime.utc(day.year, day.month + 1, 0).day;
  final padded = limit + Decimal.parse('0.5') * Decimal.fromInt(days);
  return Decimal.fromBigInt(padded ~/ Decimal.fromInt(days));
}

Decimal? _monthlyCap(LedgerState ledger, DateTime day) {
  final month = YearMonth.fromUtc(day);
  Budget? budget;
  for (final candidate in ledger.budgets.values) {
    if (candidate.categoryID != null) continue;
    if (candidate.createdAtMonth > month) continue;
    if (budget != null) {
      throw StateError('More than one unscoped budget applies to $month.');
    }
    budget = candidate;
  }
  if (budget == null) return null;
  return effectiveLimit(budget, month);
}
