import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/budgets/budget_amount_input.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_form_view_model.dart';
import 'package:spendwise/ui/budgets/budget_sheet_presentation.dart';
import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';

// MARK: - Constants
const _sheetTitle = 'Add budget';
const _categoryLabel = 'Category';
const _saveLabel = 'Save budget';
const _retryLabel = 'Try again';
const _loadingLabel = 'Loading';
const _loadErrorTitle = "Couldn't load the budget form";
const _saveErrorTitle = 'Could not save budget';

const _fieldContentPadding = EdgeInsets.zero;
const _fieldGap = 16.0;
const _loadingGap = 12.0;
const _loadingPadding = EdgeInsets.symmetric(vertical: 32);
const _footerWidth = double.infinity;

// MARK: - Sheet Presenter
Future<void> showBudgetFormSheet({
  required BuildContext context,
  required BudgetDraftKey draftKey,
  required void Function(AppSheetRoute<void>) onRouteCreated,
}) {
  return showAppSheet<void>(
    context,
    presentation: budgetSheetPresentation(context),
    presentationResolver: budgetSheetPresentation,
    onRouteCreated: onRouteCreated,
    builder: (_) => BudgetForm(draftKey: draftKey),
  );
}

// MARK: - BudgetForm
class BudgetForm extends ConsumerStatefulWidget {
  const BudgetForm({super.key, required this.draftKey});

  final BudgetDraftKey draftKey;

  @override
  ConsumerState<BudgetForm> createState() => _BudgetFormState();
}

// MARK: - BudgetFormState
class _BudgetFormState extends ConsumerState<BudgetForm> {
  late final TextEditingController _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = budgetFormViewModelProvider(widget.draftKey);
    final viewModel = ref.read(provider.notifier);
    final asyncState = ref.watch(provider);
    final formState = asyncState.value;

    if (formState != null) {
      return _BudgetFormBody(
        formState: formState,
        viewModel: viewModel,
        amountController: _amountController,
      );
    }
    final error = asyncState.error;
    if (asyncState.isLoading || error == null) {
      return const _BudgetFormLoading();
    }
    return _BudgetFormLoadError(error: error, onRetry: viewModel.retry);
  }
}

// MARK: - BudgetFormLoading
class _BudgetFormLoading extends StatelessWidget {
  const _BudgetFormLoading();

  @override
  Widget build(BuildContext context) {
    const body = Padding(
      padding: _loadingPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: _loadingGap),
          Text(_loadingLabel),
        ],
      ),
    );

    return const AppSheet(
      header: AppPickerHeader(title: _sheetTitle),
      body: Center(child: body),
      dragToDismiss: true,
      variant: AppSheetVariant.form,
    );
  }
}

// MARK: - BudgetFormLoadError
class _BudgetFormLoadError extends StatelessWidget {
  const _BudgetFormLoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = SizedBox(
      width: _footerWidth,
      child: PrimaryButton(label: _retryLabel, onPressed: onRetry),
    );
    final alert = SheetAlertData(
      message: '$_loadErrorTitle\n$error',
      severity: SheetAlertSeverity.error,
    );

    return AppSheet(
      header: const AppPickerHeader(title: _sheetTitle),
      body: const SizedBox.shrink(),
      footer: retry,
      alert: alert,
      dragToDismiss: true,
      variant: AppSheetVariant.form,
    );
  }
}

// MARK: - BudgetFormBody
class _BudgetFormBody extends StatelessWidget {
  const _BudgetFormBody({
    required this.formState,
    required this.viewModel,
    required this.amountController,
  });

  final BudgetFormViewState formState;
  final BudgetFormViewModel viewModel;
  final TextEditingController amountController;

  @override
  Widget build(BuildContext context) {
    if (amountController.text != formState.amountText) {
      amountController.text = formState.amountText;
    }

    final categoryRow = Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: _fieldContentPadding,
        title: const Text(_categoryLabel),
        trailing: Text(formState.scopeLabel),
        onTap: viewModel.requestPickCategory,
      ),
    );
    final amount = BudgetAmountInput(
      controller: amountController,
      amountText: formState.amountText,
      onChanged: viewModel.setAmount,
    );
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        categoryRow,
        const SizedBox(height: _fieldGap),
        amount,
      ],
    );
    final save = SizedBox(
      width: _footerWidth,
      child: PrimaryButton(
        label: _saveLabel,
        onPressed: formState.canSave ? viewModel.save : null,
      ),
    );
    final pad = usesBudgetAmountPad(context)
        ? BudgetAmountPad(
            controller: amountController,
            onChanged: viewModel.setAmount,
          )
        : null;
    final saveError = formState.error;
    final alert = saveError == null
        ? null
        : SheetAlertData(
            message:
                '$_saveErrorTitle\n${friendlyLedgerErrorMessage(saveError)}',
            severity: SheetAlertSeverity.error,
          );

    return AppSheet(
      header: const AppPickerHeader(title: _sheetTitle),
      body: body,
      footer: save,
      inputSurface: pad,
      alert: alert,
      dragToDismiss: true,
      variant: AppSheetVariant.form,
    );
  }
}
