import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_screen.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_edit_sheet.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_screen.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_category_picker.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_form.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_form_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_selection.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

// MARK: - BudgetsFlow
class BudgetsFlow extends FlowBase<BudgetsStep> {
  const BudgetsFlow({super.key});

  @override
  ConsumerState<BudgetsFlow> createState() => _BudgetsFlowState();
}

// MARK: - Owned Budget Session
class _BudgetSession {
  _BudgetSession({
    required this.budgetID,
    required this.generation,
    required this.contextSubscription,
    required this.detailSubscription,
    required this.limitSubscription,
  });

  final String budgetID;
  final int generation;
  final ProviderSubscription<BudgetDetailContext> contextSubscription;
  final ProviderSubscription<AsyncValue<BudgetDetailViewState>>
  detailSubscription;
  final ProviderSubscription<AsyncValue<BudgetLimitViewState>>
  limitSubscription;
  final Set<ModalRoute<void>> descendants = {};

  void close() {
    contextSubscription.close();
    detailSubscription.close();
    limitSubscription.close();
  }
}

// MARK: - Managed Detail Page
class _DetailPage {
  _DetailPage({
    required this.route,
    required this.budgetID,
    required this.generation,
  });

  final ModalRoute<void> route;
  final ValueNotifier<String> budgetID;
  int generation;
}

// MARK: - BudgetsFlowState
class _BudgetsFlowState extends FlowBaseState<BudgetsStep, BudgetsFlow> {
  _BudgetSession? _session;
  final _retiredSessions = <_BudgetSession>[];
  _DetailPage? _page;
  bool _destinationActive = true;
  bool _restoreDeferred = false;
  bool _reconcileScheduled = false;
  bool _limitSheetPresented = false;
  NavigatorState? _rootNavigator;
  Animation<double>? _coverAnimation;

  late final ProviderSubscription<BudgetSelection?> _selectionSubscription;
  late final ProviderSubscription<ShellLayoutMode> _modeSubscription;
  late final ProviderSubscription<Ledger?> _ledgerSubscription;

  ProviderSubscription<AsyncValue<BudgetFormViewState>>? _formSubscription;
  BudgetDraftKey? _openDraftKey;

  // MARK: - Lifecycle

  @override
  void initState() {
    super.initState();
    _selectionSubscription = ref.listenManual(
      selectedBudgetProvider,
      (_, _) => _scheduleReconcile(),
    );
    _modeSubscription = ref.listenManual(
      shellLayoutModeProvider,
      (_, _) => _scheduleReconcile(),
    );
    _ledgerSubscription = ref.listenManual(ledgerProvider, (previous, next) {
      if (identical(previous, next)) return;
      ref.read(selectedBudgetProvider.notifier).clear();
    });
  }

  @override
  void dispose() {
    _selectionSubscription.close();
    _modeSubscription.close();
    _ledgerSubscription.close();
    _coverAnimation?.removeListener(_scheduleReconcile);
    _coverAnimation = null;
    _removeOwnedRoutesAfterFrame(_ownedRoutes());
    _session?.close();
    _session = null;
    for (final session in _retiredSessions) {
      session.close();
    }
    _retiredSessions.clear();
    _closeFormSubscription();
    super.dispose();
  }

  List<ModalRoute<void>> _ownedRoutes() {
    final page = _page;
    final routes = [
      ?page?.route,
      ...?_session?.descendants,
      for (final session in _retiredSessions) ...session.descendants,
    ];
    _page = null;
    return routes;
  }

  void _removeOwnedRoutesAfterFrame(List<ModalRoute<void>> routes) {
    final navigator = _rootNavigator;
    if (navigator == null || routes.isEmpty) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!navigator.mounted) return;
      for (final route in routes) {
        if (route.isActive) navigator.removeRoute(route);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _destinationActive = DestinationActivity.of(context);
    _scheduleReconcile();
    return super.build(context);
  }

  // MARK: - View Model Contracts

  BudgetsListViewModel get _listViewModel =>
      ref.read(budgetsListViewModelProvider.notifier);

  BudgetDetailViewModel _detailViewModel(String budgetID) =>
      ref.read(budgetDetailViewModelProvider(budgetID).notifier);

  BudgetLimitViewModel _limitViewModel(String budgetID) =>
      ref.read(budgetLimitViewModelProvider(budgetID).notifier);

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
      case PickLimitRequested():
      case PickCategoryRequested():
      case BudgetFormSaved():
        break;
    }
    _listViewModel.clearStep();
  }

  // MARK: - Reconciliation

  void _scheduleReconcile() {
    if (_reconcileScheduled) return;
    _reconcileScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _reconcileScheduled = false;
      if (mounted) _reconcile();
    });
  }

  void _reconcile() {
    _consumePendingListStep();
    final selection = ref.read(selectedBudgetProvider);
    if (selection == null) {
      _removePage();
      _retireSession();
      return;
    }
    _ensureSession(selection);
    final open = ref.read(shellLayoutModeProvider) == ShellLayoutMode.open;
    if (open) {
      _removePage();
      return;
    }
    final page = _page;
    if (page != null) {
      page.budgetID.value = selection.budgetID;
      page.generation = selection.generation;
      return;
    }
    _presentPage(selection);
  }

  void _consumePendingListStep() {
    final pending = ref.read(budgetsListViewModelProvider).value?.step;
    final context = navigatorContext;
    if (pending == null || context == null) return;
    handleStep(context, pending);
  }

  void _presentPage(BudgetSelection selection) {
    if (!_destinationActive) return;
    final context = navigatorContext;
    if (context == null) return;
    if (!(ModalRoute.isCurrentOf(context) ?? true)) {
      _restoreDeferred = true;
      _listenForCoverRemoval(context);
      return;
    }
    final budgetID = ValueNotifier(selection.budgetID);
    final route = _detailPageRoute(budgetID, restored: _restoreDeferred);
    _restoreDeferred = false;
    final page = _DetailPage(
      route: route,
      budgetID: budgetID,
      generation: selection.generation,
    );
    _page = page;
    _rootNavigatorOf(context).push(route);
    unawaited(_watchPage(page));
  }

  void _listenForCoverRemoval(BuildContext context) {
    final animation = ModalRoute.of(context)?.secondaryAnimation;
    if (animation == null || identical(animation, _coverAnimation)) return;
    _coverAnimation?.removeListener(_scheduleReconcile);
    _coverAnimation = animation..addListener(_scheduleReconcile);
  }

  NavigatorState _rootNavigatorOf(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    _rootNavigator = navigator;
    return navigator;
  }

  void _removePage() {
    final page = _page;
    if (page == null) return;
    _page = null;
    final context = navigatorContext;
    if (context == null) return;
    final navigator = _rootNavigatorOf(context);
    if (page.route.isActive) navigator.removeRoute(page.route);
  }

  Future<void> _watchPage(_DetailPage page) async {
    await page.route.completed;
    if (!mounted || !identical(_page, page)) return;
    _page = null;
    final selection = ref.read(selectedBudgetProvider);
    if (selection?.generation == page.generation) {
      ref.read(selectedBudgetProvider.notifier).clear();
    }
    _scheduleReconcile();
  }

  ModalRoute<void> _detailPageRoute(
    ValueNotifier<String> budgetID, {
    required bool restored,
  }) {
    Widget page(BuildContext context) => ValueListenableBuilder<String>(
      valueListenable: budgetID,
      builder: (context, id, child) => BudgetDetailScreen(budgetID: id),
    );
    if (!restored) return MaterialPageRoute<void>(builder: page);
    return PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => page(context),
    );
  }

  // MARK: - Budget Sessions

  void _ensureSession(BudgetSelection selection) {
    final current = _session;
    if (current != null && current.generation == selection.generation) return;
    _retireSession();
    _session = _openSession(selection);
  }

  _BudgetSession _openSession(BudgetSelection selection) {
    final budgetID = selection.budgetID;
    final generation = selection.generation;
    return _BudgetSession(
      budgetID: budgetID,
      generation: generation,
      contextSubscription: ref.listenManual(
        budgetDetailContextProvider(budgetID),
        (_, _) {},
      ),
      detailSubscription: ref.listenManual(
        budgetDetailViewModelProvider(budgetID),
        (previous, next) =>
            _handleDetailStep(generation, budgetID, next.value?.step),
      ),
      limitSubscription: ref.listenManual(
        budgetLimitViewModelProvider(budgetID),
        (previous, next) =>
            _handleLimitStep(generation, budgetID, next.value?.step),
      ),
    );
  }

  void _retireSession() {
    final session = _session;
    if (session == null) return;
    _session = null;
    if (session.descendants.isEmpty) {
      session.close();
      return;
    }
    _retiredSessions.add(session);
  }

  Future<void> _watchDescendant(
    _BudgetSession session,
    ModalRoute<void> route,
  ) async {
    session.descendants.add(route);
    await route.completed;
    if (!mounted) return;
    session.descendants.remove(route);
    if (session.descendants.isEmpty && _retiredSessions.remove(session)) {
      session.close();
    }
    _scheduleReconcile();
  }

  void _handleDetailStep(int generation, String budgetID, BudgetsStep? step) {
    final session = _session;
    if (step == null || session == null) return;
    if (session.generation != generation) return;
    final context = navigatorContext;
    if (context == null) return;

    if (step is BudgetLimitEditRequested) {
      final route = MaterialPageRoute<void>(
        builder: (_) => BudgetLimitScreen(budgetID: budgetID),
      );
      _rootNavigatorOf(context).push(route);
      unawaited(_watchDescendant(session, route));
    }
    _detailViewModel(budgetID).clearStep();
  }

  Future<void> _handleLimitStep(
    int generation,
    String budgetID,
    BudgetsStep? step,
  ) async {
    if (step is! PickLimitRequested) return;
    if (_session?.generation != generation) return;
    if (_limitSheetPresented) return;
    final context = navigatorContext;
    if (context == null) return;

    final capturedLedger = ref.read(ledgerProvider);
    _limitSheetPresented = true;
    final entered = await showBudgetLimitEditSheet(
      context: context,
      target: step.target,
    );
    _limitSheetPresented = false;
    if (!mounted || _session?.generation != generation) return;
    if (!identical(ref.read(ledgerProvider), capturedLedger)) return;
    if (ref.read(selectedBudgetProvider)?.budgetID != budgetID) return;
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
      case BudgetFormRequested():
      case BudgetLimitEditRequested():
      case PickLimitRequested():
        break;
    }
  }

  @override
  Widget buildRoot(BuildContext context) => const BudgetsRoot();
}
