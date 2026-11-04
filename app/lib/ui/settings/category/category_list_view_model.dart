import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/base/step_emitting.dart';

// MARK: - Steps
sealed class CategoryListStep {}

class CategoryFormRequested extends CategoryListStep {
  CategoryFormRequested({this.category, this.presetParentID});

  final TransactionCategory? category;
  final String? presetParentID;
}

// MARK: - CategoryListViewState
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

// MARK: - CategoryListViewModel
abstract class CategoryListViewModel {
  void requestNewCategory();
  void requestEditCategory(TransactionCategory category);
  void requestNewSubcategory(TransactionCategory parent);
  Future<void> deleteCategory(String id);
  void clearStep();
}

// MARK: - CategoryListNotifier
class CategoryListNotifier extends AsyncNotifier<CategoryListViewState>
    with
        LedgerBackedNotifier<CategoryListViewState>,
        StepEmitting<CategoryListViewState, CategoryListStep>
    implements CategoryListViewModel {
  @override
  CategoryListViewState build() {
    final currentLedger = ledger;
    currentLedger.addListener(_onLedgerChanged);
    ref.onDispose(() => currentLedger.removeListener(_onLedgerChanged));
    return _viewState();
  }

  void _onLedgerChanged() => state = AsyncData(_viewState());

  CategoryListViewState _viewState() {
    return CategoryListViewState(
      income: ledger.categories(CategoryKind.income),
      expense: ledger.categories(CategoryKind.expense),
      step: state.value?.step,
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

// MARK: - Constants
final categoryListViewModelProvider =
    AsyncNotifierProvider.autoDispose<
      CategoryListNotifier,
      CategoryListViewState
    >(CategoryListNotifier.new, retry: (_, _) => null);
