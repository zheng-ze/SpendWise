import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

@immutable
class PeriodSummary {
  const PeriodSummary({
    required this.window,
    required this.effectiveWindow,
    required this.spent,
    required this.income,
    required this.net,
    required this.moved,
  });

  final DateRange window;

  final DateRange effectiveWindow;

  final Decimal spent;

  final Decimal income;

  final Decimal net;

  final Decimal moved;

  @override
  bool operator ==(Object other) {
    return other is PeriodSummary &&
        other.window == window &&
        other.effectiveWindow == effectiveWindow &&
        other.spent == spent &&
        other.income == income &&
        other.net == net &&
        other.moved == moved;
  }

  @override
  int get hashCode =>
      Object.hash(window, effectiveWindow, spent, income, net, moved);
}

PeriodSummary periodSummary({
  required LedgerState ledger,
  required List<AnalysisItem> items,
  required DateRange window,
  Set<String>? sourceIDs,
}) {
  final start = startOfDayUtc(window.start);
  final end = startOfDayUtc(window.end);
  if (end.isBefore(start)) {
    throw ArgumentError.value(window, 'window', 'End is before start.');
  }
  final effectiveWindow = DateRange(start, end);

  final scope = sourceIDs?.map(normalizedID).toSet();
  final complete = ledger.moneySources.keys.toSet();
  var spent = Decimal.zero;
  var income = Decimal.zero;
  if (scope == null) {
    for (final item in items) {
      if (!effectiveWindow.contains(item.date)) continue;
      switch (item.kind) {
        case CategoryKind.expense:
          spent += item.amount;
        case CategoryKind.income:
          income += item.amount;
      }
    }
  } else {
    for (final entry in ledger.entries.values) {
      if (!entry.lifecycle.isActive) continue;
      if (!effectiveWindow.contains(entry.date)) continue;
      if (!entry.touches(scope)) continue;
      for (final item in Accounting.classify(entry, complete, ledger)) {
        switch (item.kind) {
          case CategoryKind.expense:
            spent += item.amount;
          case CategoryKind.income:
            income += item.amount;
        }
      }
    }
  }

  var moved = Decimal.zero;
  for (final entry in ledger.entries.values) {
    if (!entry.lifecycle.isActive || !entry.isTransfer) continue;
    if (!effectiveWindow.contains(entry.date)) continue;
    if (scope == null) {
      if (!Accounting.applies(entry, complete)) continue;
    } else {
      if (!entry.touches(scope)) continue;
    }
    moved += entry.amount.abs();
  }

  return PeriodSummary(
    window: DateRange(start, end),
    effectiveWindow: effectiveWindow,
    spent: spent,
    income: income,
    net: income - spent,
    moved: moved,
  );
}
