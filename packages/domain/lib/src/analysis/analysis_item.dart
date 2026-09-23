import 'package:decimal/decimal.dart';
import 'package:domain/src/entries/category_kind.dart';
import 'package:domain/src/time/calendar_day.dart';
import 'package:meta/meta.dart';

@immutable
class AnalysisItem {
  AnalysisItem({
    required this.bucketID,
    required this.amount,
    required DateTime date,
    required this.kind,
  }) : date = startOfDayUtc(date);

  final String? bucketID;

  final Decimal amount;

  final DateTime date;
  final CategoryKind kind;

  @override
  bool operator ==(Object other) {
    return other is AnalysisItem &&
        other.bucketID == bucketID &&
        other.amount == amount &&
        other.date == date &&
        other.kind == kind;
  }

  @override
  int get hashCode => Object.hash(bucketID, amount, date, kind);

  @override
  String toString() =>
      'AnalysisItem(bucketID: $bucketID, amount: $amount, date: $date, '
      'kind: $kind)';
}
