part of '../ledger_state.dart';

const _clauseCategoryNesting = 5;
const _clauseEntryCategory = 6;
const _clauseReferenceOnlyReferenced = 11;

extension LedgerStateCategoryInvariants on LedgerState {
  // MARK: - Nesting

  void _assertCategoryNesting() {
    for (final category in _categories.values) {
      final parentID = category.parentID;
      if (parentID == null) continue;

      final parent = _categories[parentID];
      if (parent == null) {
        throw _violation(
          _clauseCategoryNesting,
          'category ${category.id} has unknown parent',
        );
      }
      if (parent.parentID != null) {
        throw _violation(
          _clauseCategoryNesting,
          'category ${category.id} nests below depth 2',
        );
      }
      if (parent.kind != category.kind) {
        throw _violation(
          _clauseCategoryNesting,
          'category ${category.id} kind differs from parent',
        );
      }

      if (!parent.lifecycle.isAtLeastAsAliveAs(category.lifecycle) &&
          !parent.lifecycle.isAtLeastAsAliveAs(LifecycleState.archived)) {
        throw _violation(
          _clauseCategoryNesting,
          'category ${category.id} sits under ${parent.lifecycle.name} parent',
        );
      }
    }
  }

  // MARK: - Entry coherence

  void _assertEntryCategoryCoherence() {
    for (final entry in _allEntries) {
      final categoryID = entry.categoryID;
      if (categoryID == null) continue;

      final category = _categories[categoryID];
      if (category == null) continue;

      final expected = entry.expectedCategoryKind;
      if (expected == null) {
        throw _violation(
          _clauseEntryCategory,
          'transfer ${entry.id} carries a category',
        );
      }
      if (category.kind != expected) {
        throw _violation(
          _clauseEntryCategory,
          'entry ${entry.id} kind differs from its category',
        );
      }
    }
  }

  // MARK: - Reference-only rows

  void _assertReferenceOnlyImpliesReferenced() {
    for (final category in _categories.values) {
      if (category.lifecycle != LifecycleState.referenceOnly) continue;

      if (_isCategoryReferenced(category.id)) continue;

      throw _violation(
        _clauseReferenceOnlyReferenced,
        'referenceOnly category ${category.id} unreferenced',
      );
    }

    for (final source in _moneySources.values) {
      if (source.lifecycle != LifecycleState.referenceOnly) continue;
      if (_isHolderReferenced(source.id)) continue;

      throw _violation(
        _clauseReferenceOnlyReferenced,
        'referenceOnly ${source.id} has no reference',
      );
    }
  }
}
