import 'package:domain/domain.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/insights/insight_rules.dart';
import 'package:spendwise/ledger/analysis/insights/matched_day_insights.dart';
import 'package:spendwise/ledger/analysis/summaries/period_summary.dart';
import 'package:spendwise/ledger/analysis/summaries/today_summary.dart';
import 'package:spendwise/ledger/analysis/summaries/upcoming.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_list_cards.dart';
import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/base/step_emitting.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/overview/overview_card_statement_mapping.dart';
import 'package:spendwise/ui/overview/overview_insights_mapping.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

// MARK: - Constants
const _todayLabel = 'Today';
const _captionSeparator = ' / ';
const _planCaption = 'Plan';
const _datedAheadCaption = 'Dated ahead';
const _statementTitleSuffix = 'statement closes';
const _statementCaptionPrefix = 'This cycle so far: ';
const _unnamedCardTitle = 'Card';
const _budgetWatchRowLimit = 3;

// MARK: - OverviewEntryRow
class OverviewEntryRow {
  const OverviewEntryRow({
    required this.entryId,
    required this.title,
    required this.caption,
    required this.symbolName,
    required this.color,
    required this.amount,
    required this.amountKind,
  });

  final String entryId;
  final String title;
  final String caption;
  final String symbolName;
  final Color color;
  final Decimal amount;
  final AmountKind amountKind;
}

// MARK: - OverviewUpcomingRow
class OverviewUpcomingRow {
  const OverviewUpcomingRow({
    required this.day,
    required this.month,
    required this.title,
    required this.caption,
    this.amount,
    this.amountKind,
  });

  final String day;
  final String month;
  final String title;
  final String caption;
  final Decimal? amount;
  final AmountKind? amountKind;
}

// MARK: - OverviewThisMonth
class OverviewMonthFigures {
  const OverviewMonthFigures({
    required this.spent,
    required this.income,
    required this.net,
    required this.netKind,
  });

  final String spent;
  final String income;
  final String net;
  final AmountKind netKind;
}

class OverviewThisMonth {
  const OverviewThisMonth({required this.caption, required this.figures});

  final String caption;
  final OverviewMonthFigures? figures;
}

// MARK: - OverviewViewState
class OverviewViewState implements HasStep<OverviewViewState, OverviewStep> {
  const OverviewViewState({
    required this.day,
    required this.today,
    required this.recent,
    required this.upcoming,
    required this.thisMonth,
    this.budgetWatch,
    this.insights,
    this.weekSoFar,
    this.cardStatements,
    this.todayFailed = false,
    this.thisMonthFailed = false,
    this.budgetWatchFailed = false,
    this.insightsFailed = false,
    this.insightsSettledEmpty = false,
    this.weekSoFarFailed = false,
    this.recordedToday = false,
    this.step,
  });

  final DateTime day;
  final TodaySummary? today;
  final List<OverviewEntryRow>? recent;
  final List<OverviewUpcomingRow>? upcoming;
  final OverviewThisMonth? thisMonth;
  final List<BudgetListCard>? budgetWatch;
  final OverviewInsights? insights;
  final OverviewWeekSoFar? weekSoFar;
  final List<OverviewCardStatementRow>? cardStatements;

  final bool todayFailed;
  final bool thisMonthFailed;
  final bool budgetWatchFailed;
  final bool insightsFailed;
  final bool insightsSettledEmpty;
  final bool weekSoFarFailed;
  final bool recordedToday;
  @override
  final OverviewStep? step;

  @override
  OverviewViewState withStep(OverviewStep? Function() step) =>
      OverviewViewState(
        day: day,
        today: today,
        recent: recent,
        upcoming: upcoming,
        thisMonth: thisMonth,
        budgetWatch: budgetWatch,
        insights: insights,
        weekSoFar: weekSoFar,
        cardStatements: cardStatements,
        todayFailed: todayFailed,
        thisMonthFailed: thisMonthFailed,
        budgetWatchFailed: budgetWatchFailed,
        insightsFailed: insightsFailed,
        insightsSettledEmpty: insightsSettledEmpty,
        weekSoFarFailed: weekSoFarFailed,
        recordedToday: recordedToday,
        step: step(),
      );
}

// MARK: - Steps
sealed class OverviewStep {}

class OverviewHistoryRequested extends OverviewStep {}

class OverviewBudgetsRequested extends OverviewStep {}

class OverviewTrendsRequested extends OverviewStep {}

class OverviewBudgetRequested extends OverviewStep {
  OverviewBudgetRequested(this.budgetID);

  final String budgetID;
}

class OverviewEditOverviewRequested extends OverviewStep {}

class OverviewEntryRequested extends OverviewStep {
  OverviewEntryRequested(this.entryId);

  final String entryId;
}

// MARK: - OverviewViewModel
abstract class OverviewViewModel {
  void retryReads();
  void requestHistory();
  void requestBudgets();
  void requestTrends();
  void requestEditOverview();
  void openEntry(String id);
  void openBudget(String budgetID);
  void clearStep();
}

// MARK: - OverviewNotifier
class OverviewNotifier extends AsyncNotifier<OverviewViewState>
    with
        LedgerBackedNotifier<OverviewViewState>,
        StepEmitting<OverviewViewState, OverviewStep>
    implements OverviewViewModel {
  @override
  OverviewViewState build() {
    final day = ref.watch(todayProvider);
    final currentLedger = ledger;
    final queries = analysisQueries;
    final ledgerState = currentLedger.state;
    final recent = queries.readRecent().value;
    final upcoming = queries.readUpcoming().value;
    final today = queries.readToday();
    final todayIsCurrent = today.sourceRevision == currentLedger.revision;
    final newest = recent?.firstOrNull;
    final month = monthWindow(day);
    final period = queries.readPeriod(window: month);
    final monthEntries = queries.readRegisterDays(window: month).value;
    final periodSummary = period.value;
    final periodIsCurrent = period.sourceRevision == currentLedger.revision;
    final thisMonth = periodIsCurrent && periodSummary != null
        ? _thisMonth(
            periodSummary,
            monthEntries?.isNotEmpty ?? true,
            month.start,
          )
        : null;
    final budgets = queries.readBudgets(month: month.start);
    final overview = budgets.value;
    final budgetsAreCurrent = budgets.sourceRevision == currentLedger.revision;
    final budgetWatch = budgetsAreCurrent && overview != null
        ? budgetListCards(
            overview.categoryBudgets.take(_budgetWatchRowLimit),
            ledgerState,
          )
        : null;
    final insightsRead = queries.readMatchedDayInsights();
    final insightsValue = insightsRead.value;
    final insightsAreCurrent =
        insightsRead.sourceRevision == currentLedger.revision;
    final insightsFailed = insightsRead.state == AnalysisQueryState.failed;
    final weekRead = queries.readWeekSoFar();
    final weekValue = weekRead.value;
    final weekIsCurrent = weekRead.sourceRevision == currentLedger.revision;
    final payableCards = queries.readPayableCards().value;
    return OverviewViewState(
      day: day,
      today: todayIsCurrent ? today.value : null,
      todayFailed: today.state == AnalysisQueryState.failed,
      thisMonth: thisMonth,
      thisMonthFailed: period.state == AnalysisQueryState.failed,
      budgetWatch: budgetWatch,
      budgetWatchFailed: budgets.state == AnalysisQueryState.failed,
      insights: insightsAreCurrent && insightsValue != null
          ? overviewInsights(insightsValue, ledgerState)
          : null,
      insightsFailed: insightsFailed,
      insightsSettledEmpty: _isSettledEmpty(insightsValue, insightsFailed),
      weekSoFar: weekIsCurrent && weekValue != null
          ? overviewWeekSoFar(weekValue)
          : null,
      weekSoFarFailed: weekRead.state == AnalysisQueryState.failed,
      cardStatements: payableCards == null
          ? null
          : overviewCardStatements(payableCards),
      recordedToday: newest?.entry.date == day,
      recent: recent == null
          ? null
          : [
              for (final record in recent)
                _entryRow(record.entry, ledgerState, day),
            ],
      upcoming: upcoming == null
          ? null
          : [for (final item in upcoming) _upcomingRow(item, ledgerState)],
      step: state.value?.step,
    );
  }

  @override
  void retryReads() => ref.read(analysisQueriesProvider)?.retry();

  @override
  void requestHistory() => emitStep(OverviewHistoryRequested());

  @override
  void requestBudgets() => emitStep(OverviewBudgetsRequested());

  @override
  void requestTrends() => emitStep(OverviewTrendsRequested());

  @override
  void requestEditOverview() => emitStep(OverviewEditOverviewRequested());

  @override
  void openEntry(String id) {
    final isActive =
        ref.read(ledgerSessionProvider)?.ledger.state.entries.containsKey(id) ??
        false;
    if (!isActive) return;
    emitStep(OverviewEntryRequested(id));
  }

  @override
  void openBudget(String budgetID) {
    final exists =
        ref
            .read(ledgerSessionProvider)
            ?.ledger
            .state
            .budgets
            .containsKey(budgetID) ??
        false;
    if (!exists) return;
    emitStep(OverviewBudgetRequested(budgetID));
  }
}

// MARK: - Row Mapping
OverviewEntryRow _entryRow(Entry entry, LedgerState ledger, DateTime today) {
  final row = transactionRow(entry, ledger);
  final isToday = entry.date == today;
  final date = isToday ? _todayLabel : formatDayMonthShort(entry.date);
  return OverviewEntryRow(
    entryId: entry.id,
    title: row.note.isEmpty ? row.title : row.note,
    caption: [date, row.title, row.accountLine].join(_captionSeparator),
    symbolName: row.symbolName,
    color: row.color,
    amount: row.amount,
    amountKind: row.amountKind,
  );
}

bool _isSettledEmpty(MatchedDayInsights? settled, bool failed) =>
    !failed &&
    settled != null &&
    settled.state == InsightState.available &&
    settled.changes.isEmpty;

AmountKind _netKind(Decimal net) {
  if (net > Decimal.zero) return AmountKind.income;
  if (net < Decimal.zero) return AmountKind.expense;
  return AmountKind.transfer;
}

OverviewThisMonth _thisMonth(
  PeriodSummary summary,
  bool hasEntries,
  DateTime monthStart,
) {
  final figures = OverviewMonthFigures(
    spent: formatSignedMoney(-summary.spent, symbol: false),
    income: formatSignedMoney(summary.income, symbol: false),
    net: formatSignedMoney(summary.net, symbol: false),
    netKind: _netKind(summary.net),
  );
  return OverviewThisMonth(
    caption: formatMonthName(monthStart),
    figures: hasEntries ? figures : null,
  );
}

OverviewUpcomingRow _upcomingRow(UpcomingItem item, LedgerState ledger) {
  final day = '${item.date.day}';
  final month = formatMonthShort(item.date);
  return switch (item) {
    UpcomingStatement() => OverviewUpcomingRow(
      day: day,
      month: month,
      title: '${item.accountName ?? _unnamedCardTitle} $_statementTitleSuffix',
      caption: '$_statementCaptionPrefix${formatMoney(item.cycleAmount)}',
    ),
    UpcomingPlan(:final occurrence) => _datedRow(
      occurrence.projected.entry,
      ledger,
      day,
      month,
      _planCaption,
    ),
    UpcomingEntry(:final record) => _datedRow(
      record.entry,
      ledger,
      day,
      month,
      _datedAheadCaption,
    ),
  };
}

OverviewUpcomingRow _datedRow(
  Entry entry,
  LedgerState ledger,
  String day,
  String month,
  String origin,
) {
  final row = transactionRow(entry, ledger);
  return OverviewUpcomingRow(
    day: day,
    month: month,
    title: row.note.isEmpty ? row.title : row.note,
    caption: '$origin$_captionSeparator${row.accountLine}',
    amount: row.amount,
    amountKind: row.amountKind,
  );
}

// MARK: - Constants
final overviewViewModelProvider =
    AsyncNotifierProvider.autoDispose<OverviewNotifier, OverviewViewState>(
      OverviewNotifier.new,
      retry: (_, _) => null,
    );
