import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/budgets/budget_form_view_model.dart';
import 'package:spendwise/ui/common/amount_field.dart';
import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/form_scaffold.dart';
import 'package:spendwise/ui/format/color_hex.dart';

Future<void> showBudgetFormSheet({required BuildContext context}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const BudgetForm(),
  );
}

const budgetFormOverallSentinel = '__overall__';

/// Shows the category-picker sheet and returns the chosen category id,
/// [budgetFormOverallSentinel] for "Overall", or null if the user backed out.
Future<String?> showBudgetCategoryPickerSheet({
  required BuildContext context,
  required BudgetFormViewState formState,
}) {
  final groups = formState.groupedCategories;
  final budgeted = formState.budgetedCategoryIDs;

  final overallTile = ListTile(
    title: const Text('Overall'),
    onTap: () => Navigator.of(context).pop(budgetFormOverallSentinel),
  );
  final categoryRows = [
    for (final (root, children) in groups) ...[
      ListTile(
        leading: CategoryIcon(
          symbolName: root.symbol,
          color: parseColorHex(root.colorHex),
          size: 24,
        ),
        title: Text(
          root.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        enabled: !budgeted.contains(root.id),
        onTap: () => Navigator.of(context).pop(root.id),
      ),
      for (final child in children)
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: ListTile(
            leading: CategoryIcon(
              symbolName: child.symbol,
              color: parseColorHex(child.colorHex),
              size: 20,
            ),
            title: Text(
              child.name,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            onTap: () => Navigator.of(context).pop(child.id),
          ),
        ),
    ],
  ];

  return showModalBottomSheet<String?>(
    context: context,
    builder: (_) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [overallTile, ...categoryRows],
      ),
    ),
  );
}

class BudgetForm extends ConsumerStatefulWidget {
  const BudgetForm({super.key});

  @override
  ConsumerState<BudgetForm> createState() => _BudgetFormState();
}

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
    // Pulled from the ViewModel each build rather than bound both ways,
    // since the ViewModel is the single source of truth for form text.
    if (amountController.text != formState.amountText) {
      amountController.text = formState.amountText;
    }

    final categoryTile = ListTile(
      contentPadding: EdgeInsets.zero,
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
        children: [categoryTile, const SizedBox(height: 16), amountField],
      ),
    );
  }
}
