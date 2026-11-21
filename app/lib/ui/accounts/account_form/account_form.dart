import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import 'package:spendwise/ui/accounts/account_fields_card.dart';
import 'package:spendwise/ui/accounts/account_form/account_form_logic.dart';
import 'package:spendwise/ui/accounts/account_form_frame.dart';
import 'package:spendwise/ui/accounts/account_form/account_form_view_model.dart';
import 'package:spendwise/ui/common/inputs/form_sheet_row.dart';
import 'package:spendwise/ui/shell/shell_sheet_presentation.dart';
import 'package:spendwise/ui/accounts/accounts_steps.dart';
import 'package:spendwise/ui/common/base/step_listening_state.dart';
import 'package:spendwise/ui/common/sheets/show_form_sheet_then_invalidate.dart';
import 'package:spendwise/ui/common/sheets/form_sheet_load_states.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';

// MARK: - Constants

const _loadingTitle = 'New Account';
const _loadErrorTitle = "Couldn't load the account form";
const _accountTitle = 'New Account';
const _subpocketTitle = 'New Subpocket';
const _balanceHint = 'Opening balance';

// MARK: - Visual Constants

// MARK: - Helpers
Future<void> showAccountFormSheet({
  required BuildContext context,
  required ProviderContainer container,
}) {
  return showFormSheetThenInvalidate(
    context: context,
    container: container,
    draftProvider: accountFormViewModelProvider,
    builder: (_) => const AccountForm(),
  );
}

// MARK: - AccountForm
class AccountForm extends ConsumerStatefulWidget {
  const AccountForm({super.key});

  @override
  ConsumerState<AccountForm> createState() => _AccountFormState();
}

// MARK: - AccountFormState
class _AccountFormState extends ConsumerState<AccountForm>
    with StepListeningState<AccountForm, AccountFormViewState, AccountsStep> {
  @override
  ProviderListenable<AsyncValue<AccountFormViewState>> get stepProvider =>
      accountFormViewModelProvider;

  @override
  AccountsStep? stepOf(AccountFormViewState viewState) => viewState.step;

  @override
  void clearStep() => _viewModel.clearStep();

  AccountFormViewModel get _viewModel =>
      ref.read(accountFormViewModelProvider.notifier);

  @override
  void handleStep(AccountsStep step) {
    if (step is PickParentRequested) _pickParent();
    if (step is AccountFormSaved && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickParent() async {
    final formState = ref.read(accountFormViewModelProvider).value;
    final formRoute = ModalRoute.of(context);
    if (formState == null || formRoute == null) return;
    final outcome = await showTwoColumnPickerSheet(
      context: context,
      title: 'Select Account',
      groups: [
        for (final account in formState.pocketableParents)
          PickerOption(id: account.id, label: account.name),
      ],
      selectedId: formState.parentId,
      sheetPresentation: shellSheetPresentation,
    );
    if (!context.mounted ||
        !formRoute.isActive ||
        formRoute.animation?.status != AnimationStatus.completed) {
      return;
    }
    if (outcome == null) return;
    final id = switch (outcome) {
      PickerChose(:final id) => id,
    };
    _viewModel.applyPickedParent(id);
  }

  @override
  Widget build(BuildContext context) {
    return FormSheetAsyncHost(
      state: ref.watch(accountFormViewModelProvider),
      title: _loadingTitle,
      loadErrorMessage: _loadErrorTitle,
      onRetry: () => ref.invalidate(accountFormViewModelProvider),
      builder: (formState) =>
          _AccountFormBody(formState: formState, viewModel: _viewModel),
    );
  }
}

// MARK: - AccountFormBody
class _AccountFormBody extends StatelessWidget {
  const _AccountFormBody({required this.formState, required this.viewModel});

  final AccountFormViewState formState;
  final AccountFormViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isAccountKind = formState.effectiveKind == AccountFormKind.account;
    final title = isAccountKind ? _accountTitle : _subpocketTitle;
    final kindSelector = IgnorePointer(
      ignoring: formState.isLockedToAccount,
      child: SegmentedButton<AccountFormKind>(
        segments: const [
          ButtonSegment(value: AccountFormKind.account, label: Text('Account')),
          ButtonSegment(
            value: AccountFormKind.subpocket,
            label: Text('Subpocket'),
          ),
        ],
        selected: {formState.effectiveKind},
        onSelectionChanged: formState.isLockedToAccount
            ? null
            : (selection) => viewModel.setKind(selection.first),
      ),
    );
    final parentRow = FormSheetRow(
      label: 'Account',
      trailing: Text(_parentLabel() ?? 'Select'),
      onTap: viewModel.requestPickParent,
    );
    final fieldRows = AccountFieldsCard(
      fields: formState,
      actions: viewModel,
      balanceHint: _balanceHint,
      showsTypeFields: isAccountKind,
      showsBalance: isAccountKind,
      extras: [
        if (!isAccountKind) ...[
          const SizedBox(height: accountFieldGap),
          parentRow,
        ],
      ],
    );

    return AccountFormFrame(
      title: title,
      error: formState.error,
      onSave: formState.canSave ? viewModel.save : null,
      children: [
        kindSelector,
        const SizedBox(height: accountFieldGap),
        fieldRows,
      ],
    );
  }

  String? _parentLabel() {
    final id = formState.parentId;
    if (id == null) return null;
    for (final account in formState.pocketableParents) {
      if (account.id == id) return account.name;
    }
    return null;
  }
}
