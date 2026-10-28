import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/settings/display_preferences_providers.dart';
import 'package:spendwise/ui/format/money_format.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/budgets/budget_overview.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_selection.dart';
import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/base/step_emitting.dart';

typedef BudgetListCard = ({
  String id,
  String? savedHex,
  String name,
  String amounts,
  String status,
  double progress,
  bool overLimit,
});
typedef BudgetListSummary = ({
  String? budgetID,
  String remaining,
  String caption,
  String spent,
  String? allowance,
  double? progress,
  bool overLimit,
});

const _emptyProgress = 0.0;
const _fullProgress = 1.0;
const _percentScale = 100;
const _percentDigits = 1;

// MARK: - BudgetsListViewState
class BudgetsListViewState
    implements HasStep<BudgetsListViewState, BudgetsStep> {
  const BudgetsListViewState({
    this.overview,
    this.cards = const [],
    this.loading = false,
    this.error,
    required this.today,
    this.chartColours = ChartColours.categoryColours,
    this.selectedBudgetID,
    this.step,
  });

  final BudgetsOverview? overview;
  final List<BudgetListCard> cards;
  final bool loading;
  final Object? error;
  final DateTime today;
  final ChartColours chartColours;
  final String? selectedBudgetID;
  @override
  final BudgetsStep? step;

  BudgetListSummary get summary {
    final all = overview!.allSpending;
    final cap = all.cap;
    final remaining = all.remaining;
    final allowance = all.dailyAllowance;
    final tomorrow = today.add(const Duration(days: 1));
    return (
      budgetID: all.capBudgetID,
      remaining: remaining == null
          ? 'No spending limit'
          : formatMoney(remaining),
      caption: cap == null
          ? ''
          : 'left of ${formatMoney(cap)} this month'
                '${all.capBudgetID == null ? ' (category limits)' : ''}',
      spent: formatMoney(all.spent),
      allowance: allowance == null
          ? null
          : 'From ${DateFormat('d MMMM').format(tomorrow)}: about ${formatMoney(allowance)} a day.',
      progress: cap == null
          ? null
          : (all.spent / cap).toDouble().clamp(_emptyProgress, _fullProgress),
      overLimit: remaining != null && remaining < Decimal.zero,
    );
  }

  BudgetsListViewState copyWith({BudgetsStep? Function()? step}) {
    return BudgetsListViewState(
      overview: overview,
      cards: cards,
      loading: loading,
      error: error,
      today: today,
      chartColours: chartColours,
      selectedBudgetID: selectedBudgetID,
      step: step == null ? this.step : step(),
    );
  }

  @override
  BudgetsListViewState withStep(BudgetsStep? Function() step) =>
      copyWith(step: step);
}

// MARK: - BudgetsListViewModel
abstract class BudgetsListViewModel {
  void requestBudgetDetail(String budgetID);
  void requestNewBudget();

  void deleteBudget(String id);
  void retry();
  void clearStep();
}

// MARK: - BudgetsListNotifier
class BudgetsListNotifier extends AsyncNotifier<BudgetsListViewState>
    with
        LedgerBackedNotifier<BudgetsListViewState>,
        StepEmitting<BudgetsListViewState, BudgetsStep>
    implements BudgetsListViewModel {
  BudgetsStep? _step;

  @override
  BudgetsListViewState build() {
    final currentLedger = ledger;
    final queries = ref.watch(analysisQueriesProvider);
    if (queries == null) throw StateError('Budgets requires analysis queries.');
    final month = ref.watch(effectiveMonthProvider);
    final today = ref.watch(todayProvider);
    final result = queries.readBudgets(month: month);
    final chartColours = ref.watch(
      displayPreferencesProvider.select((value) => value.chartColours),
    );
    final selection = ref.watch(selectedBudgetProvider);
    Object? error;
    if (result.state == AnalysisQueryState.failed) {
      error = analysisCache.lastFailure?.error;
      if (error == null) {
        try {
          budgetsOverview(
            state: currentLedger.state,
            items: analysisCache.items,
            month: YearMonth.fromUtc(month),
            today: today,
          );
        } catch (reason) {
          error = reason;
        }
      }
    }
    return BudgetsListViewState(
      overview: result.value,
      cards: result.value == null
          ? const []
          : _cardRows(result.value!, currentLedger.state),
      loading: result.state == AnalysisQueryState.loading,
      error: error,
      today: today,
      chartColours: chartColours,
      selectedBudgetID: selection?.budgetID,
      step: _step,
    );
  }

  List<BudgetListCard> _cardRows(
    BudgetsOverview overview,
    LedgerState ledgerState,
  ) => [
    for (final row in overview.categoryBudgets)
      (
        id: row.budgetID,
        savedHex: ledgerState.categories[row.categoryID]?.colorHex,
        name: row.parentName == null
            ? row.name
            : '${row.parentName} / ${row.name}',
        amounts: '${formatMoney(row.spend)} of ${formatMoney(row.limit)}',
        status:
            '${formatMoney(row.remaining)} left / '
            '${(row.utilizationRatio.toDouble() * _percentScale).toStringAsFixed(_percentDigits)}% used',
        progress: row.utilizationRatio.toDouble(),
        overLimit: row.remaining < Decimal.zero,
      ),
  ];

  @override
  void retry() => ref.read(analysisQueriesProvider)?.retry();

  @override
  void requestBudgetDetail(String budgetID) {
    _step = BudgetDetailRequested(budgetID);
    emitStep(BudgetDetailRequested(budgetID));
    ref.read(selectedBudgetProvider.notifier).select(budgetID);
  }

  @override
  void requestNewBudget() {
    _step = BudgetFormRequested();
    emitStep(BudgetFormRequested());
  }

  @override
  void deleteBudget(String id) => ledger.deleteBudget(id);

  @override
  void clearStep() {
    _step = null;
    super.clearStep();
  }
}

// MARK: - Constants
final budgetsListViewModelProvider =
    AsyncNotifierProvider<BudgetsListNotifier, BudgetsListViewState>(
      BudgetsListNotifier.new,
    );
