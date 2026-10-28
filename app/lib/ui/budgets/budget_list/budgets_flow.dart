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

typedef _ManagedRoute = ModalRoute<Object?>;

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
  final Set<_ManagedRoute> descendants = {};

  void close() {
    contextSubscription.close();
    detailSubscription.close();
    limitSubscription.close();
  }
}

// MARK: - Managed Detail Page
class _DetailPage {
  _DetailPage({required this.route, required this.generation});

  final _ManagedRoute route;
  final int generation;
  bool removedForPresentation = false;
}

// MARK: - BudgetsFlowState
class _BudgetsFlowState extends FlowBaseState<BudgetsStep, BudgetsFlow> {
  _BudgetSession? _session;
  final _retiredSessions = <_BudgetSession>[];
  _DetailPage? _page;
  bool _destinationActive = true;
  bool _restoreDeferred = false;
  bool _reconcileScheduled = false;
  Object? _limitOperation;
  NavigatorState? _rootNavigator;
  bool _ownerExposed = true;

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
      _discardOwnedRoutesAfterFrame();
    });
  }

  @override
  void dispose() {
    _selectionSubscription.close();
    _modeSubscription.close();
    _ledgerSubscription.close();
    final page = _page;
    _page = null;
    _removeRoutesAfterFrame([
      ?page?.route,
      for (final session in _allSessions()) ...session.descendants,
    ]);
    for (final session in _allSessions()) {
      session.close();
    }
    _session = null;
    _retiredSessions.clear();
    _closeFormSubscription();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _destinationActive = DestinationActivity.of(context);
    _ownerExposed = ModalRoute.isCurrentOf(context) ?? true;
    _scheduleReconcile();
    return super.build(context);
  }

  Iterable<_BudgetSession> _allSessions() sync* {
    final current = _session;
    if (current != null) yield current;
    yield* _retiredSessions;
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
    _consumePendingSteps();
    final selection = ref.read(selectedBudgetProvider);
    if (selection == null) {
      _removePage();
      _retireSession();
      return;
    }
    _ensureSession(selection);
    if (ref.read(shellLayoutModeProvider) == ShellLayoutMode.open) {
      _removePage();
      return;
    }
    final page = _page;
    if (page != null && page.generation == selection.generation) return;
    if (page != null) _removePage();
    _presentPage(selection);
  }

  void _consumePendingSteps() {
    final context = navigatorContext;
    if (context == null || !_destinationActive) return;
    final listStep = ref.read(budgetsListViewModelProvider).value?.step;
    if (listStep != null) handleStep(context, listStep);
    final session = _session;
    if (session == null) return;
    _handleDetailStep(
      session.generation,
      session.budgetID,
      ref.read(budgetDetailViewModelProvider(session.budgetID)).value?.step,
    );
    unawaited(
      _handleLimitStep(
        session.generation,
        session.budgetID,
        ref.read(budgetLimitViewModelProvider(session.budgetID)).value?.step,
      ),
    );
  }

  void _presentPage(BudgetSelection selection) {
    if (!_destinationActive) return;
    final context = navigatorContext;
    if (context == null) return;
    if (!_ownerExposed) {
      _restoreDeferred = true;
      return;
    }
    final budgetID = selection.budgetID;
    final route = _detailPageRoute(budgetID, restored: _restoreDeferred);
    _restoreDeferred = false;
    final page = _DetailPage(route: route, generation: selection.generation);
    _page = page;
    _rootNavigatorOf(context).push(route);
    final session = _session;
    if (session != null) _adoptDescendant(session, route);
    unawaited(_watchPage(page));
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
    if (!page.route.isActive) return;
    page.removedForPresentation = true;
    final context = navigatorContext;
    if (context == null) return;
    final navigator = _rootNavigatorOf(context);
    if (page.route.isActive) navigator.removeRoute(page.route);
  }

  Future<void> _watchPage(_DetailPage page) async {
    await page.route.completed;
    if (!mounted || page.removedForPresentation) return;
    if (identical(_page, page)) _page = null;
    final selection = ref.read(selectedBudgetProvider);
    if (selection?.generation == page.generation) {
      ref.read(selectedBudgetProvider.notifier).clear();
    }
    _scheduleReconcile();
  }

  _ManagedRoute _detailPageRoute(String budgetID, {required bool restored}) {
    Widget page(BuildContext context) => BudgetDetailScreen(budgetID: budgetID);
    if (!restored) return MaterialPageRoute<Object?>(builder: page);
    return PageRouteBuilder<Object?>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => page(context),
    );
  }

  void _removeRoutesAfterFrame(List<_ManagedRoute> routes) {
    final navigator = _rootNavigator;
    if (navigator == null || routes.isEmpty) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!navigator.mounted) return;
      for (final route in routes) {
        if (route.isActive) navigator.removeRoute(route);
      }
    });
  }

  void _discardOwnedRoutesAfterFrame() {
    final page = _page;
    _page = null;
    page?.removedForPresentation = true;
    final sessions = _allSessions().toList();
    _retireSession();
    _limitOperation = null;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _removeRoutesAfterFrameNow([
        ?page?.route,
        for (final session in sessions) ...session.descendants,
      ]);
    });
  }

  void _removeRoutesAfterFrameNow(List<_ManagedRoute> routes) {
    final navigator = _rootNavigator;
    if (navigator == null || !navigator.mounted) return;
    for (final route in routes) {
      if (route.isActive) navigator.removeRoute(route);
    }
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

  void _adoptDescendant(_BudgetSession session, _ManagedRoute route) {
    if (!session.descendants.add(route)) return;
    unawaited(_watchDescendant(session, route));
  }

  Future<void> _watchDescendant(
    _BudgetSession session,
    _ManagedRoute route,
  ) async {
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
    if (!_destinationActive || session.generation != generation) return;
    if (ref.read(selectedBudgetProvider)?.generation != generation) return;
    final context = navigatorContext;
    if (context == null) return;

    if (step is BudgetLimitEditRequested) {
      final route = MaterialPageRoute<Object?>(
        builder: (_) => BudgetLimitScreen(budgetID: budgetID),
      );
      _rootNavigatorOf(context).push(route);
      _adoptDescendant(session, route);
    }
    _detailViewModel(budgetID).clearStep();
  }

  Future<void> _handleLimitStep(
    int generation,
    String budgetID,
    BudgetsStep? step,
  ) async {
    if (step is! PickLimitRequested) return;
    if (!_destinationActive || _session?.generation != generation) return;
    if (ref.read(selectedBudgetProvider)?.generation != generation) return;
    if (_limitOperation != null) return;
    final context = navigatorContext;
    if (context == null) return;

    final capturedLedger = ref.read(ledgerProvider);
    final operation = Object();
    _limitOperation = operation;
    final session = _session;
    final entered = await showBudgetLimitEditSheet(
      context: context,
      target: step.target,
      onRoute: (route) {
        if (session != null) _adoptDescendant(session, route);
      },
    );
    if (!identical(_limitOperation, operation)) return;
    _limitOperation = null;
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
