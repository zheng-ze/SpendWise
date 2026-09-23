import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/accounts/source_edit/source_edit_form_view_model.dart';
import 'package:spendwise/ui/common/pickers/account_type_picker.dart';
import 'package:spendwise/ui/common/amount_field.dart';
import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/form_scaffold.dart';
import 'package:spendwise/ui/common/statement_day_picker.dart';

Future<void> showSourceEditFormSheet({
  required BuildContext context,
  required String holderID,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => SourceEditForm(holderID: holderID),
  );
}

class SourceEditForm extends ConsumerStatefulWidget {
  const SourceEditForm({super.key, required this.holderID});

  final String holderID;

  @override
  ConsumerState<SourceEditForm> createState() => _SourceEditFormState();
}

class _SourceEditFormState extends ConsumerState<SourceEditForm> {
  late final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _balanceController = TextEditingController();

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
    _nameController.dispose();
    _balanceController.dispose();
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
    final asyncState = ref.watch(
      sourceEditFormViewModelProvider(widget.holderID),
    );

    return asyncState.when(
      data: (formState) => _SourceEditFormBody(
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

class _SourceEditFormBody extends StatelessWidget {
  const _SourceEditFormBody({
    required this.formState,
    required this.viewModel,
    required this.nameController,
    required this.balanceController,
  });

  final SourceEditFormViewState formState;
  final SourceEditFormViewModel viewModel;
  final TextEditingController nameController;
  final TextEditingController balanceController;

  @override
  Widget build(BuildContext context) {
    if (nameController.text != formState.name) {
      nameController.text = formState.name;
    }
    if (balanceController.text != formState.balanceText) {
      balanceController.text = formState.balanceText;
    }

    return FormScaffold(
      title: formState.isAccount ? 'Edit Account' : 'Edit Subpocket',
      canSave: formState.canSave,
      onSave: viewModel.save,
      error: ErrorSection(subject: 'account', error: formState.error),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Name'),
            onChanged: viewModel.setName,
          ),
          if (formState.isAccount) ...[
            const SizedBox(height: 16),
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
          ],
          const SizedBox(height: 16),
          AmountField(
            controller: balanceController,
            allowsNegative: true,
            hintText: 'Balance',
            onChanged: viewModel.setBalance,
          ),
          if (formState.showsTransferToggle) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Transfers in count as expenses'),
              subtitle: const Text(
                'When on, money transferred into this holder is treated as '
                'spending in analysis.',
              ),
              value: formState.incomingTransfersAsExpenses,
              onChanged: viewModel.setIncomingTransfersAsExpenses,
            ),
          ],
          if (formState.isAccount)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include in net worth'),
              value: formState.includeInNetWorth,
              onChanged: viewModel.setIncludeInNetWorth,
            ),
        ],
      ),
    );
  }
}
