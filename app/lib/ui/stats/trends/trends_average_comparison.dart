import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/summaries/trends_period.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';

const _monthlyAverageLabel = 'Monthly average';
const _yearlyAverageLabel = 'Yearly average';
const _unavailableMean = 'Unavailable';

typedef TrendsBreakdownIdentity = ({
  String? bucketID,
  String? mainBucketID,
  bool isDirect,
});

@immutable
class TrendsAverageComparisonRow {
  const TrendsAverageComparisonRow({
    required this.bucketID,
    required this.mainBucketID,
    required this.isDirect,
    required this.mean,
    required this.formattedMean,
  });

  final String? bucketID;
  final String? mainBucketID;
  final bool isDirect;
  final Decimal? mean;
  final String formattedMean;
}

@immutable
class TrendsAverageComparison {
  TrendsAverageComparison({
    required this.header,
    required List<TrendsAverageComparisonRow> rows,
  }) : rows = List.unmodifiable(rows);

  final String header;
  final List<TrendsAverageComparisonRow> rows;
}

TrendsAverageComparison? projectTrendsAverageComparison({
  required TrendsBreakdown breakdown,
  required List<CategoryPeriodAverage> averages,
  required TrendsMode mode,
  required CategoryKind kind,
}) {
  final averageByIdentity = <TrendsBreakdownIdentity, CategoryPeriodAverage>{};
  for (final average in averages) {
    final identity = _identity(
      average.bucketID,
      average.mainBucketID,
      average.isDirect,
    );
    if (averageByIdentity.containsKey(identity)) return null;
    averageByIdentity[identity] = average;
  }

  final selectedIdentities = <TrendsBreakdownIdentity>{};
  final rows = <TrendsAverageComparisonRow>[];
  for (final row in breakdown.rows) {
    final identity = _identity(row.bucketID, row.mainBucketID, row.isDirect);
    if (!selectedIdentities.add(identity)) return null;
    final average = averageByIdentity[identity];
    if (average == null) return null;
    rows.add(
      TrendsAverageComparisonRow(
        bucketID: row.bucketID,
        mainBucketID: row.mainBucketID,
        isDirect: row.isDirect,
        mean: average.mean,
        formattedMean: _formatMean(average.mean, kind),
      ),
    );
  }

  return TrendsAverageComparison(header: _header(mode), rows: rows);
}

TrendsBreakdownIdentity _identity(
  String? bucketID,
  String? mainBucketID,
  bool isDirect,
) => (bucketID: bucketID, mainBucketID: mainBucketID, isDirect: isDirect);

String _header(TrendsMode mode) => switch (mode) {
  TrendsMode.month => _monthlyAverageLabel,
  TrendsMode.year => _yearlyAverageLabel,
};

String _formatMean(Decimal? mean, CategoryKind kind) {
  if (mean == null) return _unavailableMean;
  final amountKind = kind == CategoryKind.expense
      ? AmountKind.expense
      : AmountKind.income;
  return formatSignedMoney(mean, kind: amountKind, symbol: false);
}
