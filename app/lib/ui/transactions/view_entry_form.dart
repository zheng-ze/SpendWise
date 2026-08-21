import 'package:domain/domain.dart' show Decimal;
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/form_scaffold.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/entry_form_controller.dart';
import 'package:spendwise/ui/transactions/entry_form_logic.dart';

/// Read-only receipt view: kind pill, entry name and signed amount up top,
/// plain rows below, and a single "Edit" action that switches [controller]
/// to [EntryFormMode.editing].
class ViewEntryForm extends StatelessWidget {
  const ViewEntryForm({super.key, required this.controller});

  final EntryFormController controller;

  AmountKind get _amountKind => switch (controller.kind) {
    EntryFormKind.expense => AmountKind.expense,
    EntryFormKind.income => AmountKind.income,
    EntryFormKind.transfer => AmountKind.transfer,
  };

  static String _kindLabel(EntryFormKind kind) {
    return switch (kind) {
      EntryFormKind.expense => 'Expense',
      EntryFormKind.income => 'Income',
      EntryFormKind.transfer => 'Transfer',
    };
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AmountColors.of(theme);
    final amount = controller.parsedAmount ?? Decimal.zero;
    final kind = controller.kind;
    final signedAmount = kind == EntryFormKind.expense ? -amount : amount;
    final sourceLabel = controller.sourceLabel(controller.sourceId) ?? 'Select';
    final destinationLabel =
        controller.sourceLabel(controller.destinationId) ?? 'Select';
    final categoryLabel =
        controller.categoryLabel(controller.categoryId) ?? 'None';

    return SheetShell(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(_kindLabel(kind), style: theme.textTheme.labelSmall),
        ),
        const SizedBox(height: 8),
        Text(
          controller.nameController.text,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          formatSignedAmount(signedAmount, _amountKind),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: colors.kindColor(_amountKind),
          ),
        ),
        const SizedBox(height: 16),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _row('Date', formatEntryDate(controller.date)),
                if (kind == EntryFormKind.transfer) ...[
                  _row('From', sourceLabel),
                  _row('To', destinationLabel),
                ] else ...[
                  _row('Account', sourceLabel),
                  _row('Category', categoryLabel),
                ],
                _row(
                  'Include in Analysis',
                  controller.includeInAnalysis ? 'Yes' : 'No',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: controller.startEditing,
            child: const Text('Edit'),
          ),
        ),
      ],
    );
  }
}
