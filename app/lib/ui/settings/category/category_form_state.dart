import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/base/step_emitting.dart';

// MARK: - Default Color

const defaultCategoryColor = Color(0xFF007AFF);

// MARK: - Pure Helpers

bool isKindLocked({
  required bool isEditing,
  required bool hasPresetParent,
  required bool isReferenced,
}) => isEditing || hasPresetParent || isReferenced;

bool canSaveCategoryForm(String name) => name.trim().isNotEmpty;

List<TransactionCategory> eligibleParents(
  List<TransactionCategory> categories,
  CategoryKind kind, {
  required String? excludingID,
}) {
  return categories
      .where(
        (category) =>
            category.parentID == null &&
            category.lifecycle == LifecycleState.active &&
            category.kind == kind &&
            category.id != excludingID,
      )
      .toList();
}

// MARK: - Args

@immutable
class CategoryFormArgs {
  const CategoryFormArgs({this.category, this.presetParentID});

  final TransactionCategory? category;
  final String? presetParentID;

  @override
  bool operator ==(Object other) =>
      other is CategoryFormArgs &&
      other.category == category &&
      other.presetParentID == presetParentID;

  @override
  int get hashCode => Object.hash(category, presetParentID);
}

// MARK: - Steps

sealed class CategoryFormStep {}

class PickParentRequested extends CategoryFormStep {}

class PickSymbolRequested extends CategoryFormStep {}

class DeleteConfirmationRequested extends CategoryFormStep {}

class CategoryFormSaved extends CategoryFormStep {}

// MARK: - State

class CategoryFormViewState
    implements HasStep<CategoryFormViewState, CategoryFormStep> {
  const CategoryFormViewState({
    required this.editedCategoryID,
    required this.hasPresetParent,
    required this.isReferenced,
    required this.name,
    required this.kind,
    required this.symbol,
    required this.color,
    required this.includeInAnalysis,
    required this.parentID,
    required this.allCategories,
    this.error,
    this.step,
  });

  final String? editedCategoryID;

  final bool hasPresetParent;
  final bool isReferenced;
  final String name;
  final CategoryKind kind;
  final String symbol;
  final Color color;
  final bool includeInAnalysis;
  final String? parentID;

  final List<TransactionCategory> allCategories;

  final LedgerError? error;
  @override
  final CategoryFormStep? step;

  // MARK: - Derived

  bool get isEditing => editedCategoryID != null;

  bool get kindLocked => isKindLocked(
    isEditing: isEditing,
    hasPresetParent: hasPresetParent,
    isReferenced: isReferenced,
  );

  List<TransactionCategory> get eligibleParentsList =>
      eligibleParents(allCategories, kind, excludingID: editedCategoryID);

  bool get storedHasChildren {
    final id = editedCategoryID;
    if (id == null) return false;
    return allCategories.any((category) => category.parentID == id);
  }

  bool get showParentPicker =>
      !hasPresetParent && !storedHasChildren && eligibleParentsList.isNotEmpty;

  bool get hasStaleParent {
    final id = parentID;
    if (hasPresetParent || id == null) return false;
    if (storedHasChildren) return true;
    return !eligibleParentsList.any((category) => category.id == id);
  }

  bool get canSave => canSaveCategoryForm(name);

  bool get editsStoredSubcategory {
    final id = editedCategoryID;
    return allCategories.any(
      (category) => category.id == id && category.parentID != null,
    );
  }

  bool get isSubcategoryForm => hasPresetParent || editsStoredSubcategory;

  bool get showsSubcategories =>
      isEditing && !editsStoredSubcategory && parentID == null;

  List<TransactionCategory> get activeSubcategories {
    if (!showsSubcategories) return const [];
    return allCategories
        .where(
          (category) =>
              category.parentID == editedCategoryID &&
              category.lifecycle == LifecycleState.active,
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  String get title {
    if (isEditing) {
      return editsStoredSubcategory ? 'Edit subcategory' : 'Edit category';
    }
    return hasPresetParent ? 'Add subcategory' : 'Add category';
  }

  String? get parentLabel {
    final id = parentID;
    if (id == null) return null;
    for (final category in allCategories) {
      final isActiveRoot =
          category.parentID == null &&
          category.lifecycle == LifecycleState.active;
      if (isActiveRoot && category.id == id) return category.name;
    }
    return null;
  }

  // MARK: - Copy

  CategoryFormViewState copyWith({
    String? name,
    CategoryKind? kind,
    String? symbol,
    Color? color,
    bool? includeInAnalysis,
    String? Function()? parentID,
    List<TransactionCategory>? allCategories,
    LedgerError? Function()? error,
    CategoryFormStep? Function()? step,
  }) {
    return CategoryFormViewState(
      editedCategoryID: editedCategoryID,
      hasPresetParent: hasPresetParent,
      isReferenced: isReferenced,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      symbol: symbol ?? this.symbol,
      color: color ?? this.color,
      includeInAnalysis: includeInAnalysis ?? this.includeInAnalysis,
      parentID: parentID == null ? this.parentID : parentID(),
      allCategories: allCategories ?? this.allCategories,
      error: error == null ? this.error : error(),
      step: step == null ? this.step : step(),
    );
  }

  @override
  CategoryFormViewState withStep(CategoryFormStep? Function() step) =>
      copyWith(step: step);
}
