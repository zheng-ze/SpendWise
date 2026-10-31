import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/budgets/budget_amount_input.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_editor_view_model.dart';
import 'package:spendwise/ui/budgets/budget_sheet_presentation.dart';
import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';

// MARK: - Constants
const _sheetTitle = 'Change limit';
const _saveLabel = 'Save';
const _loadErrorTitle = "Couldn't load the budget limit";
const _saveErrorTitle = 'Could not save budget limit';
const _footerWidth = double.infinity;
const _amountAlignment = AlignmentDirectional.centerStart;

// MARK: - Sheet Presenter
Future<void> showBudgetLimitEditSheet({
  required BuildContext context,
  required BudgetLimitDraftKey draftKey,
  required void Function(AppSheetRoute<void>) onRouteCreated,
}) {
  return showAppSheet<void>(
    context,
    presentation: budgetSheetPresentation(context),
    presentationResolver: budgetSheetPresentation,
    onRouteCreated: onRouteCreated,
    builder: (_) => BudgetLimitEditSheet(draftKey: draftKey),
  );
}

// MARK: - BudgetLimitEditSheet
class BudgetLimitEditSheet extends ConsumerStatefulWidget {
  const BudgetLimitEditSheet({super.key, required this.draftKey});

  final BudgetLimitDraftKey draftKey;

  @override
  ConsumerState<BudgetLimitEditSheet> createState() =>
      _BudgetLimitEditSheetState();
}

// MARK: - BudgetLimitEditSheetState
class _BudgetLimitEditSheetState extends ConsumerState<BudgetLimitEditSheet> {
  late final TextEditingController _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = budgetLimitEditorViewModelProvider(widget.draftKey);
    final editorState = ref.watch(provider).value;
    if (editorState == null) {
      return _BudgetLimitLoadError(error: ref.watch(provider).error);
    }
    return _BudgetLimitBody(
      editorState: editorState,
      viewModel: ref.read(provider.notifier),
      amountController: _amountController,
    );
  }
}

// MARK: - BudgetLimitLoadError
class _BudgetLimitLoadError extends StatelessWidget {
  const _BudgetLimitLoadError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    const save = SizedBox(
      width: _footerWidth,
      child: PrimaryButton(label: _saveLabel, onPressed: null),
    );
    final alert = SheetAlertData(
      message: '$_loadErrorTitle\n$error',
      severity: SheetAlertSeverity.error,
    );

    return AppSheet(
      header: const AppPickerHeader(title: _sheetTitle),
      body: const SizedBox.shrink(),
      footer: save,
      alert: alert,
      dragToDismiss: true,
      variant: AppSheetVariant.form,
    );
  }
}

// MARK: - BudgetLimitBody
class _BudgetLimitBody extends StatelessWidget {
  const _BudgetLimitBody({
    required this.editorState,
    required this.viewModel,
    required this.amountController,
  });

  final BudgetLimitEditorState editorState;
  final BudgetLimitEditorViewModel viewModel;
  final TextEditingController amountController;

  @override
  Widget build(BuildContext context) {
    if (amountController.text != editorState.amountText) {
      amountController.text = editorState.amountText;
    }

    final amountInput = BudgetAmountInput(
      controller: amountController,
      amountText: editorState.amountText,
      onChanged: viewModel.setAmount,
    );
    final amount = Align(alignment: _amountAlignment, child: amountInput);
    final save = SizedBox(
      width: _footerWidth,
      child: PrimaryButton(
        label: _saveLabel,
        onPressed: editorState.canSave ? viewModel.save : null,
      ),
    );
    final pad = usesBudgetAmountPad(context)
        ? BudgetAmountPad(
            controller: amountController,
            onChanged: viewModel.setAmount,
          )
        : null;
    final saveError = editorState.error;
    final alert = saveError == null
        ? null
        : SheetAlertData(
            message:
                '$_saveErrorTitle\n${friendlyLedgerErrorMessage(saveError)}',
            severity: SheetAlertSeverity.error,
          );

    return AppSheet(
      header: const AppPickerHeader(title: _sheetTitle),
      body: amount,
      footer: save,
      inputSurface: pad,
      alert: alert,
      dragToDismiss: true,
      variant: AppSheetVariant.form,
    );
  }
}
