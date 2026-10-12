import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/step_emitting.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/settings/category/category_form_state.dart';

export 'package:spendwise/ui/settings/category/category_form_state.dart';

// MARK: - View Model Contract

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

// MARK: - Notifier

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

  // MARK: - Field Setters

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

  // MARK: - Picker Steps

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

  // MARK: - Delete and Save

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

// MARK: - Provider

final categoryFormViewModelProvider =
    AsyncNotifierProvider.family<
      CategoryFormNotifier,
      CategoryFormViewState,
      CategoryFormArgs
    >(CategoryFormNotifier.new);
