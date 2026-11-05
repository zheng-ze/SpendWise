import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_screen.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_edit_actions_sheet.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_edit_sheet.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_editor_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_category_picker.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_form.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_form_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_scope_options.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_selection.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/common/feedback/destructive_confirmation.dart';
import 'package:spendwise/ui/common/layout/headered_page.dart';
import 'package:spendwise/ui/common/sheets/sheet_session.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/shell_sheet_occupancy.dart';

// MARK: - Constants

const _deleteBodyText =
    'Your entries stay as they are. Only the limit is removed.';

// MARK: - BudgetsFlow
class BudgetsFlow extends FlowBase<BudgetsStep> {
  const BudgetsFlow({super.key, required this.header});

  final Widget header;

  @override
  ConsumerState<BudgetsFlow> createState() => _BudgetsFlowState();
}

// MARK: - BudgetsFlowState
class _BudgetsFlowState extends FlowBaseState<BudgetsStep, BudgetsFlow> {
  bool _reconcileScheduled = false;
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
  _EditSession? _editSession;

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
      _editSession?.sheet.retire();
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
    _editSession?.sheet.retire();
    _removePageAfterFrame();
    _formSession?.sheet.end();
    _formSession = null;
    super.dispose();
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
    switch (step) {
      case BudgetFormRequested():
        _openBudgetForm(context);
      case BudgetEditRequested():
      case PickCategoryRequested():
      case BudgetFormSaved():
      case BudgetLimitSaved():
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

  void _reconcilePage() {
    final selected = ref.read(selectedBudgetProvider);
    final phone = ref.read(shellLayoutModeProvider) == ShellLayoutMode.phone;
    final wanted = phone ? selected : null;
    if (_pageBudgetID == wanted) return;
    _removePage();
    final context = navigatorContext;
    if (wanted == null || context == null) return;
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
    _editSession?.sheet.retire();
    _shownBudgetID = budgetID;
    _shownSubscriptions = budgetID == null ? const [] : _openOwners(budgetID);
  }

  List<ProviderSubscription<Object?>> _openOwners(String budgetID) {
    final context = ref.listenManual(
      budgetDetailContextProvider(budgetID),
      (_, _) {},
    );
    final detail = ref.listenManual(budgetDetailViewModelProvider(budgetID), (
      _,
      next,
    ) {
      _clearSelectionWhenMissing(budgetID, next.value?.phase);
      unawaited(_handleDetailStep(budgetID, next.value?.step));
    });
    return [context, detail];
  }

  void _clearSelectionWhenMissing(String budgetID, BudgetDetailPhase? phase) {
    if (phase != BudgetDetailPhase.deleted) return;
    if (_shownBudgetID != budgetID) return;
    ref.read(selectedBudgetProvider.notifier).clear();
  }

  Future<void> _handleDetailStep(String budgetID, BudgetsStep? step) async {
    if (step is! BudgetEditRequested) return;
    if (_shownBudgetID != budgetID) return;
    final context = navigatorContext;
    if (context == null) return;

    final detail = _detailViewModel(budgetID);
    detail.clearStep();
    if (_editSession != null) return;
    final ledger = ref.read(ledgerProvider);
    if (ledger == null || detail.liveLimit == null) return;

    final session = _EditSession(budgetID, ledger);
    _editSession = session;
    try {
      final action = await showBudgetEditActionsSheet(
        context: context,
        onRouteCreated: (route) => session.sheet.route = route,
      );
      if (action == null || !_editStillValid(session)) return;
      switch (action) {
        case BudgetEditAction.changeLimit:
          await _openLimitEditor(session);
        case BudgetEditAction.delete:
          await _confirmDelete(session);
      }
    } finally {
      _endEditSession(session);
    }
  }

  // Retiring removes only the session's sheet route. An open delete confirmation is a plain modal route
  // the Flow does not track, so it stays up and its Delete fails this gate without writing. Nothing can
  // replace the ledger or change the shown budget while it blocks the screen, because sync runs only on
  // explicit calls; revisit this if sync becomes constant live updates.
  bool _editStillValid(_EditSession session) {
    if (!mounted || session.sheet.retired) return false;
    if (_shownBudgetID != session.budgetID) return false;
    if (!identical(ref.read(ledgerProvider), session.ledger)) return false;
    return _detailViewModel(session.budgetID).liveLimit != null;
  }

  Future<void> _confirmDelete(_EditSession session) async {
    final context = navigatorContext;
    final title = ref
        .read(budgetDetailViewModelProvider(session.budgetID))
        .value
        ?.title;
    if (context == null || title == null) return;

    final confirmed = await showDestructiveConfirmation(
      context,
      title: 'Delete the $title budget?',
      body: _deleteBodyText,
    );
    if (!confirmed || !_editStillValid(session)) return;
    _detailViewModel(session.budgetID).deleteBudget();
    ref.read(selectedBudgetProvider.notifier).clear();
    _reconcilePage();
  }

  Future<void> _openLimitEditor(_EditSession session) async {
    final context = navigatorContext;
    final current = _detailViewModel(session.budgetID).liveLimit;
    if (context == null || current == null) return;

    final draftKey = BudgetLimitDraftKey(
      budgetID: session.budgetID,
      initialLimit: current,
    );
    final provider = budgetLimitEditorViewModelProvider(draftKey);
    final subscription = ref.listenManual(provider, (_, next) {
      if (session.sheet.retired) return;
      if (next.value?.step is! BudgetLimitSaved) return;
      session.sheet.dismiss();
      ref.read(provider.notifier).clearStep();
    });
    session.sheet.subscription = subscription;
    await showBudgetLimitEditSheet(
      context: context,
      draftKey: draftKey,
      onRouteCreated: (route) {
        session.sheet.route = route;
        unawaited(
          session.sheet.endWhenCompleted(route, () => _endEditSession(session)),
        );
      },
    );
  }

  void _endEditSession(_EditSession session) {
    session.sheet.end();
    if (identical(_editSession, session)) _editSession = null;
  }

  // MARK: - Form Navigation

  void _endFormSession(_FormSession session) {
    session.sheet.end();
    if (identical(_formSession, session)) _formSession = null;
  }

  void _openBudgetForm(BuildContext context) {
    if (_formSession != null) return;
    final draftKey = BudgetDraftKey();
    final session = _FormSession(draftKey);
    _formSession = session;
    final subscription = ref.listenManual(
      budgetFormViewModelProvider(draftKey),
      (previous, next) => unawaited(_handleFormStep(session, next.value?.step)),
    );
    session.sheet.subscription = subscription;
    unawaited(
      showBudgetFormSheet(
        context: context,
        draftKey: draftKey,
        onRouteCreated: (route) {
          session.sheet.route = route;
          unawaited(
            session.sheet.endWhenCompleted(
              route,
              () => _endFormSession(session),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleFormStep(_FormSession session, BudgetsStep? step) async {
    if (step == null) return;
    switch (step) {
      case PickCategoryRequested():
        await _pickScope(session);
      case BudgetFormSaved():
        session.sheet.dismiss();
        _formViewModel(session.draftKey).clearStep();
      case BudgetFormRequested():
      case BudgetEditRequested():
      case BudgetLimitSaved():
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
    final formRoute = session.sheet.route;
    if (chosen == null || !mounted || !identical(_formSession, session)) return;
    if (formRoute == null || !formRoute.isActive) return;
    _formViewModel(session.draftKey).applyPickedScope(chosen);
  }

  @override
  Widget buildRoot(BuildContext context) =>
      HeaderedPage(header: widget.header, body: const BudgetsRoot());
}

// MARK: - FormSession
class _FormSession {
  _FormSession(this.draftKey);

  final BudgetDraftKey draftKey;
  final sheet = SheetSession();
}

// MARK: - EditSession
class _EditSession {
  _EditSession(this.budgetID, this.ledger);

  final String budgetID;
  final Ledger ledger;
  final sheet = SheetSession();
}
