import 'package:domain/domain.dart';

import 'package:spendwise/ledger/analysis/insights/insight_rules.dart';
import 'package:spendwise/ledger/analysis/insights/matched_day_insights.dart';
import 'package:spendwise/ledger/analysis/summaries/week_so_far.dart';
import 'package:spendwise/ui/format/analysis_bucket_name.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';

// MARK: - Constants
const _higherTail = ' higher than your usual start.';
const _lowerTail = ' lower than your usual start.';
const _moreThanUsual = ' more than usual';
const _lessThanUsual = ' less than usual';
const _singularVerb = ' is ';
const _pluralVerb = ' are ';
const _captionSeparator = ' / ';
const _dayUnit = 'day';
const _daysUnit = 'days';
const _usualNotePrefix = 'Usual is ';
const _usualNoteMiddle = ', the average of ';
const _usualNoteAnd = ' and ';
const _usualNoteSeparator = ', ';
const _usualNoteSuffix = ' over the same days of the last three weeks.';
const _mondayDayCount = 1;

// MARK: - Types
sealed class OverviewInsights {
  const OverviewInsights();
}

class OverviewInsightsHistoryNeeded extends OverviewInsights {
  const OverviewInsightsHistoryNeeded();
}

class OverviewInsightsAvailable extends OverviewInsights {
  const OverviewInsightsAvailable({required this.rows});

  final List<OverviewInsightRow> rows;
}

class OverviewInsightRow {
  const OverviewInsightRow({
    required this.lead,
    required this.amount,
    required this.tail,
    required this.amountKind,
  });

  final String lead;
  final String amount;
  final String tail;
  final AmountKind amountKind;
}

sealed class OverviewWeekSoFar {
  const OverviewWeekSoFar();
}

class OverviewWeekHistoryNeeded extends OverviewWeekSoFar {
  const OverviewWeekHistoryNeeded();
}

class OverviewWeekAvailable extends OverviewWeekSoFar {
  const OverviewWeekAvailable({
    required this.range,
    required this.total,
    required this.comparison,
    required this.usualNote,
    required this.totalTone,
  });

  final String range;
  final String total;
  final String? comparison;
  final AmountKind? totalTone;
  final String usualNote;
}

// MARK: - Insights
OverviewInsights overviewInsights(
  MatchedDayInsights insights,
  LedgerState state,
) {
  if (insights.state == InsightState.historyNeeded) {
    return const OverviewInsightsHistoryNeeded();
  }
  return OverviewInsightsAvailable(
    rows: [for (final change in insights.changes) _insightRow(change, state)],
  );
}

OverviewInsightRow _insightRow(CategoryChange change, LedgerState state) {
  final bucketID = change.bucketID;
  final name = state.categories[bucketID]?.name ?? analysisBucketName(bucketID);
  final isPlural =
      bucketID != null && syntheticTransferExpenseAccountType(bucketID) != null;
  final higher = change.difference > Decimal.zero;
  return OverviewInsightRow(
    lead: '$name${isPlural ? _pluralVerb : _singularVerb}',
    amount: formatMoney(change.difference.abs()),
    tail: higher ? _higherTail : _lowerTail,
    amountKind: higher ? AmountKind.expense : AmountKind.income,
  );
}

// MARK: - Week so far
OverviewWeekSoFar overviewWeekSoFar(WeekSoFar week) {
  if (week.state == InsightState.historyNeeded) {
    return const OverviewWeekHistoryNeeded();
  }
  return OverviewWeekAvailable(
    range: _weekRange(week),
    total: formatMoney(week.observedTotal),
    comparison: _weekComparison(week),
    usualNote: _usualNote(week),
    totalTone: _weekTotalTone(week),
  );
}

AmountKind? _weekTotalTone(WeekSoFar week) {
  final difference = week.difference;
  if (!week.qualifies || difference == null) return null;
  return difference > Decimal.zero ? AmountKind.expense : AmountKind.income;
}

String _weekRange(WeekSoFar week) {
  final days = week.elapsedDayCount;
  if (days == _mondayDayCount) {
    return '${formatDayMonthShort(week.weekStart)}$_captionSeparator'
        '$days $_dayUnit';
  }
  return '${formatWeekRange(week.observedWindow)}$_captionSeparator'
      '$days $_daysUnit';
}

String? _weekComparison(WeekSoFar week) {
  final difference = week.difference;
  if (!week.qualifies || difference == null) return null;
  final tail = difference > Decimal.zero ? _moreThanUsual : _lessThanUsual;
  return '${formatMoney(difference.abs())}$tail';
}

String _usualNote(WeekSoFar week) {
  final mean = formatMoney(week.usualMean ?? Decimal.zero);
  final totals = [
    for (final record in week.baselineEvidence) formatMoney(record.total),
  ];
  final last = totals.removeLast();
  final leading = totals.join(_usualNoteSeparator);
  return '$_usualNotePrefix$mean$_usualNoteMiddle$leading$_usualNoteAnd$last'
      '$_usualNoteSuffix';
}
