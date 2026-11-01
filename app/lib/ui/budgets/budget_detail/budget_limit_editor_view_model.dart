import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/budgets/budget_detail/budgets_steps.dart';
import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/base/step_emitting.dart';
import 'package:spendwise/ui/format/amount_parse.dart';
import 'package:spendwise/ui/format/money_format.dart';

// MARK: - BudgetLimitEditorState
class BudgetLimitEditorState
    implements HasStep<BudgetLimitEditorState, BudgetsStep> {
  const BudgetLimitEditorState({
    required this.amountText,
    this.error,
    this.step,
  });

  final String amountText;
  final LedgerError? error;
  @override
  final BudgetsStep? step;

  Decimal? get parsedAmount => parseAmountInput(amountText);

  bool get canSave {
    final amount = parsedAmount;
    return amount != null && amount > Decimal.zero;
  }

  BudgetLimitEditorState copyWith({
    String? amountText,
    LedgerError? Function()? error,
    BudgetsStep? Function()? step,
  }) {
    return BudgetLimitEditorState(
      amountText: amountText ?? this.amountText,
      error: error == null ? this.error : error(),
      step: step == null ? this.step : step(),
    );
  }

  @override
  BudgetLimitEditorState withStep(BudgetsStep? Function() step) =>
      copyWith(step: step);
}

// MARK: - BudgetLimitDraftKey
class BudgetLimitDraftKey {
  BudgetLimitDraftKey({required this.budgetID, required this.initialLimit});

  final String budgetID;
  final Decimal initialLimit;
}

// MARK: - BudgetLimitEditorViewModel
abstract class BudgetLimitEditorViewModel {
  void setAmount(String raw);
  void save();
  void clearStep();
}

// MARK: - BudgetLimitEditorNotifier
class BudgetLimitEditorNotifier extends AsyncNotifier<BudgetLimitEditorState>
    with
        LedgerBackedNotifier<BudgetLimitEditorState>,
        StepEmitting<BudgetLimitEditorState, BudgetsStep>
    implements BudgetLimitEditorViewModel {
  BudgetLimitEditorNotifier(this.draftKey);

  final BudgetLimitDraftKey draftKey;

  @override
  BudgetLimitEditorState build() {
    final _ = ledger;
    return BudgetLimitEditorState(
      amountText: formatPlainAmount(draftKey.initialLimit),
    );
  }

  @override
  void setAmount(String raw) => updateState((s) => s.copyWith(amountText: raw));

  @override
  void save() {
    final current = state.value;
    final amount = current?.parsedAmount;
    if (current == null || amount == null || !current.canSave) return;

    try {
      ledger.updateBudgetLimit(draftKey.budgetID, amount);
      updateState(
        (s) => s.copyWith(error: () => null, step: () => BudgetLimitSaved()),
      );
    } on LedgerError catch (error) {
      updateState((s) => s.copyWith(error: () => error));
    }
  }
}

// MARK: - Constants
final budgetLimitEditorViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<
      BudgetLimitEditorNotifier,
      BudgetLimitEditorState,
      BudgetLimitDraftKey
    >(BudgetLimitEditorNotifier.new, retry: (_, _) => null);
