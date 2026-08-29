import 'package:decimal/decimal.dart';
import 'package:domain/src/budgets/limit_event.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/time/year_month.dart';
import 'package:meta/meta.dart';

@immutable
class Budget {
  Budget({
    String? id,
    required this.categoryID,
    required List<LimitEvent> limitEvents,
    required this.createdAtMonth,
  }) : id = normalizedOrNewID(id),
       limitEvents = List.unmodifiable(limitEvents);

  final String id;
  final String? categoryID;
  final List<LimitEvent> limitEvents;
  final YearMonth createdAtMonth;

  @override
  bool operator ==(Object other) {
    return other is Budget &&
        other.id == id &&
        other.categoryID == categoryID &&
        _listEquals(other.limitEvents, limitEvents) &&
        other.createdAtMonth == createdAtMonth;
  }

  @override
  int get hashCode =>
      Object.hash(id, categoryID, Object.hashAll(limitEvents), createdAtMonth);

  @override
  String toString() => 'Budget($id, $categoryID)';
}

bool _listEquals(List<LimitEvent> a, List<LimitEvent> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// An override on [month] always wins, last one appended if more than one.
/// Otherwise, the latest default event at or before [month].
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
