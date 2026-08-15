import 'dart:ui' show Color;

import 'package:decimal/decimal.dart';
import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart' show immutable;

import 'package:spendwise/ui/format/color_hex.dart';

const _uncategorizedSymbol = 'help_outline';

/// Fraction division is not always exact (a third of a total, say), so it
/// needs a scale to round to rather than the bare `Decimal` division, which
/// only succeeds when the result terminates.
const _fractionScale = 12;

@immutable
class Slice {
  const Slice({
    required this.bucketID,
    required this.amount,
    required this.fraction,
    required this.symbolName,
    required this.color,
  });

  /// Null is the Uncategorized bucket, not an absent value.
  final String? bucketID;

  final Decimal amount;
  final Decimal fraction;
  final String symbolName;
  final Color color;
}

List<Slice> slices(
  List<AnalysisItem> items,
  CategoryKind kind,
  DateRange window,
  LedgerState state,
) {
  final filtered = items.where(
    (item) => item.kind == kind && window.contains(item.date),
  );
  final sums = Accounting.rollUp(filtered.toList(), state);

  final total = sums.values.fold(Decimal.zero, (sum, amount) => sum + amount);

  final result = [
    for (final entry in sums.entries)
      _slice(entry.key, entry.value, total, state),
  ];
  result.sort((a, b) => b.amount.compareTo(a.amount));
  return result;
}

Slice _slice(
  String? bucketID,
  Decimal amount,
  Decimal total,
  LedgerState state,
) {
  final fraction = total == Decimal.zero
      ? Decimal.zero
      : (amount / total).toDecimal(scaleOnInfinitePrecision: _fractionScale);

  final category = bucketID == null ? null : state.categories[bucketID];
  final symbolName = category?.symbol ?? _uncategorizedSymbol;
  final color = category == null
      ? colorHexFallback
      : parseColorHex(category.colorHex);

  return Slice(
    bucketID: bucketID,
    amount: amount,
    fraction: fraction,
    symbolName: symbolName,
    color: color,
  );
}
