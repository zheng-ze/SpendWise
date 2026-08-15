import 'package:domain/domain.dart';

/// Ascending by next occurrence, ended plans (no next occurrence) last.
/// Ties break by name, so the order is deterministic even between two
/// plans with the same next occurrence date.
List<RecurringPlan> sortedPlans(
  List<RecurringPlan> plans,
  LedgerState state,
  DateTime now,
) {
  final sorted = [...plans];
  sorted.sort((a, b) {
    final aNext = a.nextOccurrence(onOrAfter: now);
    final bNext = b.nextOccurrence(onOrAfter: now);

    final dateComparison = switch ((aNext, bNext)) {
      (null, null) => 0,
      (null, _) => 1,
      (_, null) => -1,
      (final aDate?, final bDate?) => aDate.compareTo(bDate),
    };
    if (dateComparison != 0) return dateComparison;

    return a.template.name.compareTo(b.template.name);
  });
  return sorted;
}
