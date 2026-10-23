import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart' show immutable;

@immutable
class CategoryDetailArgs {
  const CategoryDetailArgs({
    required this.mainID,
    required this.kind,
    required this.isYearRange,
    required this.initialDate,
  });

  final String mainID;
  final CategoryKind kind;
  final bool isYearRange;
  final DateTime initialDate;

  @override
  bool operator ==(Object other) =>
      other is CategoryDetailArgs &&
      other.mainID == mainID &&
      other.kind == kind &&
      other.isYearRange == isYearRange &&
      other.initialDate == initialDate;

  @override
  int get hashCode => Object.hash(mainID, kind, isYearRange, initialDate);
}
