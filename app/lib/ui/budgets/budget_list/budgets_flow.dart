import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_screen.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_edit_sheet.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_category_picker.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_form.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_form_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_scope_options.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_selection.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/shell_sheet_occupancy.dart';

// MARK: - BudgetsFlow
class BudgetsFlow extends FlowBase<BudgetsStep> {
  const BudgetsFlow({super.key});

  @override
  ConsumerState<BudgetsFlow> createState() => _BudgetsFlowState();
}

// MARK: - BudgetsFlowState
class _BudgetsFlowState extends FlowBaseState<BudgetsStep, BudgetsFlow> {
  bool _destinationActive = true;
  bool _reconcileScheduled = false;
  bool _limitEditorOpen = false;
  String? _shownBudgetID;
  List<ProviderSubscription<Object?>> _shownSubscriptions = const [];
  ModalRoute<Object?>? _page;
  String? _pageBudgetID;
  final Set<ModalRoute<Object?>> _flowRemovedPages = {};
  NavigatorState? _rootNavigator;

  late final ProviderSubscription<String?> _selectionSubscription;
  late final ProviderSubscription<ShellLayoutMode> _modeSubscription;
  late final ProviderSubscription<Ledger?> _ledgerSubscription;
  late final ProviderSubscription<ShellSheetOccupancy> _occupancySubscription;

  _FormSession? _formSession;

  // MARK: - Lifecycle

  @override
  void initState() {
    super.initState();
    _selectionSubscription = ref.listenManual(selectedBudgetProvider, (
      _,
      selection,
    ) {
      _showBudget(selection);
      _scheduleReconcile();
    });
    _modeSubscription = ref.listenManual(
      shellLayoutModeProvider,
      (_, _) => _scheduleReconcile(),
    );
    _ledgerSubscription = ref.listenManual(ledgerProvider, (previous, next) {
      if (identical(previous, next)) return;
      ref.read(selectedBudgetProvider.notifier).clear();
    });
    _occupancySubscription = ref.listenManual(
      shellSheetOccupancyProvider,
      (_, _) => _scheduleReconcile(),
    );
    _showBudget(ref.read(selectedBudgetProvider));
    _scheduleReconcile();
  }

  @override
  void dispose() {
    _occupancySubscription.close();
    _selectionSubscription.close();
    _modeSubscription.close();
    _ledgerSubscription.close();
    _showBudget(null);
    _removePageAfterFrame();
    _formSession?.subscription?.close();
    _formSession = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = DestinationActivity.of(context);
    if (active && !_destinationActive) _scheduleResume();
    _destinationActive = active;
    return super.build(context);
  }

  // MARK: - View Model Contracts

  BudgetsListViewModel get _listViewModel =>
      ref.read(budgetsListViewModelProvider.notifier);

  BudgetDetailViewModel _detailViewModel(String budgetID) =>
      ref.read(budgetDetailViewModelProvider(budgetID).notifier);

  BudgetFormViewModel _formViewModel(BudgetDraftKey draftKey) =>
      ref.read(budgetFormViewModelProvider(draftKey).notifier);

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
    if (!_destinationActive) return;
    switch (step) {
      case BudgetFormRequested():
        _openBudgetForm(context);
      case BudgetLimitEditRequested():
      case PickCategoryRequested():
      case BudgetFormSaved():
        break;
    }
    _listViewModel.clearStep();
  }

  // MARK: - Detail Page

  void _scheduleReconcile() {
    if (_reconcileScheduled) return;
    _reconcileScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _reconcileScheduled = false;
      if (mounted) _reconcilePage();
    });
  }

  void _scheduleResume() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _consumePendingSteps();
      _reconcilePage();
    });
  }

  void _reconcilePage() {
    final selected = ref.read(selectedBudgetProvider);
    final phone = ref.read(shellLayoutModeProvider) == ShellLayoutMode.phone;
    final wanted = phone ? selected : null;
    if (_pageBudgetID == wanted) return;
    _removePage();
    final context = navigatorContext;
    if (wanted == null || !_destinationActive || context == null) return;
    if (ref.read(shellSheetOccupancyProvider).hasSheets) return;
    _pushPage(context, wanted);
  }

  void _pushPage(BuildContext context, String budgetID) {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = MaterialPageRoute<Object?>(
      builder: (_) => BudgetDetailScreen(budgetID: budgetID),
    );
    _rootNavigator = navigator;
    _page = route;
    _pageBudgetID = budgetID;
    unawaited(navigator.push(route));
    unawaited(_clearSelectionWhenPopped(route, budgetID));
  }

  Future<void> _clearSelectionWhenPopped(
    ModalRoute<Object?> route,
    String budgetID,
  ) async {
    await route.completed;
    if (_flowRemovedPages.remove(route) || !mounted) return;
    if (identical(_page, route)) {
      _page = null;
      _pageBudgetID = null;
    }
    if (ref.read(selectedBudgetProvider) != budgetID) return;
    ref.read(selectedBudgetProvider.notifier).clear();
  }

  void _removePage() {
    final route = _page;
    _page = null;
    _pageBudgetID = null;
    if (route == null || !route.isActive) return;
    _flowRemovedPages.add(route);
    _rootNavigator?.removeRoute(route);
  }

  void _removePageAfterFrame() {
    final route = _page;
    final navigator = _rootNavigator;
    _page = null;
    if (route == null || navigator == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted && route.isActive) navigator.removeRoute(route);
    });
  }

  // MARK: - Budget Subscriptions

  void _showBudget(String? budgetID) {
    if (_shownBudgetID == budgetID) return;
    for (final subscription in _shownSubscriptions) {
      subscription.close();
    }
    _shownBudgetID = budgetID;
    _shownSubscriptions = budgetID == null ? const [] : _openOwners(budgetID);
  }

  List<ProviderSubscription<Object?>> _openOwners(String budgetID) {
    final context = ref.listenManual(
      budgetDetailContextProvider(budgetID),
      (_, _) {},
    );
    final detail = ref.listenManual(
      budgetDetailViewModelProvider(budgetID),
      (_, next) => unawaited(_handleDetailStep(budgetID, next.value?.step)),
    );
    return [context, detail];
  }

  void _consumePendingSteps() {
    final context = navigatorContext;
    if (context == null || !_destinationActive) return;
    final listStep = ref.read(budgetsListViewModelProvider).value?.step;
    if (listStep != null) handleStep(context, listStep);
    final budgetID = _shownBudgetID;
    if (budgetID == null) return;
    final detail = ref.read(budgetDetailViewModelProvider(budgetID));
    unawaited(_handleDetailStep(budgetID, detail.value?.step));
  }

  Future<void> _handleDetailStep(String budgetID, BudgetsStep? step) async {
    if (step is! BudgetLimitEditRequested) return;
    if (!_destinationActive || _shownBudgetID != budgetID) return;
    final context = navigatorContext;
    if (context == null) return;

    final detail = _detailViewModel(budgetID);
    detail.clearStep();
    if (_limitEditorOpen) return;
    final current = detail.liveLimit;
    if (current == null) return;

    _limitEditorOpen = true;
    final capturedLedger = ref.read(ledgerProvider);
    final Decimal? entered;
    try {
      entered = await showBudgetLimitEditSheet(
        context: context,
        current: current,
      );
    } finally {
      _limitEditorOpen = false;
    }
    if (!mounted || _shownBudgetID != budgetID) return;
    if (!identical(ref.read(ledgerProvider), capturedLedger)) return;
    detail.applyLimit(entered);
  }

  // MARK: - Form Navigation

  void _endFormSession(_FormSession session) {
    session.subscription?.close();
    session.subscription = null;
    if (identical(_formSession, session)) _formSession = null;
  }

  void _openBudgetForm(BuildContext context) {
    if (_formSession != null) return;
    final draftKey = BudgetDraftKey();
    final session = _FormSession(draftKey);
    _formSession = session;
    session.subscription = ref.listenManual(
      budgetFormViewModelProvider(draftKey),
      (previous, next) => unawaited(_handleFormStep(session, next.value?.step)),
    );
    unawaited(
      showBudgetFormSheet(
        context: context,
        draftKey: draftKey,
        onRouteCreated: (route) {
          session.route = route;
          unawaited(route.completed.then((_) => _endFormSession(session)));
        },
      ),
    );
  }

  void _dismissFormRoute(_FormSession session) {
    final route = session.route;
    final navigator = route?.navigator;
    if (route == null || navigator == null || !route.isActive) return;
    // A non-current form route sits under the picker; pop() would close the picker instead.
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  Future<void> _handleFormStep(_FormSession session, BudgetsStep? step) async {
    if (step == null) return;
    switch (step) {
      case PickCategoryRequested():
        await _pickScope(session);
      case BudgetFormSaved():
        _dismissFormRoute(session);
        _formViewModel(session.draftKey).clearStep();
      case BudgetFormRequested():
      case BudgetLimitEditRequested():
        break;
    }
  }

  Future<void> _pickScope(_FormSession session) async {
    final context = navigatorContext;
    final formState = ref
        .read(budgetFormViewModelProvider(session.draftKey))
        .value;
    if (context == null || formState == null) return;
    _formViewModel(session.draftKey).clearStep();

    final chosen = await showBudgetCategoryPickerSheet(
      context: context,
      options: budgetScopeOptions(formState.ledgerState),
      selected: formState.scope,
    );
    final formRoute = session.route;
    if (chosen == null || !mounted || !identical(_formSession, session)) return;
    if (formRoute == null || !formRoute.isActive) return;
    _formViewModel(session.draftKey).applyPickedScope(chosen);
  }

  @override
  Widget buildRoot(BuildContext context) => const BudgetsRoot();
}

// MARK: - FormSession
class _FormSession {
  _FormSession(this.draftKey);

  final BudgetDraftKey draftKey;
  AppSheetRoute<void>? route;
  ProviderSubscription<AsyncValue<BudgetFormViewState>>? subscription;
}
