import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/accounts/account_form/account_form_logic.dart';
import 'package:spendwise/ui/accounts/account_form/account_form_view_model.dart';
import 'package:spendwise/ui/accounts/account_sheet_presentation.dart';
import 'package:spendwise/ui/accounts/accounts_steps.dart';
import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/inputs/amount_field.dart';
import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/pickers/account_type_picker.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/inputs/statement_day_picker.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Visual Constants

const _fieldContentPadding = EdgeInsets.zero;

// MARK: - Helpers
Future<void> showAccountFormSheet({
  required BuildContext context,
  required ProviderContainer container,
}) async {
  AppSheetRoute<void>? route;
  await showAppSheet<void>(
    context,
    presentation: accountSheetPresentation(context),
    presentationResolver: accountSheetPresentation,
    onRouteCreated: (createdRoute) => route = createdRoute,
    builder: (_) => const AccountForm(),
  );
  final completedRoute = route;
  if (completedRoute == null) return;
  await completedRoute.completed;
  container.invalidate(accountFormViewModelProvider);
}

// MARK: - AccountForm
class AccountForm extends ConsumerStatefulWidget {
  const AccountForm({super.key});

  @override
  ConsumerState<AccountForm> createState() => _AccountFormState();
}

// MARK: - AccountFormState
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
        break;
    }
    _viewModel.clearStep();
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
      sheetPresentation: accountSheetPresentation,
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

// MARK: - AccountFormBody
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

  static const _fieldGap = 16.0;

  @override
  Widget build(BuildContext context) {
    if (nameController.text != formState.name) {
      nameController.text = formState.name;
    }
    if (balanceController.text != formState.balanceText) {
      balanceController.text = formState.balanceText;
    }

    final title = formState.effectiveKind == AccountFormKind.subpocket
        ? 'New Subpocket'
        : 'New Account';
    final fields = Column(
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
        const SizedBox(height: _fieldGap),
        TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Name'),
          onChanged: viewModel.setName,
        ),
        const SizedBox(height: _fieldGap),
        if (formState.effectiveKind == AccountFormKind.account) ...[
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
          const SizedBox(height: _fieldGap),
          AmountField(
            controller: balanceController,
            allowsNegative: true,
            hintText: 'Opening balance',
            onChanged: viewModel.setBalance,
          ),
        ] else
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              contentPadding: _fieldContentPadding,
              title: const Text('Account'),
              trailing: Text(_parentLabel() ?? 'Select'),
              onTap: viewModel.requestPickParent,
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
      surfaceColor: context.colors.raised,
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
