import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/accounts/account_fields_card.dart';
import 'package:spendwise/ui/accounts/account_form_frame.dart';
import 'package:spendwise/ui/accounts/accounts_steps.dart';
import 'package:spendwise/ui/accounts/source_edit/source_edit_form_view_model.dart';
import 'package:spendwise/ui/shell/shell_sheet_presentation.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/form_sheet_load_states.dart';

// MARK: - Constants

const _loadingTitle = 'Edit Account';
const _loadErrorTitle = "Couldn't load this account";
const _accountTitle = 'Edit Account';
const _subpocketTitle = 'Edit Subpocket';
const _balanceHint = 'Balance';

// MARK: - Visual Constants

const _fieldContentPadding = EdgeInsets.zero;

// MARK: - Helpers
Future<void> showSourceEditFormSheet({
  required BuildContext context,
  required String holderID,
  required ProviderContainer container,
}) async {
  AppSheetRoute<void>? route;
  await showAppSheet<void>(
    context,
    presentation: shellSheetPresentation(context),
    presentationResolver: shellSheetPresentation,
    onRouteCreated: (createdRoute) => route = createdRoute,
    builder: (_) => SourceEditForm(holderID: holderID),
  );
  final completedRoute = route;
  if (completedRoute == null) return;
  await completedRoute.completed;
  container.invalidate(sourceEditFormViewModelProvider(holderID));
}

// MARK: - SourceEditForm
class SourceEditForm extends ConsumerStatefulWidget {
  const SourceEditForm({super.key, required this.holderID});

  final String holderID;

  @override
  ConsumerState<SourceEditForm> createState() => _SourceEditFormState();
}

// MARK: - SourceEditFormState
class _SourceEditFormState extends ConsumerState<SourceEditForm> {
  ProviderSubscription<AsyncValue<SourceEditFormViewState>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(
      sourceEditFormViewModelProvider(widget.holderID),
      (previous, next) => _handleStep(next.value?.step),
    );
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  SourceEditFormViewModel get _viewModel =>
      ref.read(sourceEditFormViewModelProvider(widget.holderID).notifier);

  void _handleStep(AccountsStep? step) {
    if (step == null) return;
    switch (step) {
      case SourceEditFormSaved():
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      case AccountFormRequested():
      case SourceEditRequested():
      case AccountOpened():
      case AccountAloneOpened():
      case PocketOpened():
      case PickParentRequested():
      case AccountFormSaved():
        break;
    }
    _viewModel.clearStep();
  }

  @override
  Widget build(BuildContext context) {
    final provider = sourceEditFormViewModelProvider(widget.holderID);

    return FormSheetAsyncHost(
      state: ref.watch(provider),
      title: _loadingTitle,
      loadErrorMessage: _loadErrorTitle,
      onRetry: () => ref.invalidate(provider),
      builder: (formState) =>
          _SourceEditFormBody(formState: formState, viewModel: _viewModel),
    );
  }
}

// MARK: - SourceEditFormBody
class _SourceEditFormBody extends StatelessWidget {
  const _SourceEditFormBody({required this.formState, required this.viewModel});

  final SourceEditFormViewState formState;
  final SourceEditFormViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final title = formState.isAccount ? _accountTitle : _subpocketTitle;
    final transferSwitch = SwitchListTile(
      contentPadding: _fieldContentPadding,
      title: const Text('Transfers in count as expenses'),
      subtitle: const Text(
        'When on, money transferred into this holder is treated as '
        'spending in analysis.',
      ),
      value: formState.incomingTransfersAsExpenses,
      onChanged: viewModel.setIncomingTransfersAsExpenses,
    );
    final netWorthSwitch = SwitchListTile(
      contentPadding: _fieldContentPadding,
      title: const Text('Include in net worth'),
      value: formState.includeInNetWorth,
      onChanged: viewModel.setIncludeInNetWorth,
    );
    final fieldRows = AccountFieldsCard(
      fields: formState,
      actions: viewModel,
      balanceHint: _balanceHint,
      showsTypeFields: formState.isAccount,
      extras: [
        if (formState.showsTransferToggle) ...[
          const SizedBox(height: accountFieldGap),
          transferSwitch,
        ],
        if (formState.isAccount) netWorthSwitch,
      ],
    );

    return AccountFormFrame(
      title: title,
      error: formState.error,
      onSave: formState.canSave ? viewModel.save : null,
      children: [fieldRows],
    );
  }
}
