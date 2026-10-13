import 'dart:collection';

import 'package:decimal/decimal.dart';
import 'package:domain/src/analysis/analysis_item.dart';
import 'package:domain/src/entries/category_kind.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/time/date_range.dart';

// MARK: - Filtering

extension AnalysisItemList on List<AnalysisItem> {
  List<AnalysisItem> filtered({
    CategoryKind? kind,
    Set<String?>? buckets,
    DateRange? interval,
  }) {
    final wanted = buckets?.map(normalizedOptionalID).toSet();
    return UnmodifiableListView(
      where((item) {
        if (kind != null && item.kind != kind) return false;
        if (wanted != null && !wanted.contains(item.bucketID)) return false;
        if (interval != null && !interval.contains(item.date)) return false;

        return true;
      }).toList(),
    );
  }

  // MARK: - Totals

  Decimal total({
    CategoryKind? kind,
    Set<String?>? buckets,
    DateRange? interval,
  }) {
    return filtered(
      kind: kind,
      buckets: buckets,
      interval: interval,
    ).fold(Decimal.zero, (sum, item) => sum + item.amount);
  }
}
