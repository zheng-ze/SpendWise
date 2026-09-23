import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/step_emitting.dart';
import 'package:spendwise/ui/format/color_hex.dart';

const defaultCategoryColor = Color(0xFF007AFF);

bool isKindLocked({
  required bool hasPresetParent,
  required bool isReferenced,
}) => hasPresetParent || isReferenced;

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
            category.kind == kind &&
            category.id != excludingID,
      )
      .toList();
}

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

  @override
  CategoryFormViewState withStep(CategoryFormStep? Function() step) =>
      copyWith(step: step);
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

class CategoryFormNotifier extends AsyncNotifier<CategoryFormViewState>
    with
        LedgerBackedNotifier<CategoryFormViewState>,
        StepEmitting<CategoryFormViewState, CategoryFormStep>
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
  void requestPickParent() => emitStep(PickParentRequested());

  @override
  void applyPickedParent(String? id) {
    if (!ref.mounted) return;
    updateState((s) => s.copyWith(parentID: () => id, step: () => null));
  }

  @override
  void requestPickSymbol() => emitStep(PickSymbolRequested());

  @override
  void applyPickedSymbol(String name) {
    if (!ref.mounted) return;
    updateState((s) => s.copyWith(symbol: name, step: () => null));
  }

  @override
  void requestDelete() => emitStep(DeleteConfirmationRequested());

  @override
  Future<void> applyDeleteConfirmed(bool confirmed) async {
    if (!confirmed) {
      clearStep();
      return;
    }
    final category = _category;
    if (category == null) return;
    ledger.deleteCategory(category.id);
    emitStep(CategoryFormSaved());
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
}

final categoryFormViewModelProvider =
    AsyncNotifierProvider.family<
      CategoryFormNotifier,
      CategoryFormViewState,
      CategoryFormArgs
    >(CategoryFormNotifier.new);
