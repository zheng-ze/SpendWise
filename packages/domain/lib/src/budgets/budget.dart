import 'package:domain/src/budgets/limit_event.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/time/year_month.dart';
import 'package:meta/meta.dart';

// MARK: - Model

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
