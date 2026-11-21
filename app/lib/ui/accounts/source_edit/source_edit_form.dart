import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import 'package:spendwise/ui/accounts/account_fields_card.dart';
import 'package:spendwise/ui/accounts/account_form_frame.dart';
import 'package:spendwise/ui/accounts/accounts_steps.dart';
import 'package:spendwise/ui/accounts/source_edit/source_edit_form_view_model.dart';
import 'package:spendwise/ui/common/base/step_listening_state.dart';
import 'package:spendwise/ui/common/sheets/show_form_sheet_then_invalidate.dart';
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
}) {
  return showFormSheetThenInvalidate(
    context: context,
    container: container,
    draftProvider: sourceEditFormViewModelProvider(holderID),
    builder: (_) => SourceEditForm(holderID: holderID),
  );
}

// MARK: - SourceEditForm
class SourceEditForm extends ConsumerStatefulWidget {
  const SourceEditForm({super.key, required this.holderID});

  final String holderID;

  @override
  ConsumerState<SourceEditForm> createState() => _SourceEditFormState();
}

// MARK: - SourceEditFormState
class _SourceEditFormState extends ConsumerState<SourceEditForm>
    with
        StepListeningState<
          SourceEditForm,
          SourceEditFormViewState,
          AccountsStep
        > {
  @override
  ProviderListenable<AsyncValue<SourceEditFormViewState>> get stepProvider =>
      sourceEditFormViewModelProvider(widget.holderID);

  @override
  AccountsStep? stepOf(SourceEditFormViewState viewState) => viewState.step;

  @override
  void clearStep() => _viewModel.clearStep();

  SourceEditFormViewModel get _viewModel =>
      ref.read(sourceEditFormViewModelProvider(widget.holderID).notifier);

  @override
  void handleStep(AccountsStep step) {
    if (step is SourceEditFormSaved && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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
