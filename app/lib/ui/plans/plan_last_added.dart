import 'package:domain/domain.dart';

const Duration _includeAnchorOffset = Duration(days: 1);

DateTime? lastAddedDate(RecurringPlan plan) {
  return plan
      .occurrences(
        after: plan.anchor.subtract(_includeAnchorOffset),
        upTo: plan.lastResolvedDate,
      )
      .lastOrNull;
}
