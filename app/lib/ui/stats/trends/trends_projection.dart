import 'package:domain/domain.dart';

import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/analysis/summaries/trends_period.dart';
import 'package:spendwise/ledger/analysis/breakdowns/category_breakdown.dart'
    as analysis;
import 'package:spendwise/ledger/analysis/breakdowns/scoped_trend.dart';
import 'package:spendwise/settings/display_preferences.dart' as settings;
import 'package:spendwise/ui/stats/trends/trends_breakdown.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_usual.dart';

// MARK: - Constants
const _rangeSeparator = ' - ';
const _spentLabel = 'Spent';
const _earnedLabel = 'Earned';
const _noExpensesMessage = 'No expenses recorded';
const _noIncomeMessage = 'No income recorded';
const _pagePrevious = -1;
const _pageNext = 1;
const _fullSharePercent = 100;
const _nextCalendarPeriod = 1;
const _monthsInSpread = 12;
const _monthsBeforeCurrentMonth = 11;

// MARK: - Projection
TrendsBody projectTrends({
  required AnalysisQueries queries,
  required TrendsIntent intent,
  required DateTime today,
  required int ledgerRevision,
  required Map<String, TrendsCategory> categories,
  required TrendsBreakdownPreferences preferences,
}) {
  final currentMonth = monthSerial(today);
  final preflight = queries.readMonthCompleteness(
    month: monthStartOf(currentMonth),
  );
  if (preflight.state == AnalysisQueryState.failed) {
    return const TrendsErrorBody();
  }
  if (preflight.value?.today != today) return const TrendsLoadingBody();
  final first = queries.readFirstRecordMonth();
  final unready = _unready([preflight, first], ledgerRevision);
  if (unready != null) return unready;

  final bounds = TrendsBounds.fromFirstRecord(first.value, currentMonth);
  final context = TrendsContext(currentMonth: currentMonth, bounds: bounds);
  final projection = _Projection(
    queries: queries,
    today: today,
    intent: intent,
    context: context,
    bounds: bounds,
    basis: intent.effective(context),
    reads: [preflight, first],
    firstRecordMonth: first.value,
    isEmpty: first.value == null,
    revision: ledgerRevision,
    categories: categories,
    preferences: preferences,
  );
  return switch (intent.mode) {
    TrendsMode.month => projection.months(),
    TrendsMode.year => projection.years(),
  };
}

TrendsBody? _unready(List<AnalysisQueryResult<Object?>> reads, int revision) {
  final failed = reads.any((read) => read.state == AnalysisQueryState.failed);
  if (failed) return const TrendsErrorBody();
  final coherent = reads.every(
    (read) =>
        read.state == AnalysisQueryState.ready &&
        read.sourceRevision == revision,
  );
  return coherent ? null : const TrendsLoadingBody();
}

// MARK: - Modes
class _Projection {
  const _Projection({
    required this.queries,
    required this.today,
    required this.intent,
    required this.context,
    required this.bounds,
    required this.basis,
    required this.reads,
    required this.firstRecordMonth,
    required this.isEmpty,
    required this.revision,
    required this.categories,
    required this.preferences,
  });

  final AnalysisQueries queries;
  final DateTime today;
  final TrendsIntent intent;
  final TrendsContext context;
  final TrendsBounds bounds;
  final TrendsBasis basis;
  final List<AnalysisQueryResult<Object?>> reads;
  final DateTime? firstRecordMonth;
  final bool isEmpty;
  final int revision;
  final Map<String, TrendsCategory> categories;
  final TrendsBreakdownPreferences preferences;

  CategoryKind get _kind => switch (intent.kind) {
    TrendsKind.expense => CategoryKind.expense,
    TrendsKind.income => CategoryKind.income,
  };

  TrendsBody months() {
    final summary = queries.readTrendsPeriod(
      endMonth: monthStartOf(basis.end),
      kind: _kind,
      level: _level,
    );
    final usual = isEmpty
        ? null
        : queries.readComparedWithUsual(
            month: monthStartOf(basis.selected),
            kind: _kind,
          );
    final breakdown = _readBreakdown();
    final unready = _unready([...reads, summary, ?usual, breakdown], revision);
    if (unready != null) return unready;
    final value = summary.value;
    final usualValue = usual?.value;
    if (value == null || (usual != null && usualValue == null)) {
      return const TrendsErrorBody();
    }
    final current = monthStartOf(context.currentMonth);
    if (value.today != today || value.spread.currentMonth != current) {
      return const TrendsLoadingBody();
    }
    if (!_monthSummaryMatches(
      value,
      basis,
      monthStartOf(bounds.earliestMonthEnd),
      firstRecordMonth,
      _kind,
      _level,
    )) {
      return const TrendsErrorBody();
    }

    final slots = value.spread.slots;
    final period = _periodRow(
      '${formatMonthLabel(slots.first.month)}$_rangeSeparator'
      '${formatMonthLabel(slots.last.month)}',
    );
    final index = basis.selected - (basis.end - (slots.length - 1));
    final selected = slots[index];
    final projected = _breakdown(breakdown.value, selected.total);
    if (projected == null) return const TrendsErrorBody();
    if (isEmpty) return TrendsEmptyBody(period: period, bounds: bounds);
    final bars = [
      for (final slot in slots)
        TrendsBar(
          label: formatMonthInitial(slot.month),
          semanticLabel: formatMonthNameYear(slot.month),
          value: slot.total.toDouble(),
        ),
    ];
    return TrendsReadyBody(
      period: period,
      bars: bars,
      breakdown: projected,
      selectedIndex: index,
      headline: _headline(
        formatMonthNameYear(selected.month),
        selected.total,
        selected.itemCount,
      ),
      usual: trendsUsual(
        usualValue!,
        currentMonth: usualValue.selectedMonth == current,
      ),
      bounds: bounds,
      periodSummary: value,
    );
  }

  bool _monthSummaryMatches(
    MonthTrendsPeriod summary,
    TrendsBasis basis,
    DateTime earliestMonthEnd,
    DateTime? firstRecordMonth,
    CategoryKind kind,
    analysis.BreakdownLevel level,
  ) {
    final slots = summary.spread.slots;
    final breakdown = summary.breakdown;
    final spreadTotal = slots.fold(
      Decimal.zero,
      (total, slot) => total + slot.total,
    );
    final endMonth = monthStartOf(basis.end);
    return slots.length == _monthsInSpread &&
        slots.first.month ==
            DateTime.utc(
              endMonth.year,
              endMonth.month - _monthsBeforeCurrentMonth,
            ) &&
        slots.last.month == endMonth &&
        (summary.highestMonth == null ||
            slots.contains(summary.highestMonth)) &&
        summary.averages.completePeriodCount <= slots.length &&
        _averagesMatchBreakdown(summary) &&
        summary.spread.endMonth == endMonth &&
        summary.spread.kind == kind &&
        summary.spread.earliestSpreadEndMonth == earliestMonthEnd &&
        summary.firstRecordMonth == firstRecordMonth &&
        breakdown.window ==
            DateRange(slots.first.window.start, slots.last.window.end) &&
        breakdown.kind == kind &&
        breakdown.level == level &&
        breakdown.total == spreadTotal;
  }

  bool _averagesMatchBreakdown(MonthTrendsPeriod summary) {
    final rows = summary.breakdown.rows;
    final averages = summary.averages.rows;
    if (rows.length != averages.length) return false;
    for (var index = 0; index < rows.length; index++) {
      if (rows[index].bucketID != averages[index].bucketID ||
          rows[index].mainBucketID != averages[index].mainBucketID ||
          rows[index].isDirect != averages[index].isDirect) {
        return false;
      }
    }
    return true;
  }

  TrendsBody years() {
    final spread = queries.readYearSpread(endYear: basis.end, kind: _kind);
    final breakdown = _readBreakdown();
    final unready = _unready([...reads, spread, breakdown], revision);
    if (unready != null) return unready;
    final value = spread.value;
    if (value == null) return const TrendsErrorBody();
    if (value.currentYear != yearOfMonth(context.currentMonth)) {
      return const TrendsLoadingBody();
    }

    final slots = value.slots;
    final period = _periodRow(
      '${slots.first.year}$_rangeSeparator${slots.last.year}',
    );
    final index = basis.selected - (basis.end - (slots.length - 1));
    final selected = slots[index];
    final projected = _breakdown(breakdown.value, selected.total);
    if (projected == null) return const TrendsErrorBody();
    if (isEmpty) return TrendsEmptyBody(period: period, bounds: bounds);
    final bars = [
      for (final slot in slots)
        TrendsBar(
          label: '${slot.year}',
          semanticLabel: '${slot.year}',
          value: slot.total.toDouble(),
        ),
    ];
    return TrendsReadyBody(
      period: period,
      bars: bars,
      breakdown: projected,
      selectedIndex: index,
      headline: _headline(
        '${selected.year}',
        selected.total,
        selected.itemCount,
      ),
      usual: null,
      bounds: bounds,
    );
  }

  DateTime get _selectedPeriod => switch (intent.mode) {
    TrendsMode.month => monthStartOf(basis.selected),
    TrendsMode.year => DateTime.utc(basis.selected),
  };

  analysis.BreakdownLevel get _level => switch (preferences.level) {
    settings.BreakdownLevel.categories => analysis.BreakdownLevel.categories,
    settings.BreakdownLevel.subcategories =>
      analysis.BreakdownLevel.subcategories,
  };

  AnalysisQueryResult<analysis.PeriodBreakdown> _readBreakdown() {
    final mode = switch (intent.mode) {
      TrendsMode.month => AnalysisPeriodMode.month,
      TrendsMode.year => AnalysisPeriodMode.year,
    };
    return queries.readCategoryBreakdown(
      period: _selectedPeriod,
      mode: mode,
      kind: _kind,
      level: _level,
    );
  }

  TrendsBreakdown? _breakdown(analysis.PeriodBreakdown? value, Decimal total) {
    final period = _selectedPeriod;
    final end = switch (intent.mode) {
      TrendsMode.month => DateTime.utc(
        period.year,
        period.month + _nextCalendarPeriod,
      ),
      TrendsMode.year => DateTime.utc(period.year + _nextCalendarPeriod),
    };
    if (value == null ||
        value.window != DateRange(period, end) ||
        value.kind != _kind ||
        value.level != _level ||
        value.total != total) {
      return null;
    }
    final rowTotal = value.rows.fold(
      Decimal.zero,
      (sum, row) => sum + row.amount,
    );
    final shares = value.rows.fold(
      Decimal.zero,
      (sum, row) => sum + row.sharePercent,
    );
    final expectedShare = value.rows.isEmpty
        ? Decimal.zero
        : Decimal.fromInt(_fullSharePercent);
    if (rowTotal != total || shares != expectedShare) return null;
    if (value.rows.isEmpty) {
      return TrendsEmptyBreakdown(
        sourceRevision: revision,
        period: period,
        kind: _kind,
        mode: intent.mode,
        preferences: preferences,
      );
    }
    final rows = value.rows
        .map(
          (row) => projectBreakdownRow(
            row,
            categories: categories,
            period: period,
            mode: intent.mode,
            kind: _kind,
          ),
        )
        .toList();
    return TrendsBreakdown(
      sourceRevision: revision,
      period: period,
      kind: _kind,
      mode: intent.mode,
      preferences: preferences,
      total: total,
      rows: rows,
    );
  }

  TrendsPeriodRow _periodRow(String rangeLabel) {
    final grid = context.grid(intent.mode);
    return TrendsPeriodRow(
      rangeLabel: rangeLabel,
      previousEnabled: !isEmpty && grid.canPage(basis.end, _pagePrevious),
      nextEnabled: !isEmpty && grid.canPage(basis.end, _pageNext),
    );
  }

  TrendsHeadline _headline(String title, Decimal total, int itemCount) {
    final expense = intent.kind == TrendsKind.expense;
    final kind = expense ? AmountKind.expense : AmountKind.income;
    final sublabel = expense ? _spentLabel : _earnedLabel;
    if (itemCount == 0) {
      return TrendsHeadline(
        title: title,
        sublabel: sublabel,
        amountKind: kind,
        emptyMessage: expense ? _noExpensesMessage : _noIncomeMessage,
      );
    }
    return TrendsHeadline(
      title: title,
      sublabel: sublabel,
      amountKind: kind,
      amount: formatSignedMoney(total, kind: kind),
    );
  }
}
