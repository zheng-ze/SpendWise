import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart'
    show BudgetFormSaved, BudgetsStep, PickCategoryRequested;
import 'package:spendwise/ui/budgets/budget_list/budget_scope_options.dart';
import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/base/step_emitting.dart';
import 'package:spendwise/ui/format/amount_parse.dart';

// MARK: - Constants
const _scopePlaceholder = 'Choose';
const _deletedCategoryLabel = '(category deleted)';

// MARK: - BudgetFormViewState
class BudgetFormViewState implements HasStep<BudgetFormViewState, BudgetsStep> {
  const BudgetFormViewState({
    required this.scope,
    required this.amountText,
    required this.ledgerState,
    this.error,
    this.step,
  });

  final BudgetScopeChoice? scope;
  final String amountText;
  final LedgerState ledgerState;
  final LedgerError? error;
  @override
  final BudgetsStep? step;

  Decimal? get parsedAmount => parseAmountInput(amountText);

  bool get canSave {
    final amount = parsedAmount;
    return scope != null && amount != null && amount > Decimal.zero;
  }

  String get scopeLabel => switch (scope) {
    null => _scopePlaceholder,
    AllSpendingChosen() => allSpendingLabel,
    CategoryChosen(:final categoryID) =>
      ledgerState.categories[categoryID]?.name ?? _deletedCategoryLabel,
  };

  BudgetFormViewState copyWith({
    BudgetScopeChoice? scope,
    String? amountText,
    LedgerError? Function()? error,
    BudgetsStep? Function()? step,
  }) {
    return BudgetFormViewState(
      scope: scope ?? this.scope,
      amountText: amountText ?? this.amountText,
      ledgerState: ledgerState,
      error: error == null ? this.error : error(),
      step: step == null ? this.step : step(),
    );
  }

  @override
  BudgetFormViewState withStep(BudgetsStep? Function() step) =>
      copyWith(step: step);
}

// MARK: - BudgetDraftKey
class BudgetDraftKey {
  BudgetDraftKey();
}

// MARK: - BudgetFormViewModel
abstract class BudgetFormViewModel {
  void setAmount(String raw);
  void requestPickCategory();
  void applyPickedScope(BudgetScopeChoice scope);
  void retry();
  Future<void> save();
  void clearStep();
}

// MARK: - BudgetFormNotifier
class BudgetFormNotifier extends AsyncNotifier<BudgetFormViewState>
    with
        LedgerBackedNotifier<BudgetFormViewState>,
        StepEmitting<BudgetFormViewState, BudgetsStep>
    implements BudgetFormViewModel {
  BudgetFormNotifier(this.draftKey);

  final BudgetDraftKey draftKey;

  @override
  Future<BudgetFormViewState> build() async {
    final ledgerState = ledger.state;
    final unscopedTaken = ledgerState.budgets.values.any(
      (budget) => budget.categoryID == null,
    );
    return BudgetFormViewState(
      scope: unscopedTaken ? null : const AllSpendingChosen(),
      amountText: '',
      ledgerState: ledgerState,
    );
  }

  @override
  void setAmount(String raw) => updateState((s) => s.copyWith(amountText: raw));

  @override
  void requestPickCategory() => emitStep(PickCategoryRequested());

  @override
  void applyPickedScope(BudgetScopeChoice scope) {
    updateState((s) => s.copyWith(scope: scope, step: () => null));
  }

  @override
  void retry() => ref.invalidateSelf();

  @override
  Future<void> save() async {
    final current = state.value;
    final scope = current?.scope;
    final amount = current?.parsedAmount;
    if (current == null || scope == null || amount == null) return;
    if (!current.canSave) return;

    try {
      ledger.addBudget(scope.categoryID, amount);
      updateState(
        (s) => s.copyWith(error: () => null, step: () => BudgetFormSaved()),
      );
    } on LedgerError catch (error) {
      updateState((s) => s.copyWith(error: () => error));
    }
  }
}

// MARK: - Constants
final budgetFormViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<BudgetFormNotifier, BudgetFormViewState, BudgetDraftKey>(
      BudgetFormNotifier.new,
      retry: (_, _) => null,
    );
