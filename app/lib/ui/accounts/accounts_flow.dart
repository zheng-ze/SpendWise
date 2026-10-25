import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/accounts/account_form/account_form.dart';
import 'package:spendwise/ui/accounts/accounts_screen.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/accounts/money_navigation.dart';
import 'package:spendwise/ui/accounts/account_detail_screen.dart';
import 'package:spendwise/ui/accounts/source_edit/source_edit_form.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

// MARK: - AccountsFlow
class AccountsFlow extends FlowBase<AccountsStep> {
  const AccountsFlow({super.key, this.moneyObserver});

  final MoneyNavigatorObserver? moneyObserver;

  @override
  ConsumerState<AccountsFlow> createState() => _AccountsFlowState();
}

// MARK: - AccountsFlowState
class _AccountsFlowState extends FlowBaseState<AccountsStep, AccountsFlow> {
  late final _routeObserver = _AccountsRouteObserver(
    onTopRouteChanged: _scheduleDetailReconciliation,
  );
  late final List<NavigatorObserver> _navigatorObservers = [
    _routeObserver,
    ?widget.moneyObserver,
  ];
  ProviderSubscription<AsyncValue<AccountsViewState>>? _viewStateSubscription;
  ProviderSubscription<ShellLayoutMode>? _modeSubscription;
  Route<void>? _detailRoute;
  bool _presentationOnlyRemoval = false;
  bool _reconciliationScheduled = false;

  @override
  List<NavigatorObserver> get navigatorObservers => _navigatorObservers;

  @override
  void initState() {
    super.initState();
    _viewStateSubscription = ref.listenManual(
      accountsViewModelProvider,
      (previous, next) => _scheduleDetailReconciliation(),
    );
    _modeSubscription = ref.listenManual(
      shellLayoutModeProvider,
      (previous, next) => _scheduleDetailReconciliation(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleDetailReconciliation();
  }

  @override
  void dispose() {
    _viewStateSubscription?.close();
    _modeSubscription?.close();
    super.dispose();
  }

  AccountsViewModel get _screenViewModel =>
      ref.read(accountsViewModelProvider.notifier);

  @override
  void Function() subscribeToStep(void Function(AccountsStep? step) handle) =>
      ref
          .listenManual(
            accountsViewModelProvider,
            (previous, AsyncValue<AccountsViewState> next) =>
                handle(next.value?.step),
          )
          .close;

  @override
  void handleStep(BuildContext context, AccountsStep step) {
    switch (step) {
      case AccountFormRequested():
        showAccountFormSheet(context: context);
      case SourceEditRequested(:final holderId):
        showSourceEditFormSheet(context: context, holderID: holderId);
      case AccountOpened(:final title, :final scopeIDs):
        _pushTransactions(context, title, scopeIDs);
      case AccountAloneOpened(:final title, :final scopeIDs):
        _pushTransactions(context, title, scopeIDs);
      case PocketOpened(:final title, :final scopeIDs):
        _pushTransactions(context, title, scopeIDs);
      case AccountDetailRequested():
        _scheduleDetailReconciliation();
      case PickParentRequested():
        break;
      case AccountFormSaved():
      case SourceEditFormSaved():
        break;
    }
    _screenViewModel.clearStep();
  }

  void _pushTransactions(
    BuildContext context,
    String title,
    Set<String> scopeIDs,
  ) {
    final route = MaterialPageRoute<void>(
      settings: MoneyTransactionsRouteSettings(
        preferredSourceId: scopeIDs.firstOrNull,
      ),
      builder: (_) => TransactionsFlow(
        initialScope: TransactionsScope(title: title, scopeIDs: scopeIDs),
        onEnded: () => Navigator.of(context).pop(),
      ),
    );
    unawaited(
      Navigator.of(context)
          .push(route)
          .whenComplete(_scheduleDetailReconciliation),
    );
  }

  void _scheduleDetailReconciliation() {
    if (_reconciliationScheduled) return;
    _reconciliationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconciliationScheduled = false;
      if (!mounted || !DestinationActivity.of(context)) return;
      _reconcileDetailRoute();
    });
  }

  void _reconcileDetailRoute() {
    final selectedDetail = ref
        .read(accountsViewModelProvider)
        .value
        ?.selectedDetail;
    final mode = ref.read(shellLayoutModeProvider);
    final navigatorContext = this.navigatorContext;
    if (navigatorContext == null) return;

    if (mode == ShellLayoutMode.phone) {
      if (selectedDetail != null && _detailRoute == null) {
        _pushDetailRoute(navigatorContext);
      }
      return;
    }

    if (_detailRoute == null || _routeObserver.topRoute != _detailRoute) {
      return;
    }
    _presentationOnlyRemoval = selectedDetail != null;
    Navigator.of(navigatorContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _presentationOnlyRemoval = false;
    });
  }

  void _pushDetailRoute(BuildContext context) {
    final route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'account-detail'),
      builder: (_) => AccountDetailScreen(
        shouldClearSelectionOnPop: () => !_presentationOnlyRemoval,
      ),
    );
    _detailRoute = route;
    unawaited(
      Navigator.of(context).push(route).whenComplete(() {
        if (identical(_detailRoute, route)) _detailRoute = null;
        _scheduleDetailReconciliation();
      }),
    );
  }

  @override
  Widget buildRoot(BuildContext context) => const AccountsScreen();
}

class _AccountsRouteObserver extends NavigatorObserver {
  _AccountsRouteObserver({required this.onTopRouteChanged});

  final VoidCallback onTopRouteChanged;
  Route<dynamic>? topRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    topRoute = route;
    onTopRouteChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    topRoute = previousRoute;
    onTopRouteChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(topRoute, route)) topRoute = previousRoute;
    onTopRouteChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (identical(topRoute, oldRoute)) topRoute = newRoute;
    onTopRouteChanged();
  }
}
