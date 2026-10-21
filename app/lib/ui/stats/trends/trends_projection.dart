import 'package:domain/domain.dart';

import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
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

// MARK: - Projection
TrendsBody projectTrends({
  required AnalysisQueries queries,
  required TrendsIntent intent,
  required DateTime today,
  required int ledgerRevision,
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
    intent: intent,
    context: context,
    bounds: bounds,
    basis: intent.effective(context),
    reads: [preflight, first],
    isEmpty: first.value == null,
    revision: ledgerRevision,
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
    required this.intent,
    required this.context,
    required this.bounds,
    required this.basis,
    required this.reads,
    required this.isEmpty,
    required this.revision,
  });

  final AnalysisQueries queries;
  final TrendsIntent intent;
  final TrendsContext context;
  final TrendsBounds bounds;
  final TrendsBasis basis;
  final List<AnalysisQueryResult<Object?>> reads;
  final bool isEmpty;
  final int revision;

  CategoryKind get _kind => switch (intent.kind) {
    TrendsKind.expense => CategoryKind.expense,
    TrendsKind.income => CategoryKind.income,
  };

  TrendsBody months() {
    final spread = queries.readMonthSpread(
      endMonth: monthStartOf(basis.end),
      kind: _kind,
    );
    final usual = isEmpty
        ? null
        : queries.readComparedWithUsual(
            month: monthStartOf(basis.selected),
            kind: _kind,
          );
    final unready = _unready([...reads, spread, ?usual], revision);
    if (unready != null) return unready;
    final value = spread.value;
    final usualValue = usual?.value;
    if (value == null || (usual != null && usualValue == null)) {
      return const TrendsErrorBody();
    }
    final current = monthStartOf(context.currentMonth);
    if (value.currentMonth != current) return const TrendsLoadingBody();

    final slots = value.slots;
    final period = _periodRow(
      '${formatMonthLabel(slots.first.month)}$_rangeSeparator'
      '${formatMonthLabel(slots.last.month)}',
    );
    if (isEmpty) return TrendsEmptyBody(period: period, bounds: bounds);
    final index = basis.selected - (basis.end - (slots.length - 1));
    final selected = slots[index];
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
    );
  }

  TrendsBody years() {
    final spread = queries.readYearSpread(endYear: basis.end, kind: _kind);
    final unready = _unready([...reads, spread], revision);
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
    if (isEmpty) return TrendsEmptyBody(period: period, bounds: bounds);
    final index = basis.selected - (basis.end - (slots.length - 1));
    final selected = slots[index];
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
