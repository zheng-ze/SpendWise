import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/accounts/account_form.dart';
import 'package:spendwise/ui/accounts/accounts_screen.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/accounts/source_edit_form.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

/// Owns the Accounts feature's own nested Navigator, so a picker sheet or
/// a scoped transactions push never reaches for the app's root Navigator.
class AccountsFlow extends ConsumerStatefulWidget {
  const AccountsFlow({super.key});

  @override
  ConsumerState<AccountsFlow> createState() => _AccountsFlowState();
}

class _AccountsFlowState extends ConsumerState<AccountsFlow> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  ProviderSubscription<AsyncValue<AccountsViewState>>? _screenSubscription;

  @override
  void initState() {
    super.initState();
    _screenSubscription = ref.listenManual(
      accountsViewModelProvider,
      (previous, next) => _handleStep(next.value?.step),
    );
  }

  @override
  void dispose() {
    _screenSubscription?.close();
    super.dispose();
  }

  AccountsViewModel get _screenViewModel =>
      ref.read(accountsViewModelProvider.notifier);

  void _handleStep(AccountsStep? step) {
    if (step == null) return;
    final context = _navigatorKey.currentContext;
    if (context == null) return;

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
        // The account form sheet's own subscription handles this instead.
        break;
      case AccountFormSaved():
      case SourceEditFormSaved():
        // Each form sheet's own subscription handles closing itself.
        break;
    }
    _screenViewModel.clearStep();
  }

  void _pushTransactions(
    BuildContext context,
    String title,
    Set<String> scopeIDs,
  ) {
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionsFlow(
          initialScope: TransactionsScope(title: title, scopeIDs: scopeIDs),
          onEditSource: (context, holderId) =>
              _screenViewModel.requestSourceEdit(holderId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _navigatorKey.currentState?.maybePop();
      },
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => const AccountsScreen(),
        ),
      ),
    );
  }
}
