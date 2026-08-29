import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/budgets/budget_card.dart';
import 'package:spendwise/ui/budgets/budget_detail_screen.dart';
import 'package:spendwise/ui/budgets/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_form.dart';
import 'package:spendwise/ui/budgets/budget_form_view_model.dart';
import 'package:spendwise/ui/budgets/budget_limit_screen.dart';
import 'package:spendwise/ui/budgets/budget_limit_view_model.dart';
import 'package:spendwise/ui/budgets/budgets_list_view_model.dart';
import 'package:spendwise/ui/common/expanding_fab.dart';
import 'package:spendwise/ui/common/flow_base.dart';
import 'package:spendwise/ui/common/swipe_to_delete_row.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

/// Owns the budgets tab's own nested Navigator, mediating `BudgetsStep`
/// (ADR-0059's one-Step-type-per-Flow rule — `TransactionsStep` shared by
/// `TransactionsViewModel` and `EntryFormViewModel` is the precedent).
/// Mounted for the budgets tab's whole lifetime, not per-budget: it renders
/// the budgets list itself, so it can own opening a budget's detail screen,
/// editing that budget's limit, and adding a new budget. A budget's detail
/// and limit screens push onto the app's root Navigator instead of this
/// Flow's own, so they cover the tab row and month selector
/// `StatsRootScreen` renders above this Flow.
class BudgetsFlow extends FlowBase<BudgetsStep> {
  const BudgetsFlow({super.key});

  @override
  ConsumerState<BudgetsFlow> createState() => _BudgetsFlowState();
}

class _BudgetsFlowState extends FlowBaseState<BudgetsStep, BudgetsFlow> {
  // Re-created per opened budget, since BudgetDetailViewModel/
  // BudgetLimitViewModel are family instances keyed by budgetID — mirrors
  // TransactionsFlow._formSubscription's lazy-subscribe-on-open shape.
  ProviderSubscription<AsyncValue<BudgetDetailViewState>>? _detailSubscription;
  ProviderSubscription<AsyncValue<BudgetLimitViewState>>? _limitSubscription;
  String? _openBudgetID;

  // Not a family, so this can be subscribed to once, upfront.
  ProviderSubscription<AsyncValue<BudgetFormViewState>>? _formSubscription;

  @override
  void initState() {
    super.initState();
    _formSubscription = ref.listenManual(
      budgetFormViewModelProvider,
      (previous, next) => _handleFormStep(next.value?.step),
    );
  }

  @override
  void dispose() {
    _detailSubscription?.close();
    _limitSubscription?.close();
    _formSubscription?.close();
    super.dispose();
  }

  BudgetsListViewModel get _listViewModel =>
      ref.read(budgetsListViewModelProvider.notifier);

  @override
  void Function() subscribeToStep(void Function(BudgetsStep? step) handle) =>
      ref
          .listenManual(
            budgetsListViewModelProvider,
            (previous, AsyncValue<BudgetsListViewState> next) =>
                handle(next.value?.step),
          )
          .close;

  @override
  void handleStep(BuildContext context, BudgetsStep step) {
    switch (step) {
      case BudgetDetailRequested(:final budgetID):
        _openBudget(context, budgetID);
      case BudgetFormRequested():
        showBudgetFormSheet(context: context);
      case BudgetLimitEditRequested():
      case PickLimitRequested():
      case PickCategoryRequested():
      case BudgetFormSaved():
        // These variants are only ever emitted by a budget-detail, limit, or
        // form ViewModel's own state, handled by the other handlers below.
        break;
    }
    _listViewModel.clearStep();
  }

  void _openBudget(BuildContext context, String budgetID) {
    _detailSubscription?.close();
    _limitSubscription?.close();
    _openBudgetID = budgetID;
    _detailSubscription = ref.listenManual(
      budgetDetailViewModelProvider(budgetID),
      (previous, next) => _handleDetailStep(budgetID, next.value?.step),
    );
    _limitSubscription = ref.listenManual(
      budgetLimitViewModelProvider(budgetID),
      (previous, next) => _handleLimitStep(budgetID, next.value?.step),
    );
    final route = MaterialPageRoute<void>(
      builder: (_) => BudgetDetailScreen(budgetID: budgetID),
    );
    Navigator.of(context, rootNavigator: true).push(route);
  }

  void _handleDetailStep(String budgetID, BudgetsStep? step) {
    if (step == null) return;
    if (_openBudgetID != budgetID) return;
    final context = navigatorContext;
    if (context == null) return;

    switch (step) {
      case BudgetLimitEditRequested():
        final route = MaterialPageRoute<void>(
          builder: (_) => BudgetLimitScreen(budgetID: budgetID),
        );
        Navigator.of(context, rootNavigator: true).push(route);
      case BudgetDetailRequested():
      case BudgetFormRequested():
      case PickLimitRequested():
      case PickCategoryRequested():
      case BudgetFormSaved():
        // Only BudgetDetailViewModel emits BudgetLimitEditRequested;
        // unreachable here.
        break;
    }
    ref.read(budgetDetailViewModelProvider(budgetID).notifier).clearStep();
  }

  Future<void> _handleLimitStep(String budgetID, BudgetsStep? step) async {
    if (step == null) return;
    if (_openBudgetID != budgetID) return;
    if (step is! PickLimitRequested) return;
    final context = navigatorContext;
    if (context == null) return;

    final entered = await showBudgetLimitEditSheet(
      context: context,
      target: step.target,
    );
    // applyPickedLimit clears the step itself, reading the pending
    // PickLimitRequested to find its edit target first — clearing it here
    // first would make that lookup a no-op.
    ref
        .read(budgetLimitViewModelProvider(budgetID).notifier)
        .applyPickedLimit(entered);
  }

  Future<void> _handleFormStep(BudgetsStep? step) async {
    if (step == null) return;
    final context = navigatorContext;
    if (context == null) return;

    switch (step) {
      case PickCategoryRequested():
        final formState = ref.read(budgetFormViewModelProvider).value;
        if (formState == null) return;
        final chosen = await showBudgetCategoryPickerSheet(
          context: context,
          formState: formState,
        );
        if (!context.mounted) return;
        ref
            .read(budgetFormViewModelProvider.notifier)
            .applyPickedCategory(
              chosen == budgetFormOverallSentinel ? null : chosen,
            );
      case BudgetFormSaved():
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        ref.read(budgetFormViewModelProvider.notifier).clearStep();
      case BudgetDetailRequested():
      case BudgetFormRequested():
      case BudgetLimitEditRequested():
      case PickLimitRequested():
        // Only BudgetFormViewModel emits these; unreachable here.
        break;
    }
  }

  @override
  Widget buildRoot(BuildContext context) => const _BudgetsRoot();
}

class _BudgetsRoot extends ConsumerWidget {
  const _BudgetsRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(budgetsListViewModelProvider);
    final viewModel = ref.watch(budgetsListViewModelProvider.notifier);
    final month = YearMonth.fromUtc(ref.watch(selectedMonthProvider));

    return asyncState.when(
      data: (viewState) => _BudgetsRootBody(
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

class _BudgetsRootBody extends StatelessWidget {
  const _BudgetsRootBody({
    required this.viewState,
    required this.viewModel,
    required this.month,
  });

  final BudgetsListViewState viewState;
  final BudgetsListViewModel viewModel;
  final YearMonth month;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            _BudgetsList(
              viewState: viewState,
              viewModel: viewModel,
              month: month,
            ),
            ExpandingFab(
              primary: FabAction(
                label: 'Add Budget',
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

class _BudgetsList extends StatelessWidget {
  const _BudgetsList({
    required this.viewState,
    required this.viewModel,
    required this.month,
  });

  final BudgetsListViewState viewState;
  final BudgetsListViewModel viewModel;
  final YearMonth month;

  @override
  Widget build(BuildContext context) {
    final budgets = viewState.budgets;

    if (budgets.isEmpty) return const BudgetsEmptyState();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: budgets.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
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
    if (categoryID == null) return 'Overall';
    return state.categories[categoryID]?.name ?? '(category deleted)';
  }
}
