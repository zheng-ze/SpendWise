import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart' show immutable;

/// Sealed rather than an enum so `sub`'s payload can hold the null bucket
/// explicitly, distinct from `all`'s lack of any id constraint.
@immutable
sealed class CategoryScope {
  const CategoryScope();
}

@immutable
class AllScope extends CategoryScope {
  const AllScope();
}

@immutable
class SubScope extends CategoryScope {
  const SubScope(this.subID);

  final String? subID;
}

@immutable
class DirectScope extends CategoryScope {
  const DirectScope();
}

Set<String?> matchingCategoryIDs(
  String mainID,
  CategoryScope scope,
  LedgerState state,
) {
  switch (scope) {
    case AllScope():
      return {
        mainID,
        for (final category in state.categories.values)
          if (category.parentID == mainID) category.id,
      };
    case SubScope(:final subID):
      return {subID};
    case DirectScope():
      return {mainID};
  }
}
