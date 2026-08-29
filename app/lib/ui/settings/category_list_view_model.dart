import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/step_emitting.dart';

sealed class CategoryListStep {}

class CategoryFormRequested extends CategoryListStep {
  CategoryFormRequested({this.category, this.presetParentID});

  final TransactionCategory? category;
  final String? presetParentID;
}

class CategoryListViewState
    implements HasStep<CategoryListViewState, CategoryListStep> {
  const CategoryListViewState({
    required this.income,
    required this.expense,
    this.step,
  });

  final List<TransactionCategory> income;
  final List<TransactionCategory> expense;
  @override
  final CategoryListStep? step;

  CategoryListViewState copyWith({
    List<TransactionCategory>? income,
    List<TransactionCategory>? expense,
    CategoryListStep? Function()? step,
  }) {
    return CategoryListViewState(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      step: step == null ? this.step : step(),
    );
  }

  @override
  CategoryListViewState withStep(CategoryListStep? Function() step) =>
      copyWith(step: step);
}

abstract class CategoryListViewModel {
  void requestNewCategory();
  void requestEditCategory(TransactionCategory category);
  void requestNewSubcategory(TransactionCategory parent);
  Future<void> deleteCategory(String id);
  void clearStep();
}

class CategoryListNotifier extends AsyncNotifier<CategoryListViewState>
    with
        LedgerBackedNotifier<CategoryListViewState>,
        StepEmitting<CategoryListViewState, CategoryListStep>
    implements CategoryListViewModel {
  @override
  Future<CategoryListViewState> build() async {
    final currentLedger = ledger;
    currentLedger.addListener(_onLedgerChanged);
    ref.onDispose(() => currentLedger.removeListener(_onLedgerChanged));
    return _buildState(currentLedger);
  }

  void _onLedgerChanged() {
    final current = state.value;
    state = AsyncData(_buildState(ledger, step: current?.step));
  }

  CategoryListViewState _buildState(Ledger ledger, {CategoryListStep? step}) {
    return CategoryListViewState(
      income: ledger.categories(CategoryKind.income),
      expense: ledger.categories(CategoryKind.expense),
      step: step,
    );
  }

  @override
  void requestNewCategory() => emitStep(CategoryFormRequested());

  @override
  void requestEditCategory(TransactionCategory category) =>
      emitStep(CategoryFormRequested(category: category));

  @override
  void requestNewSubcategory(TransactionCategory parent) =>
      emitStep(CategoryFormRequested(presetParentID: parent.id));

  @override
  Future<void> deleteCategory(String id) async {
    ledger.deleteCategory(id);
  }
}

final categoryListViewModelProvider =
    AsyncNotifierProvider<CategoryListNotifier, CategoryListViewState>(
      CategoryListNotifier.new,
    );
