import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/budgets/budget_detail.dart';
import 'package:spendwise/ledger/analysis/insights/completeness.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/common/charts/month_bars.dart';

// MARK: - Constants
const _emptyProgress = 0.0;
const _fullProgress = 1.0;
const _overallEmptyTitle = 'No spending yet this month';
const _overallEmptyBody = 'Add an expense to see it here.';

// MARK: - Values
typedef BudgetDetailEmptyCopy = ({String title, String body});

enum BudgetDetailBody { skeleton, failure, deleted, content }

@immutable
class BudgetDetailSummaryValues {
  const BudgetDetailSummaryValues({required this.spent, required this.limit});

  final Decimal spent;
  final Decimal limit;

  Decimal get remaining => limit - spent;

  bool get overLimit => spent > limit;

  double get progress {
    if (limit <= Decimal.zero) return _emptyProgress;
    return (spent / limit).toDouble().clamp(_emptyProgress, _fullProgress);
  }
}

@immutable
class BudgetDetailPresentation {
  const BudgetDetailPresentation({
    required this.body,
    required this.failure,
    required this.summary,
    required this.emptyCopy,
  });

  final BudgetDetailBody body;

  final Object? failure;

  final BudgetDetailSummaryValues? summary;

  final BudgetDetailEmptyCopy? emptyCopy;
}

// MARK: - Mapping
BudgetDetailPresentation budgetDetailPresentation(BudgetDetailViewState state) {
  final projection = state.projection;
  final failure = state.error;
  if (state.phase == BudgetDetailPhase.deleted) {
    return const BudgetDetailPresentation(
      body: BudgetDetailBody.deleted,
      failure: null,
      summary: null,
      emptyCopy: null,
    );
  }
  if (projection == null) {
    return BudgetDetailPresentation(
      body: state.phase == BudgetDetailPhase.failed
          ? BudgetDetailBody.failure
          : BudgetDetailBody.skeleton,
      failure: failure,
      summary: null,
      emptyCopy: null,
    );
  }

  final emptyCopy = state.countedEntries.isEmpty
      ? budgetDetailEmptyCopy(state.categoryName)
      : null;
  return BudgetDetailPresentation(
    body: BudgetDetailBody.content,
    failure: failure,
    summary: BudgetDetailSummaryValues(
      spent: state.spent,
      limit: projection.selectedLimit,
    ),
    emptyCopy: emptyCopy,
  );
}

BudgetDetailEmptyCopy budgetDetailEmptyCopy(String? categoryName) {
  if (categoryName == null) {
    return (title: _overallEmptyTitle, body: _overallEmptyBody);
  }
  return (
    title: 'No $categoryName spending yet this month',
    body: 'Choose $categoryName when you add an expense.',
  );
}

List<MonthBarSlot> budgetMonthBarSlots(List<BudgetMonthSlot> slots) => [
  for (final slot in slots) budgetMonthBarSlot(slot),
];

MonthBarSlot budgetMonthBarSlot(BudgetMonthSlot slot) {
  final hasRecords = slot.recordCount > 0;
  return switch (slot.completeness) {
    PeriodCompleteness.preRecord => const MonthBarSlot(
      status: MonthBarStatus.blank,
    ),
    PeriodCompleteness.complete when hasRecords => MonthBarSlot(
      value: slot.spend.toDouble(),
    ),
    PeriodCompleteness.complete => const MonthBarSlot(
      status: MonthBarStatus.gap,
    ),
    PeriodCompleteness.incomplete when hasRecords => MonthBarSlot(
      value: slot.spend.toDouble(),
      status: MonthBarStatus.incomplete,
    ),
    PeriodCompleteness.incomplete => const MonthBarSlot(
      status: MonthBarStatus.blank,
    ),
  };
}
