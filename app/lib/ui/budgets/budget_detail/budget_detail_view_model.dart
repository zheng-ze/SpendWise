import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
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

// MARK: - Labels
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

// MARK: - Snapshot
@immutable
class BudgetDetailSnapshot {
  const BudgetDetailSnapshot({
    required this.ledger,
    required this.ledgerState,
    required this.budget,
    required this.projection,
    required this.categoryName,
    required this.countedEntries,
    required this.hasCountedEntries,
    required this.selectedLimit,
    required this.currentLimit,
    required this.displayedYear,
    required this.selectedMonth,
    required this.months,
  });

  final Ledger ledger;
  final LedgerState ledgerState;
  final Budget budget;
  final BudgetDetail projection;
  final String? categoryName;
  final List<BudgetCountedEntry> countedEntries;
  final bool hasCountedEntries;
  final Decimal selectedLimit;
  final Decimal currentLimit;
  final DateTime displayedYear;
  final DateTime selectedMonth;
  final List<DateTime> months;

  String get title => categoryName ?? _overallTitle;

  Decimal get spent => budgetCountedTotal(countedEntries);

  List<Decimal> get spendSeries => [
    for (final slot in projection.slots) slot.spend,
  ];

  double get chartMaxYValue => chartMaxY(spendSeries, [currentLimit]);
}

BudgetDetailSnapshot _captureSnapshot({
  required Ledger ledger,
  required LedgerState ledgerState,
  required Budget budget,
  required BudgetDetail projection,
  required BudgetDetailContext context,
  required DateTime today,
}) {
  final summary = projection.summary;
  if (summary == null) {
    throw StateError('Budget ${budget.id} has no detail summary.');
  }
  final selected = YearMonth.fromUtc(context.selectedMonth);
  return BudgetDetailSnapshot(
    ledger: ledger,
    ledgerState: ledgerState,
    budget: budget,
    projection: projection,
    categoryName: _categoryName(budget, ledgerState),
    countedEntries: budgetCountedEntries(budget, selected, ledgerState),
    hasCountedEntries: budgetHasCountedEntries(budget, ledgerState),
    selectedLimit: summary.limit,
    currentLimit: effectiveLimit(budget, YearMonth.fromUtc(today)),
    displayedYear: context.displayedYear,
    selectedMonth: context.selectedMonth,
    months: trendMonths(context.displayedYear, isYearRange: true),
  );
}

// MARK: - BudgetDetailViewState
enum BudgetDetailPhase { loading, ready, failed, deleted }

class BudgetDetailViewState
    implements HasStep<BudgetDetailViewState, BudgetsStep> {
  const BudgetDetailViewState({
    required this.phase,
    required this.title,
    required this.displayedYear,
    required this.selectedMonth,
    this.snapshot,
    this.error,
    this.step,
  });

  final BudgetDetailPhase phase;
  final String title;
  final DateTime displayedYear;
  final DateTime selectedMonth;
  final BudgetDetailSnapshot? snapshot;
  final Object? error;
  @override
  final BudgetsStep? step;

  BudgetDetailViewState copyWith({BudgetsStep? Function()? step}) {
    return BudgetDetailViewState(
      phase: phase,
      title: title,
      displayedYear: displayedYear,
      selectedMonth: selectedMonth,
      snapshot: snapshot,
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

// MARK: - BudgetDetailNotifier
class BudgetDetailNotifier extends AsyncNotifier<BudgetDetailViewState>
    with
        LedgerBackedNotifier<BudgetDetailViewState>,
        StepEmitting<BudgetDetailViewState, BudgetsStep>
    implements BudgetDetailViewModel {
  BudgetDetailNotifier(this._budgetID);

  final String _budgetID;

  BudgetsStep? _step;

  BudgetDetailSnapshot? _accepted;

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
      return _viewState(BudgetDetailPhase.deleted, context, title: '');
    }

    final title = _categoryName(budget, ledgerState) ?? _overallTitle;
    final result = queries.readBudgetDetail(
      budgetID: _budgetID,
      displayedYear: context.displayedYear,
      selectedMonth: context.selectedMonth,
    );
    final projection = result.value;
    final coherent =
        result.state == AnalysisQueryState.ready &&
        result.sourceRevision == currentLedger.revision;

    if (coherent && projection != null) {
      try {
        final snapshot = _captureSnapshot(
          ledger: currentLedger,
          ledgerState: ledgerState,
          budget: budget,
          projection: projection,
          context: context,
          today: today,
        );
        _accepted = snapshot;
        return _viewState(
          BudgetDetailPhase.ready,
          context,
          title: snapshot.title,
          snapshot: snapshot,
        );
      } catch (reason) {
        return _viewState(
          BudgetDetailPhase.failed,
          context,
          title: title,
          snapshot: _retainedFor(context, currentLedger),
          error: reason,
        );
      }
    }

    final retained = _retainedFor(context, currentLedger);
    if (result.state == AnalysisQueryState.failed) {
      return _viewState(
        BudgetDetailPhase.failed,
        context,
        title: title,
        snapshot: retained,
        error: _failureReason(
          budget: budget,
          ledgerState: ledgerState,
          context: context,
          today: today,
          revision: currentLedger.revision,
        ),
      );
    }
    return _viewState(
      BudgetDetailPhase.loading,
      context,
      title: title,
      snapshot: retained,
    );
  }

  BudgetDetailSnapshot? _retainedFor(
    BudgetDetailContext context,
    Ledger currentLedger,
  ) {
    final accepted = _accepted;
    if (accepted == null || !identical(accepted.ledger, currentLedger)) {
      return null;
    }
    final sameMonth =
        accepted.selectedMonth == context.selectedMonth &&
        accepted.displayedYear == context.displayedYear;
    return sameMonth ? accepted : null;
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

  BudgetDetailViewState _viewState(
    BudgetDetailPhase phase,
    BudgetDetailContext context, {
    required String title,
    BudgetDetailSnapshot? snapshot,
    Object? error,
  }) {
    return BudgetDetailViewState(
      phase: phase,
      title: title,
      displayedYear: context.displayedYear,
      selectedMonth: context.selectedMonth,
      snapshot: snapshot,
      error: error,
      step: _step,
    );
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
