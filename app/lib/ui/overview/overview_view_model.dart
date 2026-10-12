import 'package:domain/domain.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/summaries/today_summary.dart';
import 'package:spendwise/ledger/analysis/summaries/upcoming.dart';
import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/base/step_emitting.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

// MARK: - Constants
const _todayLabel = 'Today';
const _captionSeparator = ' / ';
const _planCaption = 'Plan';
const _datedAheadCaption = 'Dated ahead';
const _statementTitleSuffix = 'statement closes';
const _statementCaptionPrefix = 'This cycle so far: ';
const _unnamedCardTitle = 'Card';

// MARK: - OverviewEntryRow
class OverviewEntryRow {
  const OverviewEntryRow({
    required this.title,
    required this.caption,
    required this.symbolName,
    required this.color,
    required this.amount,
    required this.amountKind,
  });

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

// MARK: - OverviewViewState
class OverviewViewState implements HasStep<OverviewViewState, OverviewStep> {
  const OverviewViewState({
    required this.day,
    required this.today,
    required this.recent,
    required this.upcoming,
    this.todayFailed = false,
    this.recordedToday = false,
    this.step,
  });

  final DateTime day;
  final TodaySummary? today;
  final List<OverviewEntryRow>? recent;
  final List<OverviewUpcomingRow>? upcoming;

  final bool todayFailed;
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
        todayFailed: todayFailed,
        recordedToday: recordedToday,
        step: step(),
      );
}

// MARK: - Steps
sealed class OverviewStep {}

class OverviewHistoryRequested extends OverviewStep {}

// MARK: - OverviewViewModel
abstract class OverviewViewModel {
  void retryToday();
  void requestHistory();
  void clearStep();
}

// MARK: - OverviewNotifier
class OverviewNotifier extends AsyncNotifier<OverviewViewState>
    with
        LedgerBackedNotifier<OverviewViewState>,
        StepEmitting<OverviewViewState, OverviewStep>
    implements OverviewViewModel {
  @override
  Future<OverviewViewState> build() async {
    final day = ref.watch(todayProvider);
    final currentLedger = ledger;
    final queries = ref.watch(analysisQueriesProvider);
    final pendingStep = state.value?.step;
    if (queries == null) {
      return OverviewViewState(
        day: day,
        today: null,
        recent: null,
        upcoming: null,
        step: pendingStep,
      );
    }
    final ledgerState = currentLedger.state;
    final recent = queries.readRecent().value;
    final upcoming = queries.readUpcoming().value;
    final today = queries.readToday();
    final todayIsCurrent = today.sourceRevision == currentLedger.revision;
    final newest = recent?.firstOrNull;
    return OverviewViewState(
      day: day,
      today: todayIsCurrent ? today.value : null,
      todayFailed: today.state == AnalysisQueryState.failed,
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
      step: pendingStep,
    );
  }

  @override
  void retryToday() => ref.read(analysisQueriesProvider)?.retry();

  @override
  void requestHistory() => emitStep(OverviewHistoryRequested());
}

OverviewEntryRow _entryRow(Entry entry, LedgerState ledger, DateTime today) {
  final row = transactionRow(entry, ledger);
  final isToday = entry.date == today;
  final date = isToday ? _todayLabel : formatDayMonthShort(entry.date);
  return OverviewEntryRow(
    title: row.note.isEmpty ? row.title : row.note,
    caption: [date, row.title, row.accountLine].join(_captionSeparator),
    symbolName: row.symbolName,
    color: row.color,
    amount: row.amount,
    amountKind: row.amountKind,
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

final overviewViewModelProvider =
    AsyncNotifierProvider<OverviewNotifier, OverviewViewState>(
      OverviewNotifier.new,
    );
