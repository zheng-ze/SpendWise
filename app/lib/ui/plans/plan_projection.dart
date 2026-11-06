import 'package:domain/domain.dart';

import 'package:spendwise/ui/format/money_format.dart';

// MARK: - Constants
const _includeAnchorOffset = Duration(days: 1);
const _unknownAccountLabel = 'Unknown';

// MARK: - Projection
DateTime? lastAddedDate(RecurringPlan plan) {
  return plan
      .occurrences(
        after: plan.anchor.subtract(_includeAnchorOffset),
        upTo: plan.lastResolvedDate,
      )
      .lastOrNull;
}

AmountKind planAmountKind(EntryTemplate template) {
  if (template.destinationID != null) return AmountKind.transfer;
  return template.amount < Decimal.zero
      ? AmountKind.expense
      : AmountKind.income;
}

String planAccountName(LedgerState state, String id) =>
    state.sourceName(id) ?? _unknownAccountLabel;
