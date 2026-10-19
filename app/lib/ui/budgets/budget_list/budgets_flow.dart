import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/budgets/budget_detail/budget_detail_screen.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_edit_sheet.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_screen.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_view_model.dart';
import 'package:spendwise/ui/budgets/budget_host.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_category_picker.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_form.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_form_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';

// MARK: - BudgetsFlow
class BudgetsFlow extends FlowBase<BudgetsStep> {
  const BudgetsFlow({super.key, required this.host});

  final BudgetHost host;

  @override
  ConsumerState<BudgetsFlow> createState() => _BudgetsFlowState();
}

// MARK: - BudgetsFlowState
class _BudgetsFlowState extends FlowBaseState<BudgetsStep, BudgetsFlow> {
  ProviderSubscription<AsyncValue<BudgetDetailViewState>>? _detailSubscription;
  ProviderSubscription<AsyncValue<BudgetLimitViewState>>? _limitSubscription;
  String? _openBudgetID;

  ProviderSubscription<AsyncValue<BudgetFormViewState>>? _formSubscription;
  BudgetDraftKey? _openDraftKey;
  bool _active = false;

  // MARK: - Lifecycle

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = DestinationActivity.of(context);
    final becameActive = active && !_active;
    _active = active;
    if (becameActive) WidgetsBinding.instance.addPostFrameCallback(_pickUpStep);
  }

  @override
  void dispose() {
    _closeBudgetSubscriptions();
    _closeFormSubscription();
    super.dispose();
  }

  void _pickUpStep(Duration _) {
    if (!mounted) return;
    final navContext = navigatorContext;
    if (navContext == null) return;
    final pending = ref.read(budgetsListViewModelProvider(widget.host)).value;
    final step = pending?.step;
    if (step != null) handleStep(navContext, step);
  }

  // MARK: - View Model Contracts

  HostedBudget _hosted(String budgetID) =>
      (host: widget.host, budgetID: budgetID);

  BudgetsListViewModel get _listViewModel =>
      ref.read(budgetsListViewModelProvider(widget.host).notifier);

  BudgetDetailViewModel _detailViewModel(String budgetID) =>
      ref.read(budgetDetailViewModelProvider(_hosted(budgetID)).notifier);

  BudgetLimitViewModel _limitViewModel(String budgetID) =>
      ref.read(budgetLimitViewModelProvider(_hosted(budgetID)).notifier);

  BudgetFormViewModel _formViewModel(BudgetDraftKey draftKey) =>
      ref.read(budgetFormViewModelProvider(draftKey).notifier);

  // MARK: - List Navigation

  @override
  void Function() subscribeToStep(void Function(BudgetsStep? step) handle) =>
      ref
          .listenManual(
            budgetsListViewModelProvider(widget.host),
            (previous, AsyncValue<BudgetsListViewState> next) =>
                handle(next.value?.step),
          )
          .close;

  @override
  void handleStep(BuildContext context, BudgetsStep step) {
    if (!DestinationActivity.of(context)) return;
    final current = ref
        .read(budgetsListViewModelProvider(widget.host))
        .value
        ?.step;
    if (!identical(current, step)) return;
    switch (step) {
      case BudgetDetailRequested(:final budgetID):
        unawaited(_openBudget(context, budgetID));
      case BudgetFormRequested():
        _openBudgetForm(context);
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
      budgetDetailViewModelProvider(_hosted(budgetID)),
      (previous, next) => _handleDetailStep(budgetID, next.value?.step),
    );
    _detailSubscription = detailSubscription;
    _limitSubscription = ref.listenManual(
      budgetLimitViewModelProvider(_hosted(budgetID)),
      (previous, next) => _handleLimitStep(budgetID, next.value?.step),
    );
    final route = MaterialPageRoute<void>(
      builder: (_) => BudgetDetailScreen(hostedBudget: _hosted(budgetID)),
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
          builder: (_) => BudgetLimitScreen(hostedBudget: _hosted(budgetID)),
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

  void _closeFormSubscription() {
    _formSubscription?.close();
    _formSubscription = null;
    _openDraftKey = null;
  }

  void _openBudgetForm(BuildContext context) {
    _closeFormSubscription();
    final draftKey = BudgetDraftKey();
    _openDraftKey = draftKey;
    _formSubscription = ref.listenManual(
      budgetFormViewModelProvider(draftKey),
      (previous, next) => _handleFormStep(draftKey, next.value?.step),
    );
    showBudgetFormSheet(context: context, draftKey: draftKey).whenComplete(() {
      if (identical(_openDraftKey, draftKey)) _closeFormSubscription();
    });
  }

  Future<void> _handleFormStep(
    BudgetDraftKey draftKey,
    BudgetsStep? step,
  ) async {
    if (step == null) return;
    final context = navigatorContext;
    if (context == null) return;

    switch (step) {
      case PickCategoryRequested():
        final formState = ref.read(budgetFormViewModelProvider(draftKey)).value;
        if (formState == null) return;
        final chosen = await showBudgetCategoryPickerSheet(
          context: context,
          formState: formState,
        );
        if (!context.mounted || !identical(_openDraftKey, draftKey)) return;
        _formViewModel(draftKey).applyPickedCategory(
          chosen == budgetFormOverallSentinel ? null : chosen,
        );
      case BudgetFormSaved():
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        _formViewModel(draftKey).clearStep();
      case BudgetDetailRequested():
      case BudgetFormRequested():
      case BudgetLimitEditRequested():
      case PickLimitRequested():
        break;
    }
  }

  @override
  Widget buildRoot(BuildContext context) => BudgetsRoot(host: widget.host);
}
