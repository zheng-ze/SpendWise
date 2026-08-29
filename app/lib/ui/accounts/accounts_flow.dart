import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/accounts/account_form.dart';
import 'package:spendwise/ui/accounts/accounts_screen.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/accounts/source_edit_form.dart';
import 'package:spendwise/ui/common/flow_base.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

/// Owns the Accounts feature's own nested Navigator, so a picker sheet or
/// a scoped transactions push never reaches for the app's root Navigator.
class AccountsFlow extends FlowBase<AccountsStep> {
  const AccountsFlow({super.key});

  @override
  ConsumerState<AccountsFlow> createState() => _AccountsFlowState();
}

class _AccountsFlowState
    extends FlowBaseState<AccountsStep, AccountsFlow> {
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
    Navigator.of(context).push(
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
  Widget buildRoot(BuildContext context) => const AccountsScreen();
}
