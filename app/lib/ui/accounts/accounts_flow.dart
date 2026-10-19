import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/accounts/account_form/account_form.dart';
import 'package:spendwise/ui/accounts/accounts_screen.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/accounts/money_navigation.dart';
import 'package:spendwise/ui/accounts/source_edit/source_edit_form.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

// MARK: - AccountsFlow
class AccountsFlow extends FlowBase<AccountsStep> {
  const AccountsFlow({super.key, this.moneyObserver, this.rootObserver});

  final MoneyNavigatorObserver? moneyObserver;
  final NavigatorObserver? rootObserver;

  @override
  ConsumerState<AccountsFlow> createState() => _AccountsFlowState();
}

// MARK: - AccountsFlowState
class _AccountsFlowState extends FlowBaseState<AccountsStep, AccountsFlow> {
  late final List<NavigatorObserver> _navigatorObservers = [
    ?widget.moneyObserver,
    ?widget.rootObserver,
  ];
  bool _active = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = DestinationActivity.of(context);
    final activated = active && !_active;
    _active = active;
    if (activated) WidgetsBinding.instance.addPostFrameCallback(_pickUpStep);
  }

  void _pickUpStep(Duration _) {
    if (!mounted) return;
    final context = navigatorContext;
    final step = ref.read(accountsViewModelProvider).value?.step;
    if (context != null && step != null) handleStep(context, step);
  }

  @override
  List<NavigatorObserver> get navigatorObservers => _navigatorObservers;
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
    if (!DestinationActivity.of(context)) return;
    if (!identical(ref.read(accountsViewModelProvider).value?.step, step)) {
      return;
    }
    _screenViewModel.clearStep();
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
      case PickParentRequested():
        break;
      case AccountFormSaved():
      case SourceEditFormSaved():
        break;
    }
  }

  void _pushTransactions(
    BuildContext context,
    String title,
    Set<String> scopeIDs,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: MoneyTransactionsRouteSettings(
          preferredSourceId: scopeIDs.firstOrNull,
        ),
        builder: (_) => TransactionsFlow(
          initialScope: TransactionsScope(title: title, scopeIDs: scopeIDs),
          onEnded: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget buildRoot(BuildContext context) => const AccountsScreen();
}
