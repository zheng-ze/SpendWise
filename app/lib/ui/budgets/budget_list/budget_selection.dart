import 'package:flutter_riverpod/flutter_riverpod.dart';

// MARK: - BudgetSelection
typedef BudgetSelection = ({String budgetID, int generation});

// MARK: - SelectedBudgetNotifier
class SelectedBudgetNotifier extends Notifier<BudgetSelection?> {
  int _lastGeneration = 0;

  @override
  BudgetSelection? build() => null;

  void select(String budgetID) {
    if (state?.budgetID == budgetID) return;
    _lastGeneration += 1;
    state = (budgetID: budgetID, generation: _lastGeneration);
  }

  void clear() => state = null;
}

// MARK: - Constants
final selectedBudgetProvider =
    NotifierProvider<SelectedBudgetNotifier, BudgetSelection?>(
      SelectedBudgetNotifier.new,
    );
