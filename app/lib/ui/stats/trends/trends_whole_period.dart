import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/summaries/trends_period.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';

const _notEnoughData = 'Not enough data';
const _observationSeparator = ' - ';
const _amountSeparator = ': ';

@immutable
class TrendsBreakdownHeader {
  const TrendsBreakdownHeader({
    required this.title,
    required this.range,
    required this.total,
  });

  final String title;
  final String range;
  final String total;
}

@immutable
class TrendsInsight {
  const TrendsInsight({required this.title, required this.value});

  final String title;
  final String value;
}

@immutable
class TrendsInsights {
  TrendsInsights({required List<TrendsInsight> observations})
    : observations = List.unmodifiable(observations);

  final List<TrendsInsight> observations;

  String? get emptyMessage => observations.isEmpty ? _notEnoughData : null;
}

@immutable
class TrendsWholePeriod {
  const TrendsWholePeriod({
    required this.breakdown,
    required this.header,
    required this.insights,
  });

  final TrendsBreakdown breakdown;
  final TrendsBreakdownHeader header;
  final TrendsInsights insights;
}

TrendsWholePeriod projectWholePeriod(
  TrendsPeriod summary, {
  required Map<String, TrendsCategory> categories,
  required TrendsBreakdownPreferences preferences,
  required DateTime period,
  required TrendsMode mode,
  required CategoryKind kind,
  required int revision,
  required String rangeLabel,
}) {
  final source = summary.breakdown;
  final amountKind = _amountKind(kind);
  final rows = [
    for (final row in source.rows)
      projectBreakdownRow(
        row,
        categories: categories,
        period: period,
        mode: mode,
        kind: kind,
      ),
  ];
  final breakdown = rows.isEmpty
      ? TrendsEmptyBreakdown(
          sourceRevision: revision,
          period: period,
          kind: kind,
          mode: mode,
          preferences: preferences,
        )
      : TrendsBreakdown(
          sourceRevision: revision,
          period: period,
          kind: kind,
          mode: mode,
          preferences: preferences,
          total: source.total,
          rows: rows,
        );
  final header = TrendsBreakdownHeader(
    title: kind == CategoryKind.income
        ? 'Income breakdown'
        : 'Expense breakdown',
    range: rangeLabel,
    total: formatSignedMoney(source.total, kind: amountKind),
  );
  final largest = rows.isEmpty ? null : _largestInsight(rows.first, kind);
  final highest = _highestInsight(summary, kind);
  final insights = TrendsInsights(observations: [?largest, ?highest]);
  return TrendsWholePeriod(
    breakdown: breakdown,
    header: header,
    insights: insights,
  );
}

AmountKind _amountKind(CategoryKind kind) =>
    kind == CategoryKind.income ? AmountKind.income : AmountKind.expense;

TrendsInsight _largestInsight(TrendsBreakdownRow row, CategoryKind kind) {
  final noun = kind == CategoryKind.income ? 'income' : 'expense';
  return TrendsInsight(
    title: 'Largest $noun category',
    value: '${row.name}$_observationSeparator${row.formattedShare}',
  );
}

TrendsInsight? _highestInsight(TrendsPeriod summary, CategoryKind kind) {
  final noun = kind == CategoryKind.income ? 'income' : 'spending';
  final amountKind = _amountKind(kind);
  switch (summary) {
    case MonthTrendsPeriod(:final highestMonth?):
      return TrendsInsight(
        title: 'Highest $noun month',
        value:
            '${formatMonthNameYear(highestMonth.month)}'
            '$_amountSeparator'
            '${formatSignedMoney(highestMonth.total, kind: amountKind)}',
      );
    case YearTrendsPeriod(:final highestYear?):
      return TrendsInsight(
        title: 'Highest $noun year',
        value:
            '${highestYear.year}$_amountSeparator'
            '${formatSignedMoney(highestYear.total, kind: amountKind)}',
      );
    default:
      return null;
  }
}
