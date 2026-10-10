import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

@immutable
sealed class AnalysisCategoryScope {
  const AnalysisCategoryScope();

  const factory AnalysisCategoryScope.all() = AllCategoryScope;

  const factory AnalysisCategoryScope.direct() = DirectCategoryScope;

  factory AnalysisCategoryScope.subcategory(String subID) = SubCategoryScope;
}

@immutable
class AllCategoryScope extends AnalysisCategoryScope {
  const AllCategoryScope();

  @override
  bool operator ==(Object other) => other is AllCategoryScope;

  @override
  int get hashCode => runtimeType.hashCode;
}

@immutable
class DirectCategoryScope extends AnalysisCategoryScope {
  const DirectCategoryScope();

  @override
  bool operator ==(Object other) => other is DirectCategoryScope;

  @override
  int get hashCode => runtimeType.hashCode;
}

@immutable
class SubCategoryScope extends AnalysisCategoryScope {
  SubCategoryScope(String subID) : subID = normalizedID(subID);

  final String subID;

  @override
  bool operator ==(Object other) =>
      other is SubCategoryScope && other.subID == subID;

  @override
  int get hashCode => Object.hash(runtimeType, subID);
}
