import 'package:decimal/decimal.dart';
import 'package:domain/src/budgets/budget.dart';
import 'package:domain/src/budgets/limit_event.dart';
import 'package:domain/src/time/year_month.dart';

// MARK: - Limits

Decimal effectiveLimit(Budget budget, YearMonth month) {
  for (final event in budget.limitEvents.reversed) {
    if (event.kind == LimitEventKind.override &&
        event.effectiveFromMonth == month) {
      return event.value;
    }
  }

  LimitEvent? latestDefault;
  for (final event in budget.limitEvents) {
    if (event.kind != LimitEventKind.defaultLimit) continue;
    final from = event.effectiveFromMonth;
    if (from != null && from > month) continue;

    if (latestDefault == null) {
      latestDefault = event;
      continue;
    }
    final latestFrom = latestDefault.effectiveFromMonth;
    if (latestFrom == null || (from != null && from >= latestFrom)) {
      latestDefault = event;
    }
  }

  if (latestDefault == null) {
    throw StateError(
      'Budget ${budget.id} has no default limit event at or before $month.',
    );
  }
  return latestDefault.value;
}
