import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';

@immutable
class TrendsDetailMetadata {
  const TrendsDetailMetadata({required this.id, required this.title});

  final String id;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is TrendsDetailMetadata && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);
}

TrendsDetailMetadata deriveTrendsDetailMetadata({
  required TrendsIntent intent,
  required DateTime today,
  TrendsBounds? bounds,
}) {
  final context = TrendsContext(
    currentMonth: monthSerial(today),
    bounds: bounds,
  );
  final selected = intent.effective(context).selected;
  return switch (intent.mode) {
    TrendsMode.month => _monthMetadata(monthStartOf(selected)),
    TrendsMode.year => _yearMetadata(DateTime.utc(selected)),
  };
}

TrendsDetailMetadata _monthMetadata(DateTime month) => TrendsDetailMetadata(
  id: 'month:${month.year}-${month.month.toString().padLeft(2, '0')}',
  title: formatMonthNameYear(month),
);

TrendsDetailMetadata _yearMetadata(DateTime year) =>
    TrendsDetailMetadata(id: 'year:${year.year}', title: formatYearLabel(year));

final trendsDetailMetadataProvider = Provider.autoDispose<TrendsDetailMetadata>(
  (ref) {
    final intent = ref.watch(trendsIntentProvider);
    final today = ref.watch(todayProvider);
    final ledger = ref.watch(ledgerProvider);
    final queries = ref.watch(analysisQueriesProvider);
    final firstRecord = queries?.readFirstRecordMonth();
    final hasCurrentBounds =
        ledger != null &&
        firstRecord?.state == AnalysisQueryState.ready &&
        firstRecord?.sourceRevision == ledger.revision;
    final bounds = hasCurrentBounds
        ? TrendsBounds.fromFirstRecord(firstRecord!.value, monthSerial(today))
        : null;

    return deriveTrendsDetailMetadata(
      intent: intent,
      today: today,
      bounds: bounds,
    );
  },
);
