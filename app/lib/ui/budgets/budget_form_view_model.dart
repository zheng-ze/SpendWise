import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/budgets/budget_detail_view_model.dart'
    show BudgetFormSaved, BudgetsStep, PickCategoryRequested;
import 'package:spendwise/ui/common/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/step_emitting.dart';
import 'package:spendwise/ui/format/amount_parse.dart';

/// A category with an unbudgeted child stays offered even when the category
/// itself already carries a budget, since the child still needs a group to
/// list under.
List<(TransactionCategory, List<TransactionCategory>)> groupedBudgetCategories(
  LedgerState state,
) {
  final budgeted = state.budgets.values
      .map((budget) => budget.categoryID)
      .toSet();

  final active = state.categories.values.where(
    (category) =>
        category.lifecycle.isActive && category.kind == CategoryKind.expense,
  );

  final roots = active.where((category) => category.parentID == null).toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  final childrenByParent = <String, List<TransactionCategory>>{};
  for (final category in active) {
    final parentID = category.parentID;
    if (parentID == null || budgeted.contains(category.id)) continue;
    (childrenByParent[parentID] ??= []).add(category);
  }
  for (final children in childrenByParent.values) {
    children.sort((a, b) => a.name.compareTo(b.name));
  }

  return [
    for (final root in roots)
      if (!budgeted.contains(root.id) ||
          (childrenByParent[root.id]?.isNotEmpty ?? false))
        (root, childrenByParent[root.id] ?? const []),
  ];
}

class BudgetFormViewState implements HasStep<BudgetFormViewState, BudgetsStep> {
  const BudgetFormViewState({
    required this.categoryID,
    required this.amountText,
    required this.ledgerState,
    this.error,
    this.step,
  });

  final String? categoryID;
  final String amountText;
  final LedgerState ledgerState;
  final LedgerError? error;
  @override
  final BudgetsStep? step;

  Decimal? get parsedAmount => parseAmountInput(amountText);

  bool get canSave {
    final amount = parsedAmount;
    return amount != null && amount > Decimal.zero;
  }

  String get categoryLabel {
    final id = categoryID;
    if (id == null) return 'Overall';
    return ledgerState.categories[id]?.name ?? '(category deleted)';
  }

  Set<String?> get budgetedCategoryIDs =>
      ledgerState.budgets.values.map((budget) => budget.categoryID).toSet();

  List<(TransactionCategory, List<TransactionCategory>)>
  get groupedCategories => groupedBudgetCategories(ledgerState);

  BudgetFormViewState copyWith({
    String? Function()? categoryID,
    String? amountText,
    LedgerState? ledgerState,
    LedgerError? Function()? error,
    BudgetsStep? Function()? step,
  }) {
    return BudgetFormViewState(
      categoryID: categoryID == null ? this.categoryID : categoryID(),
      amountText: amountText ?? this.amountText,
      ledgerState: ledgerState ?? this.ledgerState,
      error: error == null ? this.error : error(),
      step: step == null ? this.step : step(),
    );
  }

  @override
  BudgetFormViewState withStep(BudgetsStep? Function() step) =>
      copyWith(step: step);
}

abstract class BudgetFormViewModel {
  void setAmount(String raw);
  void requestPickCategory();
  void applyPickedCategory(String? categoryID);
  Future<void> save();
  void clearStep();
}

class BudgetFormNotifier extends AsyncNotifier<BudgetFormViewState>
    with
        LedgerBackedNotifier<BudgetFormViewState>,
        StepEmitting<BudgetFormViewState, BudgetsStep>
    implements BudgetFormViewModel {
  @override
  Future<BudgetFormViewState> build() async {
    return BudgetFormViewState(
      categoryID: null,
      amountText: '',
      ledgerState: ledger.state,
    );
  }

  @override
  void setAmount(String raw) => updateState((s) => s.copyWith(amountText: raw));

  @override
  void requestPickCategory() => emitStep(PickCategoryRequested());

  // A picker outcome can arrive after the sheet that opened it was
  // dismissed, so this must no-op rather than update a gone provider.
  @override
  void applyPickedCategory(String? categoryID) {
    if (!ref.mounted) return;
    updateState(
      (s) => s.copyWith(categoryID: () => categoryID, step: () => null),
    );
  }

  @override
  Future<void> save() async {
    final current = state.value;
    if (current == null) return;
    final amount = current.parsedAmount;
    if (amount == null) return;

    try {
      ledger.addBudget(
        current.categoryID,
        amount.abs(),
        now: startOfDayUtc(DateTime.now()),
      );
      updateState(
        (s) => s.copyWith(error: () => null, step: () => BudgetFormSaved()),
      );
    } on LedgerError catch (error) {
      updateState((s) => s.copyWith(error: () => error));
    }
  }
}

final budgetFormViewModelProvider =
    AsyncNotifierProvider<BudgetFormNotifier, BudgetFormViewState>(
      BudgetFormNotifier.new,
    );
