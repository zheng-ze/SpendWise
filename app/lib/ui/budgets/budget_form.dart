import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/amount_field.dart';
import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/form_scaffold.dart';
import 'package:spendwise/ui/format/color_hex.dart';

Future<void> showBudgetFormSheet({
  required BuildContext context,
  required Ledger ledger,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.95,
      child: BudgetForm(ledger: ledger, budget: budget),
    ),
  );
}

class BudgetForm extends StatefulWidget {
  const BudgetForm({super.key, required this.ledger});

  final Ledger ledger;

  @override
  State<BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<BudgetForm> {
  final TextEditingController _amountController = TextEditingController();

  String? _categoryID;

  LedgerError? _error;

  bool get _isEditing => widget.budget != null;

  Decimal? get _parsedAmount => Decimal.tryParse(_amountController.text);

  Set<String?> get _budgetedCategoryIDs {
    final budgeted = widget.ledger.state.budgets.values
        .map((budget) => budget.categoryID)
        .toSet();
    if (_isEditing) budgeted.remove(widget.budget!.categoryID);
    return budgeted;
  }

  /// Root categories with an unbudgeted child are kept even when the root
  /// itself is already budgeted, so the child still has a group to sit
  /// under in the picker.
  List<(TransactionCategory, List<TransactionCategory>)>
  get _groupedCategories {
    final budgeted = _budgetedCategoryIDs;

    final active = widget.ledger.state.categories.values.where(
      (category) =>
          category.lifecycle.isActive && category.kind == CategoryKind.expense,
    );

    final roots = active.where((category) => category.parentID == null).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final childrenByParent = <String, List<TransactionCategory>>{};
    for (final category in active) {
      final parentID = category.parentID;
      if (parentID == null || budgeted.contains(category.id)) continue;
      (childrenByParent[parentID] ??= []).add(category);
    }
    for (final children in childrenByParent.values) {
      children.sort((a, b) => a.name.compareTo(b.name));
    }

    return [
      for (final root in roots)
        if (!budgeted.contains(root.id) ||
            (childrenByParent[root.id]?.isNotEmpty ?? false))
          (root, childrenByParent[root.id] ?? const []),
    ];
  }

  bool get _canSave {
    final amount = _parsedAmount;
    return amount != null && amount > Decimal.zero;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
    final groups = _groupedCategories;
    final budgeted = _budgetedCategoryIDs;

    final overallTile = ListTile(
      title: const Text('Overall'),
      onTap: () => Navigator.of(context).pop(),
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

    final chosen = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [overallTile, ...categoryRows],
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _categoryID = chosen);
  }

  Future<void> _save() async {
    final amount = _parsedAmount!.abs();

    try {
      widget.ledger.addBudget(_categoryID, amount);

      if (!mounted) return;
      Navigator.of(context).maybePop();
    } on LedgerError catch (error) {
      setState(() => _error = error);
    }
  }

  void _delete() {
    widget.ledger.deleteBudget(widget.budget!.id);
    Navigator.of(context).maybePop();
  }

  String get _categoryLabel {
    final id = _categoryID;
    if (id == null) return 'Overall';
    return widget.ledger.state.categories[id]?.name ?? '(category deleted)';
  }

  @override
  Widget build(BuildContext context) {
    final categoryTile = ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Category'),
      trailing: Text(_categoryLabel),
      onTap: _isEditing ? null : _pickCategory,
      enabled: !_isEditing,
    );
    final amountField = AmountField(
      controller: _amountController,
      allowsNegative: false,
      hintText: 'Limit',
      onChanged: (_) => setState(() {}),
    );
    final errorSection = ErrorSection(subject: 'budget', error: _error);
    final deleteButton = SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: _delete,
        child: const Text('Delete Budget'),
      ),
    );

    return FormScaffold(
      title: _isEditing ? 'Edit Budget' : 'New Budget',
      canSave: _canSave,
      onSave: _save,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          categoryTile,
          const SizedBox(height: 16),
          amountField,
          const SizedBox(height: 16),
          if (_isEditing) ...[const SizedBox(height: 16), overrideTile],
          errorSection,
          if (_isEditing) ...[const SizedBox(height: 24), deleteButton],
        ],
      ),
    );
  }
}
