import 'package:domain/domain.dart';

bool isKindLocked({
  required bool hasPresetParent,
  required bool isReferenced,
}) => hasPresetParent || isReferenced;

bool canSaveCategoryForm(String name) => name.trim().isNotEmpty;

/// Returns the root categories of [kind], minus [excludingID].
List<TransactionCategory> eligibleParents(
  List<TransactionCategory> categories,
  CategoryKind kind, {
  required String? excludingID,
}) {
  return categories
      .where(
        (category) =>
            // A child never qualifies: nesting only goes one level deep, so
            // a child can't parent another.
            category.parentID == null &&
            category.kind == kind &&
            category.id != excludingID,
      )
      .toList();
}
