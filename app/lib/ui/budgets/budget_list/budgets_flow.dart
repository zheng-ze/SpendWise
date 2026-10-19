import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/budgets/budget_detail/budget_detail_screen.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_edit_sheet.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_screen.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_category_picker.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_form.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_form_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';

// MARK: - BudgetsFlow
class BudgetsFlow extends FlowBase<BudgetsStep> {
  const BudgetsFlow({super.key});

  @override
  ConsumerState<BudgetsFlow> createState() => _BudgetsFlowState();
}

// MARK: - BudgetsFlowState
class _BudgetsFlowState extends FlowBaseState<BudgetsStep, BudgetsFlow> {
  ProviderSubscription<AsyncValue<BudgetDetailViewState>>? _detailSubscription;
  ProviderSubscription<AsyncValue<BudgetLimitViewState>>? _limitSubscription;
  String? _openBudgetID;

  ProviderSubscription<AsyncValue<BudgetFormViewState>>? _formSubscription;

  // MARK: - Lifecycle

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
    _closeBudgetSubscriptions();
    _formSubscription?.close();
    super.dispose();
  }

  // MARK: - View Model Contracts

  BudgetsListViewModel get _listViewModel =>
      ref.read(budgetsListViewModelProvider.notifier);

  BudgetDetailViewModel _detailViewModel(String budgetID) =>
      ref.read(budgetDetailViewModelProvider(budgetID).notifier);

  BudgetLimitViewModel _limitViewModel(String budgetID) =>
      ref.read(budgetLimitViewModelProvider(budgetID).notifier);

  BudgetFormViewModel get _formViewModel =>
      ref.read(budgetFormViewModelProvider.notifier);

  // MARK: - List Navigation

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
        unawaited(_openBudget(context, budgetID));
      case BudgetFormRequested():
        showBudgetFormSheet(context: context);
      case BudgetLimitEditRequested():
      case PickLimitRequested():
      case PickCategoryRequested():
      case BudgetFormSaved():
        break;
    }
    _listViewModel.clearStep();
  }

  // MARK: - Budget Navigation

  void _closeBudgetSubscriptions() {
    _detailSubscription?.close();
    _limitSubscription?.close();
    _detailSubscription = null;
    _limitSubscription = null;
    _openBudgetID = null;
  }

  Future<void> _openBudget(BuildContext context, String budgetID) async {
    _closeBudgetSubscriptions();
    _openBudgetID = budgetID;
    final detailSubscription = ref.listenManual(
      budgetDetailViewModelProvider(budgetID),
      (previous, next) => _handleDetailStep(budgetID, next.value?.step),
    );
    _detailSubscription = detailSubscription;
    _limitSubscription = ref.listenManual(
      budgetLimitViewModelProvider(budgetID),
      (previous, next) => _handleLimitStep(budgetID, next.value?.step),
    );
    final route = MaterialPageRoute<void>(
      builder: (_) => BudgetDetailScreen(budgetID: budgetID),
    );
    unawaited(Navigator.of(context, rootNavigator: true).push(route));
    await route.completed;
    if (!identical(_detailSubscription, detailSubscription)) return;
    _closeBudgetSubscriptions();
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
        break;
    }
    _detailViewModel(budgetID).clearStep();
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
    _limitViewModel(budgetID).applyPickedLimit(entered);
  }

  // MARK: - Form Navigation

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
        _formViewModel.applyPickedCategory(
          chosen == budgetFormOverallSentinel ? null : chosen,
        );
      case BudgetFormSaved():
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        _formViewModel.clearStep();
      case BudgetDetailRequested():
      case BudgetFormRequested():
      case BudgetLimitEditRequested():
      case PickLimitRequested():
        break;
    }
  }

  @override
  Widget buildRoot(BuildContext context) => const BudgetsRoot();
}
