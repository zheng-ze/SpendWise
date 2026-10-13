import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/budgets/budget_list/budget_form_view_model.dart';
import 'package:spendwise/ui/common/inputs/amount_field.dart';
import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/inputs/form_scaffold.dart';

// MARK: - Visual Constants

const _fieldContentPadding = EdgeInsets.zero;

// MARK: - Sheet Presenter
Future<void> showBudgetFormSheet({required BuildContext context}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const BudgetForm(),
  );
}

// MARK: - BudgetForm
class BudgetForm extends ConsumerStatefulWidget {
  const BudgetForm({super.key});

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
    final asyncState = ref.watch(budgetFormViewModelProvider);

    return asyncState.when(
      data: (formState) => _BudgetFormBody(
        formState: formState,
        viewModel: ref.read(budgetFormViewModelProvider.notifier),
        amountController: _amountController,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
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

  static const _fieldGap = 16.0;

  @override
  Widget build(BuildContext context) {
    if (amountController.text != formState.amountText) {
      amountController.text = formState.amountText;
    }

    final categoryTile = ListTile(
      contentPadding: _fieldContentPadding,
      title: const Text('Category'),
      trailing: Text(formState.categoryLabel),
      onTap: viewModel.requestPickCategory,
    );
    final amountField = AmountField(
      controller: amountController,
      allowsNegative: false,
      hintText: 'Limit',
      autofocus: true,
      onChanged: viewModel.setAmount,
    );

    return FormScaffold(
      title: 'New Budget',
      canSave: formState.canSave,
      onSave: viewModel.save,
      error: ErrorSection(subject: 'budget', error: formState.error),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          categoryTile,
          const SizedBox(height: _fieldGap),
          amountField,
        ],
      ),
    );
  }
}
