import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/accounts/account_form_logic.dart';
import 'package:spendwise/ui/accounts/account_form_view_model.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/common/account_type_picker.dart';
import 'package:spendwise/ui/common/amount_field.dart';
import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/form_scaffold.dart';
import 'package:spendwise/ui/common/statement_day_picker.dart';
import 'package:spendwise/ui/common/two_column_picker_sheet.dart';

/// Opens the account/subpocket creation sheet. Creation-only.
Future<void> showAccountFormSheet({required BuildContext context}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const AccountForm(),
  );
}

class AccountForm extends ConsumerStatefulWidget {
  const AccountForm({super.key});

  @override
  ConsumerState<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<AccountForm> {
  late final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _balanceController = TextEditingController();

  ProviderSubscription<AsyncValue<AccountFormViewState>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(
      accountFormViewModelProvider,
      (previous, next) => _handleStep(next.value?.step),
    );
  }

  @override
  void dispose() {
    _subscription?.close();
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  AccountFormViewModel get _viewModel =>
      ref.read(accountFormViewModelProvider.notifier);

  void _handleStep(AccountsStep? step) {
    if (step == null) return;
    switch (step) {
      case PickParentRequested():
        _pickParent();
      case AccountFormSaved():
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      case AccountFormRequested():
      case SourceEditRequested():
      case AccountOpened():
      case AccountAloneOpened():
      case PocketOpened():
      case SourceEditFormSaved():
        // Only AccountsViewModel or SourceEditFormViewModel emit these;
        // unreachable here.
        break;
    }
    _viewModel.clearStep();
  }

  Future<void> _pickParent() async {
    final formState = ref.read(accountFormViewModelProvider).value;
    if (formState == null) return;
    final outcome = await showTwoColumnPickerSheet(
      context: context,
      title: 'Select Account',
      groups: [
        for (final account in formState.pocketableParents)
          PickerOption(id: account.id, label: account.name),
      ],
      selectedId: formState.parentId,
    );
    if (!context.mounted) return;
    if (outcome == null) return;
    final id = switch (outcome) {
      PickerChose(:final id) => id,
      PickerCleared() => null,
    };
    _viewModel.applyPickedParent(id);
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(accountFormViewModelProvider);

    return asyncState.when(
      data: (formState) => _AccountFormBody(
        formState: formState,
        viewModel: _viewModel,
        nameController: _nameController,
        balanceController: _balanceController,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
    );
  }
}

class _AccountFormBody extends StatelessWidget {
  const _AccountFormBody({
    required this.formState,
    required this.viewModel,
    required this.nameController,
    required this.balanceController,
  });

  final AccountFormViewState formState;
  final AccountFormViewModel viewModel;
  final TextEditingController nameController;
  final TextEditingController balanceController;

  @override
  Widget build(BuildContext context) {
    // Pulled from the ViewModel each build rather than bound both ways,
    // since the ViewModel is the single source of truth for form text.
    if (nameController.text != formState.name) {
      nameController.text = formState.name;
    }
    if (balanceController.text != formState.balanceText) {
      balanceController.text = formState.balanceText;
    }

    return FormScaffold(
      title: formState.effectiveKind == AccountFormKind.subpocket
          ? 'New Subpocket'
          : 'New Account',
      canSave: formState.canSave,
      onSave: viewModel.save,
      error: ErrorSection(subject: 'account', error: formState.error),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IgnorePointer(
            ignoring: formState.isLockedToAccount,
            child: SegmentedButton<AccountFormKind>(
              segments: const [
                ButtonSegment(
                  value: AccountFormKind.account,
                  label: Text('Account'),
                ),
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
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Name'),
            onChanged: viewModel.setName,
          ),
          const SizedBox(height: 16),
          if (formState.effectiveKind == AccountFormKind.account) ...[
            AccountTypePicker(
              selected: formState.type,
              onSelected: viewModel.setType,
            ),
            if (formState.type == AccountType.card) ...[
              const SizedBox(height: 16),
              StatementDayPicker(
                selected: formState.statementDay,
                onSelected: viewModel.setStatementDay,
              ),
            ],
            const SizedBox(height: 16),
            AmountField(
              controller: balanceController,
              allowsNegative: true,
              hintText: 'Opening balance',
              onChanged: viewModel.setBalance,
            ),
          ] else
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Account'),
              trailing: Text(_parentLabel() ?? 'Select'),
              onTap: viewModel.requestPickParent,
            ),
        ],
      ),
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
