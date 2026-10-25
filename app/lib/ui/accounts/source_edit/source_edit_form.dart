import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/accounts/accounts_steps.dart';
import 'package:spendwise/ui/accounts/source_edit/source_edit_form_view_model.dart';
import 'package:spendwise/ui/accounts/account_sheet_presentation.dart';
import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/pickers/account_type_picker.dart';
import 'package:spendwise/ui/common/inputs/amount_field.dart';
import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/common/inputs/statement_day_picker.dart';

// MARK: - Visual Constants

const _fieldContentPadding = EdgeInsets.zero;

// MARK: - Helpers
Future<void> showSourceEditFormSheet({
  required BuildContext context,
  required String holderID,
  required ProviderContainer container,
}) async {
  AppSheetRoute<void>? route;
  container.read(accountSheetPresentedProvider.notifier).state = true;
  try {
    await showAppSheet<void>(
      context,
      presentation: accountSheetPresentation(context),
      presentationResolver: accountSheetPresentation,
      onRouteCreated: (createdRoute) => route = createdRoute,
      builder: (_) => SourceEditForm(holderID: holderID),
    );
    final completedRoute = route;
    if (completedRoute == null) return;
    await completedRoute.completed;
    container.invalidate(sourceEditFormViewModelProvider(holderID));
  } finally {
    container.read(accountSheetPresentedProvider.notifier).state = false;
  }
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

// MARK: - SourceEditFormBody
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

  static const _fieldGap = 16.0;

  @override
  Widget build(BuildContext context) {
    if (nameController.text != formState.name) {
      nameController.text = formState.name;
    }
    if (balanceController.text != formState.balanceText) {
      balanceController.text = formState.balanceText;
    }

    final title = formState.isAccount ? 'Edit Account' : 'Edit Subpocket';
    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Name'),
          onChanged: viewModel.setName,
        ),
        if (formState.isAccount) ...[
          const SizedBox(height: _fieldGap),
          AccountTypePicker(
            selected: formState.type,
            onSelected: viewModel.setType,
            sheetPresentation: accountSheetPresentation,
          ),
          if (formState.type == AccountType.card) ...[
            const SizedBox(height: _fieldGap),
            StatementDayPicker(
              selected: formState.statementDay,
              onSelected: viewModel.setStatementDay,
              sheetPresentation: accountSheetPresentation,
            ),
          ],
        ],
        const SizedBox(height: _fieldGap),
        AmountField(
          controller: balanceController,
          allowsNegative: true,
          hintText: 'Balance',
          onChanged: viewModel.setBalance,
        ),
        if (formState.showsTransferToggle) ...[
          const SizedBox(height: _fieldGap),
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: _fieldContentPadding,
              title: const Text('Transfers in count as expenses'),
              subtitle: const Text(
                'When on, money transferred into this holder is treated as '
                'spending in analysis.',
              ),
              value: formState.incomingTransfersAsExpenses,
              onChanged: viewModel.setIncomingTransfersAsExpenses,
            ),
          ),
        ],
        if (formState.isAccount)
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: _fieldContentPadding,
              title: const Text('Include in net worth'),
              value: formState.includeInNetWorth,
              onChanged: viewModel.setIncludeInNetWorth,
            ),
          ),
        ErrorSection(subject: 'account', error: formState.error),
      ],
    );
    final saveButton = SizedBox(
      width: double.infinity,
      child: PrimaryButton(
        label: 'Save',
        onPressed: formState.canSave ? viewModel.save : null,
      ),
    );

    return AppSheet(
      header: AppPickerHeader(title: title),
      body: fields,
      footer: saveButton,
      dragToDismiss: true,
      variant: AppSheetVariant.form,
    );
  }
}
