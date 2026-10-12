import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/budgets/budget_list/budget_card.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';
import 'package:spendwise/ui/common/navigation/expanding_fab.dart';
import 'package:spendwise/ui/common/lists/swipe_to_delete_row.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

// MARK: - Root

class BudgetsRoot extends ConsumerWidget {
  const BudgetsRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(budgetsListViewModelProvider);
    final viewModel = ref.watch(budgetsListViewModelProvider.notifier);
    final month = YearMonth.fromUtc(ref.watch(effectiveMonthProvider));

    return asyncState.when(
      data: (viewState) => BudgetsRootBody(
        viewState: viewState,
        viewModel: viewModel,
        month: month,
      ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('$error'))),
    );
  }
}

// MARK: - Body

class BudgetsRootBody extends StatelessWidget {
  const BudgetsRootBody({
    super.key,
    required this.viewState,
    required this.viewModel,
    required this.month,
  });

  static const _addBudgetLabel = 'Add Budget';

  final BudgetsListViewState viewState;
  final BudgetsListViewModel viewModel;
  final YearMonth month;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            BudgetsListView(
              viewState: viewState,
              viewModel: viewModel,
              month: month,
            ),
            ExpandingFab(
              primary: FabAction(
                label: _addBudgetLabel,
                icon: Icons.add,
                onTap: viewModel.requestNewBudget,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// MARK: - List

class BudgetsListView extends StatelessWidget {
  const BudgetsListView({
    super.key,
    required this.viewState,
    required this.viewModel,
    required this.month,
  });

  final BudgetsListViewState viewState;
  final BudgetsListViewModel viewModel;
  final YearMonth month;

  static const _listVerticalPadding = 8.0;
  static const _separatorHeight = 1.0;

  static const _overallName = 'Overall';

  static const _deletedCategoryName = '(category deleted)';

  @override
  Widget build(BuildContext context) {
    final budgets = viewState.budgets;

    if (budgets.isEmpty) return const BudgetsEmptyState();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: _listVerticalPadding),
      itemCount: budgets.length,
      separatorBuilder: (_, _) => const Divider(height: _separatorHeight),
      itemBuilder: (context, index) {
        final budget = budgets[index];
        return SwipeToDeleteRow(
          itemKey: ValueKey('budget-${budget.id}'),
          itemName: _budgetDisplayName(budget, viewState.ledgerState),
          onDeleted: () => viewModel.deleteBudget(budget.id),
          child: BudgetCard(
            budget: budget,
            month: month,
            items: viewState.items,
            state: viewState.ledgerState,
            isSubcategory: viewState.isSubcategoryBudget(budget),
            onTap: () => viewModel.requestBudgetDetail(budget.id),
          ),
        );
      },
    );
  }

  String _budgetDisplayName(Budget budget, LedgerState state) {
    final categoryID = budget.categoryID;
    if (categoryID == null) return _overallName;
    return state.categories[categoryID]?.name ?? _deletedCategoryName;
  }
}
