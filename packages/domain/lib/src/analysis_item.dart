import 'package:decimal/decimal.dart';
import 'package:domain/src/category_kind.dart';
import 'package:meta/meta.dart';

@immutable
class AnalysisItem {
  const AnalysisItem({
    required this.bucketID,
    required this.amount,
    required this.date,
    required this.kind,
  });

  /// Null is the Uncategorized bucket, not an absent value.
  final String? bucketID;

  /// Always positive. [kind] carries the direction.
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
}
