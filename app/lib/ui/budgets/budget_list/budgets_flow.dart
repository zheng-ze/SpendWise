import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:spendwise/ui/shell/selected_detail_controller.dart';

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
  late final SelectedDetailController _detail = SelectedDetailController(
    ref: ref,
    selection: selectedBudgetProvider,
    clearSelection: () => ref.read(selectedBudgetProvider.notifier).clear(),
    buildPage: _buildDetailPage,
    navigatorContext: () => navigatorContext,
    mounted: () => mounted,
    openOwners: _openOwners,
    onShownChanged: (_) => _editSession?.sheet.retire(),
  );

  _FormSession? _formSession;
  _EditSession? _editSession;

  // MARK: - Lifecycle

  @override
  void initState() {
    super.initState();
    _detail.start();
  }

  @override
  void dispose() {
    _detail.dispose();
    _editSession?.sheet.retire();
    _formSession?.sheet.end();
    _formSession = null;
    super.dispose();
  }

  ModalRoute<Object?> _buildDetailPage(String budgetID) =>
      MaterialPageRoute<Object?>(
        builder: (_) => BudgetDetailScreen(budgetID: budgetID),
      );

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

  // MARK: - Budget Subscriptions

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
    if (_detail.shownID != budgetID) return;
    ref.read(selectedBudgetProvider.notifier).clear();
  }

  Future<void> _handleDetailStep(String budgetID, BudgetsStep? step) async {
    if (step is! BudgetEditRequested) return;
    if (_detail.shownID != budgetID) return;
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
    if (_detail.shownID != session.budgetID) return false;
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
    _detail.reconcileNow();
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
