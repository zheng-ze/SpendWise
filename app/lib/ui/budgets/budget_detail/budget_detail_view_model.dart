import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/analysis/budgets/budget_counted_entries.dart';
import 'package:spendwise/ledger/analysis/budgets/budget_detail.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budgets_steps.dart';
import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/base/step_emitting.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/stats/helpers/trend.dart';

export 'package:spendwise/ui/budgets/budget_detail/budgets_steps.dart';

// MARK: - Chart Scale
double chartMaxY(List<Decimal> spend, List<Decimal> limit) {
  final maxAmount = [
    ...spend,
    ...limit,
  ].fold(Decimal.zero, (max, amount) => amount > max ? amount : max);
  return maxAmount > Decimal.one
      ? maxAmount.toDouble() * _chartHeadroomFactor
      : _emptyChartMaxY;
}

// MARK: - Constants
const _chartHeadroomFactor = 1.15;
const _emptyChartMaxY = 1.0;
const _overallTitle = 'Overall';
const _deletedCategoryTitle = '(category deleted)';

String? _categoryName(Budget budget, LedgerState state) {
  final categoryID = budget.categoryID;
  if (categoryID == null) return null;
  return state.categories[categoryID]?.name ?? _deletedCategoryTitle;
}

// MARK: - Context
typedef BudgetDetailContext = ({
  DateTime displayedYear,
  DateTime selectedMonth,
});

// MARK: - BudgetDetailContextNotifier
class BudgetDetailContextNotifier extends Notifier<BudgetDetailContext> {
  BudgetDetailContextNotifier(this.budgetID);

  final String budgetID;

  @override
  BudgetDetailContext build() {
    final month = ref.read(effectiveMonthProvider);
    return (
      displayedYear: DateTime.utc(month.year),
      selectedMonth: DateTime.utc(month.year, month.month),
    );
  }

  void selectMonth(DateTime month) {
    state = (
      displayedYear: state.displayedYear,
      selectedMonth: DateTime.utc(month.year, month.month),
    );
  }

  void changeYear(DateTime year) {
    state = (
      displayedYear: DateTime.utc(year.year),
      selectedMonth: DateTime.utc(year.year, state.selectedMonth.month),
    );
  }
}

// MARK: - Projection
@immutable
class BudgetDetailProjection {
  const BudgetDetailProjection({
    required this.ledger,
    required this.displayedYear,
    required this.selectedMonth,
    required this.projection,
    required this.selectedLimit,
    required this.currentLimit,
  });

  final Ledger ledger;
  final DateTime displayedYear;
  final DateTime selectedMonth;
  final BudgetDetail projection;
  final Decimal selectedLimit;
  final Decimal currentLimit;

  List<DateTime> get months => trendMonths(displayedYear, isYearRange: true);

  List<BudgetMonthSlot> get slots => projection.slots;

  double get chartMaxYValue => chartMaxY(
    [for (final slot in projection.slots) slot.spend],
    [currentLimit],
  );

  bool belongsTo(Ledger currentLedger, BudgetDetailContext context) =>
      identical(ledger, currentLedger) &&
      displayedYear == context.displayedYear &&
      selectedMonth == context.selectedMonth;
}

BudgetDetailProjection _captureProjection({
  required Ledger ledger,
  required Budget budget,
  required BudgetDetail projection,
  required BudgetDetailContext context,
  required DateTime today,
}) {
  final summary = projection.summary;
  if (summary == null) {
    throw StateError('Budget ${budget.id} has no detail summary.');
  }
  return BudgetDetailProjection(
    ledger: ledger,
    displayedYear: context.displayedYear,
    selectedMonth: context.selectedMonth,
    projection: projection,
    selectedLimit: summary.limit,
    currentLimit: effectiveLimit(budget, YearMonth.fromUtc(today)),
  );
}

// MARK: - BudgetDetailViewState
enum BudgetDetailPhase { loading, ready, failed, deleted }

class BudgetDetailViewState
    implements HasStep<BudgetDetailViewState, BudgetsStep> {
  const BudgetDetailViewState({
    required this.phase,
    required this.title,
    required this.categoryName,
    required this.ledger,
    required this.ledgerState,
    required this.countedEntries,
    required this.hasCountedEntries,
    required this.displayedYear,
    required this.selectedMonth,
    this.projection,
    this.error,
    this.step,
  });

  final BudgetDetailPhase phase;
  final String title;
  final String? categoryName;
  final Ledger ledger;
  final LedgerState ledgerState;
  final List<BudgetCountedEntry> countedEntries;
  final bool hasCountedEntries;
  final DateTime displayedYear;
  final DateTime selectedMonth;
  final BudgetDetailProjection? projection;
  final Object? error;
  @override
  final BudgetsStep? step;

  Decimal get spent => budgetCountedTotal(countedEntries);

  BudgetDetailViewState copyWith({BudgetsStep? Function()? step}) {
    return BudgetDetailViewState(
      phase: phase,
      title: title,
      categoryName: categoryName,
      ledger: ledger,
      ledgerState: ledgerState,
      countedEntries: countedEntries,
      hasCountedEntries: hasCountedEntries,
      displayedYear: displayedYear,
      selectedMonth: selectedMonth,
      projection: projection,
      error: error,
      step: step == null ? this.step : step(),
    );
  }

  @override
  BudgetDetailViewState withStep(BudgetsStep? Function() step) =>
      copyWith(step: step);
}

// MARK: - BudgetDetailViewModel
abstract class BudgetDetailViewModel {
  void selectMonth(DateTime month);
  void changeYear(DateTime year);
  void requestLimitEdit();
  void retry();
  void clearStep();
}

typedef _ProjectionOutcome = ({
  BudgetDetailPhase phase,
  BudgetDetailProjection? projection,
  Object? error,
});

// MARK: - BudgetDetailNotifier
class BudgetDetailNotifier extends AsyncNotifier<BudgetDetailViewState>
    with
        LedgerBackedNotifier<BudgetDetailViewState>,
        StepEmitting<BudgetDetailViewState, BudgetsStep>
    implements BudgetDetailViewModel {
  BudgetDetailNotifier(this._budgetID);

  final String _budgetID;

  BudgetsStep? _step;

  BudgetDetailProjection? _accepted;

  @override
  BudgetDetailViewState build() {
    final context = ref.watch(budgetDetailContextProvider(_budgetID));
    final queries = ref.watch(analysisQueriesProvider);
    final today = ref.watch(todayProvider);
    if (queries == null) {
      throw StateError('Budget detail requires analysis queries.');
    }
    final currentLedger = ledger;
    final ledgerState = currentLedger.state;
    final budget = ledgerState.budgets[_budgetID];
    if (budget == null) {
      _accepted = null;
      return BudgetDetailViewState(
        phase: BudgetDetailPhase.deleted,
        title: '',
        categoryName: null,
        ledger: currentLedger,
        ledgerState: ledgerState,
        countedEntries: const [],
        hasCountedEntries: false,
        displayedYear: context.displayedYear,
        selectedMonth: context.selectedMonth,
        step: _step,
      );
    }

    final outcome = _resolveProjection(
      queries: queries,
      currentLedger: currentLedger,
      ledgerState: ledgerState,
      budget: budget,
      context: context,
      today: today,
    );
    final categoryName = _categoryName(budget, ledgerState);
    return BudgetDetailViewState(
      phase: outcome.phase,
      title: categoryName ?? _overallTitle,
      categoryName: categoryName,
      ledger: currentLedger,
      ledgerState: ledgerState,
      countedEntries: budgetCountedEntries(
        budget,
        YearMonth.fromUtc(context.selectedMonth),
        ledgerState,
      ),
      hasCountedEntries: budgetHasCountedEntries(budget, ledgerState),
      displayedYear: context.displayedYear,
      selectedMonth: context.selectedMonth,
      projection: outcome.projection,
      error: outcome.error,
      step: _step,
    );
  }

  _ProjectionOutcome _resolveProjection({
    required AnalysisQueries queries,
    required Ledger currentLedger,
    required LedgerState ledgerState,
    required Budget budget,
    required BudgetDetailContext context,
    required DateTime today,
  }) {
    final result = queries.readBudgetDetail(
      budgetID: _budgetID,
      displayedYear: context.displayedYear,
      selectedMonth: context.selectedMonth,
    );
    final detail = result.value;
    final coherent =
        result.state == AnalysisQueryState.ready &&
        result.sourceRevision == currentLedger.revision;

    if (coherent && detail != null) {
      try {
        final accepted = _captureProjection(
          ledger: currentLedger,
          budget: budget,
          projection: detail,
          context: context,
          today: today,
        );
        _accepted = accepted;
        return (
          phase: BudgetDetailPhase.ready,
          projection: accepted,
          error: null,
        );
      } catch (reason) {
        return (
          phase: BudgetDetailPhase.failed,
          projection: _retainedFor(context, currentLedger),
          error: reason,
        );
      }
    }

    final retained = _retainedFor(context, currentLedger);
    if (result.state == AnalysisQueryState.failed) {
      return (
        phase: BudgetDetailPhase.failed,
        projection: retained,
        error: _failureReason(
          budget: budget,
          ledgerState: ledgerState,
          context: context,
          today: today,
          revision: currentLedger.revision,
        ),
      );
    }
    return (
      phase: BudgetDetailPhase.loading,
      projection: retained,
      error: null,
    );
  }

  BudgetDetailProjection? _retainedFor(
    BudgetDetailContext context,
    Ledger currentLedger,
  ) {
    final accepted = _accepted;
    if (accepted == null) return null;
    return accepted.belongsTo(currentLedger, context) ? accepted : null;
  }

  Object _failureReason({
    required Budget budget,
    required LedgerState ledgerState,
    required BudgetDetailContext context,
    required DateTime today,
    required int revision,
  }) {
    final cache = analysisCache;
    final failure = cache.lastFailure;
    if (failure != null && failure.sourceRevision == revision) {
      return failure.error;
    }
    try {
      budgetDetail(
        state: ledgerState,
        items: cache.items,
        budgetID: _budgetID,
        displayedYear: context.displayedYear.year,
        selectedMonth: YearMonth.fromUtc(context.selectedMonth),
        today: today,
      );
      effectiveLimit(budget, YearMonth.fromUtc(today));
    } catch (reason) {
      return reason;
    }
    return StateError('Budget ${budget.id} could not be computed.');
  }

  @override
  void selectMonth(DateTime month) => ref
      .read(budgetDetailContextProvider(_budgetID).notifier)
      .selectMonth(month);

  @override
  void changeYear(DateTime year) => ref
      .read(budgetDetailContextProvider(_budgetID).notifier)
      .changeYear(year);

  @override
  void retry() => ref.read(analysisQueriesProvider)?.retry();

  @override
  void requestLimitEdit() {
    _step = BudgetLimitEditRequested();
    emitStep(BudgetLimitEditRequested());
  }

  @override
  void clearStep() {
    _step = null;
    super.clearStep();
  }
}

// MARK: - Constants
final budgetDetailContextProvider = NotifierProvider.autoDispose
    .family<BudgetDetailContextNotifier, BudgetDetailContext, String>(
      BudgetDetailContextNotifier.new,
    );

final budgetDetailViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<BudgetDetailNotifier, BudgetDetailViewState, String>(
      BudgetDetailNotifier.new,
    );
