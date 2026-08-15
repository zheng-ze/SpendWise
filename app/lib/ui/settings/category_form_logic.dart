import 'package:domain/domain.dart';

bool isKindLocked({
  required bool hasPresetParent,
  required bool isReferenced,
}) => hasPresetParent || isReferenced;

bool canSaveCategoryForm(String name) => name.trim().isNotEmpty;

/// Root categories of [kind], minus [excludingID]. A child never qualifies:
/// the domain enforces one level of nesting, so a child can't parent another.
List<TransactionCategory> eligibleParents(
  List<TransactionCategory> categories,
  CategoryKind kind, {
  required String? excludingID,
}) {
  return categories
      .where(
        (category) =>
            category.parentID == null &&
            category.kind == kind &&
            category.id != excludingID,
      )
      .toList();
}
