import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/amount_field.dart';
import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/form_scaffold.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/format/money_format.dart';

const _rolloverLabels = {
  RolloverMode.none: 'None',
  RolloverMode.positiveOnly: 'Roll over unused',
  RolloverMode.both: 'Roll over unused or overspent',
};

Future<void> showBudgetFormSheet({
  required BuildContext context,
  required Ledger ledger,
  Budget? budget,
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
  const BudgetForm({super.key, required this.ledger, this.budget});

  final Ledger ledger;
  final Budget? budget;

  @override
  State<BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<BudgetForm> {
  late final TextEditingController _amountController = TextEditingController(
    text: widget.budget == null
        ? ''
        : formatPlainAmount(effectiveLimit(widget.budget!, _currentMonth)),
  );

  late final TextEditingController _carryCapController = TextEditingController(
    text: widget.budget?.carryCap == null
        ? ''
        : formatPlainAmount(widget.budget!.carryCap!),
  );

  late String? _categoryID = widget.budget?.categoryID;
  late RolloverMode _rolloverMode =
      widget.budget?.rolloverMode ?? RolloverMode.none;
  YearMonth? _overrideMonth;

  LedgerError? _error;

  bool get _isEditing => widget.budget != null;

  YearMonth get _currentMonth => YearMonth.fromUtc(DateTime.now().toUtc());

  Decimal? get _parsedAmount => Decimal.tryParse(_amountController.text);

  Decimal? get _parsedCarryCap => _carryCapController.text.trim().isEmpty
      ? null
      : Decimal.tryParse(_carryCapController.text);

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
    _carryCapController.dispose();
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

  Future<void> _pickOverrideMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.utc(_currentMonth.year, _currentMonth.month),
      firstDate: DateTime.utc(2000),
      lastDate: DateTime.utc(2100),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _overrideMonth = YearMonth(picked.year, picked.month));
  }

  Future<void> _save() async {
    final amount = _parsedAmount!.abs();

    try {
      final overrideMonth = _overrideMonth;
      if (overrideMonth != null) {
        widget.ledger.setBudgetMonthOverride(
          widget.budget!.id,
          overrideMonth,
          amount,
        );
      } else if (_isEditing) {
        widget.ledger.updateBudgetAmount(
          widget.budget!.id,
          amount,
          _currentMonth,
        );
      } else {
        widget.ledger.addBudget(
          _categoryID,
          amount,
          _rolloverMode,
          carryCap: _rolloverMode == RolloverMode.none
              ? null
              : _parsedCarryCap?.abs(),
        );
      }

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
    final rolloverTile = ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Rollover'),
      trailing: Text(_rolloverLabels[_rolloverMode]!),
      onTap: _isEditing ? null : () => _showRolloverPicker(context),
      enabled: !_isEditing,
    );
    final carryCapField = AmountField(
      controller: _carryCapController,
      allowsNegative: false,
      hintText: 'Rollover cap (optional)',
      onChanged: (_) => setState(() {}),
    );
    final overrideTile = ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('One-month override'),
      trailing: Text(
        _overrideMonth == null
            ? 'None'
            : '${_overrideMonth!.year}-${_overrideMonth!.month.toString().padLeft(2, '0')}',
      ),
      onTap: _pickOverrideMonth,
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
          rolloverTile,
          if (_rolloverMode != RolloverMode.none) ...[
            const SizedBox(height: 16),
            carryCapField,
          ],
          if (_isEditing) ...[const SizedBox(height: 16), overrideTile],
          errorSection,
          if (_isEditing) ...[const SizedBox(height: 24), deleteButton],
        ],
      ),
    );
  }

  Future<void> _showRolloverPicker(BuildContext context) async {
    final chosen = await showModalBottomSheet<RolloverMode>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final mode in RolloverMode.values)
              ListTile(
                title: Text(_rolloverLabels[mode]!),
                onTap: () => Navigator.of(context).pop(mode),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _rolloverMode = chosen;
      if (chosen == RolloverMode.none) _carryCapController.clear();
    });
  }
}
