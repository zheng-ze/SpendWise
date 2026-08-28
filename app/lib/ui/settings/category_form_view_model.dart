import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/ledger_backed_notifier.dart';
import 'package:spendwise/ui/format/color_hex.dart';

const defaultCategoryColor = Color(0xFF007AFF);

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

/// Which category (if any) is being edited, and any parent preset from
/// "add subcategory". Keyed on this pair so Riverpod's family cache treats
/// each distinct form target as its own notifier instance.
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

sealed class CategoryFormStep {}

class PickParentRequested extends CategoryFormStep {}

class PickSymbolRequested extends CategoryFormStep {}

class DeleteConfirmationRequested extends CategoryFormStep {}

class CategoryFormSaved extends CategoryFormStep {}

class CategoryFormViewState {
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

  /// The id of the category being edited, or null when this form creates a
  /// new one. Also excludes this category from its own possible parents.
  final String? editedCategoryID;

  final bool hasPresetParent;
  final bool isReferenced;
  final String name;
  final CategoryKind kind;
  final String symbol;
  final Color color;
  final bool includeInAnalysis;
  final String? parentID;

  /// Every category in the ledger, used to compute [eligibleParents] and
  /// [parentLabel] as the kind/parent selection changes.
  final List<TransactionCategory> allCategories;

  final LedgerError? error;
  final CategoryFormStep? step;

  bool get isEditing => editedCategoryID != null;

  bool get kindLocked => isKindLocked(
    hasPresetParent: hasPresetParent,
    isReferenced: isReferenced,
  );

  List<TransactionCategory> get eligibleParentsList =>
      eligibleParents(allCategories, kind, excludingID: editedCategoryID);

  bool get showParentPicker =>
      !hasPresetParent && eligibleParentsList.isNotEmpty;

  bool get canSave => canSaveCategoryForm(name);

  String get title {
    if (isEditing) return 'Edit Category';
    if (hasPresetParent) return 'New Subcategory';
    return 'New Category';
  }

  String? get parentLabel {
    final id = parentID;
    if (id == null) return null;
    for (final category in allCategories) {
      if (category.id == id) return category.name;
    }
    return null;
  }

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
}

abstract class CategoryFormViewModel {
  void setName(String name);
  void setKind(CategoryKind kind);
  void setColor(Color color);
  void setIncludeInAnalysis(bool value);
  void setParentID(String? id);
  void requestPickParent();
  void applyPickedParent(String? id);
  void requestPickSymbol();
  void applyPickedSymbol(String name);
  void requestDelete();
  Future<void> applyDeleteConfirmed(bool confirmed);
  Future<void> save();
  void clearStep();
}

// One instance per (category, presetParentID) pair, since the provider is a
// family keyed by what the form edits.
class CategoryFormNotifier extends AsyncNotifier<CategoryFormViewState>
    with LedgerBackedNotifier<CategoryFormViewState>
    implements CategoryFormViewModel {
  CategoryFormNotifier(this._args);

  final CategoryFormArgs _args;

  TransactionCategory? get _category => _args.category;

  bool get _isEditing => _category != null;

  TransactionCategory? get _presetParent {
    final id = _args.presetParentID;
    if (id == null) return null;
    return ledger.state.categories[id];
  }

  bool get _isReferenced {
    final category = _category;
    if (category == null) return false;
    return ledger.state.entryCountReferencing(category.id) > 0;
  }

  Color _initialColor() {
    final ownHex = _category?.colorHex;
    if (ownHex != null) return parseColorHex(ownHex);
    final parentHex = _presetParent?.colorHex;
    return parentHex != null ? parseColorHex(parentHex) : defaultCategoryColor;
  }

  @override
  Future<CategoryFormViewState> build() async {
    final category = _category;
    return CategoryFormViewState(
      editedCategoryID: category?.id,
      hasPresetParent: _args.presetParentID != null,
      isReferenced: _isReferenced,
      name: category?.name ?? '',
      kind: category?.kind ?? _presetParent?.kind ?? CategoryKind.expense,
      symbol: category?.symbol ?? 'tag',
      color: _initialColor(),
      includeInAnalysis: category?.includeInAnalysis ?? true,
      parentID: category?.parentID ?? _args.presetParentID,
      allCategories: ledger.state.categories.values.toList(),
    );
  }

  @override
  void setName(String name) => updateState((s) => s.copyWith(name: name));

  @override
  void setKind(CategoryKind kind) {
    updateState((s) {
      final parentID = s.parentID;
      final parent = parentID == null
          ? null
          : ledger.state.categories[parentID];
      final parentStillValid = parent != null && parent.kind == kind;
      return s.copyWith(
        kind: kind,
        parentID: parentStillValid ? null : () => null,
      );
    });
  }

  @override
  void setColor(Color color) => updateState((s) => s.copyWith(color: color));

  @override
  void setIncludeInAnalysis(bool value) =>
      updateState((s) => s.copyWith(includeInAnalysis: value));

  @override
  void setParentID(String? id) =>
      updateState((s) => s.copyWith(parentID: () => id));

  @override
  void requestPickParent() =>
      updateState((s) => s.copyWith(step: () => PickParentRequested()));

  // A picker outcome can arrive after the sheet that opened it was
  // dismissed, so this must no-op rather than update a gone provider.
  @override
  void applyPickedParent(String? id) {
    if (!ref.mounted) return;
    updateState((s) => s.copyWith(parentID: () => id, step: () => null));
  }

  @override
  void requestPickSymbol() =>
      updateState((s) => s.copyWith(step: () => PickSymbolRequested()));

  @override
  void applyPickedSymbol(String name) {
    if (!ref.mounted) return;
    updateState((s) => s.copyWith(symbol: name, step: () => null));
  }

  @override
  void requestDelete() =>
      updateState((s) => s.copyWith(step: () => DeleteConfirmationRequested()));

  @override
  Future<void> applyDeleteConfirmed(bool confirmed) async {
    if (!confirmed) {
      updateState((s) => s.copyWith(step: () => null));
      return;
    }
    final category = _category;
    if (category == null) return;
    ledger.deleteCategory(category.id);
    updateState((s) => s.copyWith(step: () => CategoryFormSaved()));
  }

  @override
  Future<void> save() async {
    final current = state.value;
    if (current == null) return;

    final name = current.name.trim();

    try {
      final category = TransactionCategory(
        id: _category?.id,
        name: name,
        kind: current.kind,
        colorHex: toColorHex(current.color),
        includeInAnalysis: current.includeInAnalysis,
        parentID: current.parentID,
        symbol: current.symbol,
        lifecycle: _category?.lifecycle ?? LifecycleState.active,
      );

      if (_isEditing) {
        ledger.updateCategory(category);
      } else {
        ledger.addCategory(category);
      }

      updateState(
        (s) => s.copyWith(error: () => null, step: () => CategoryFormSaved()),
      );
    } on LedgerError catch (error) {
      updateState((s) => s.copyWith(error: () => error));
    }
  }

  @override
  void clearStep() => updateState((s) => s.copyWith(step: () => null));
}

final categoryFormViewModelProvider =
    AsyncNotifierProvider.family<
      CategoryFormNotifier,
      CategoryFormViewState,
      CategoryFormArgs
    >(CategoryFormNotifier.new);
