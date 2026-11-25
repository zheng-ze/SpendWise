import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/id_selection.dart';
import 'package:spendwise/ui/money/money_segment.dart';

// MARK: - Constants
final selectedBudgetProvider =
    NotifierProvider.autoDispose<IdSelectionNotifier, String?>(
      IdSelectionNotifier.new,
    );

final pendingBudgetSelectionProvider =
    NotifierProvider<IdSelectionNotifier, String?>(IdSelectionNotifier.new);

// MARK: - Handoff
void requestBudgetSelection({
  required String budgetID,
  required IdSelectionNotifier pending,
  required MoneySegmentNotifier moneySegment,
}) {
  pending.select(budgetID);
  moneySegment.openAt(MoneySegment.budgets);
}
