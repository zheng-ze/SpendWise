import 'package:domain/domain.dart'
    show Decimal, LedgerState, LedgerStateQueries;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/form_scaffold.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/entry_form_logic.dart';
import 'package:spendwise/ui/transactions/entry_form_view_model.dart';

/// Read-only receipt view: kind pill, entry name and signed amount up top,
/// plain rows below, and a single "Edit" action that switches to
/// [EntryFormMode.editing].
class ViewEntryForm extends ConsumerWidget {
  const ViewEntryForm({
    super.key,
    required this.viewModel,
    required this.state,
  });

  final EntryFormViewModel viewModel;
  final EntryFormViewState state;

  AmountKind get _amountKind => switch (state.kind) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = AmountColors.of(theme);
    final ledgerState = ref.watch(ledgerProvider)?.state;
    final amount = state.parsedAmount ?? Decimal.zero;
    final kind = state.kind;
    final signedAmount = kind == EntryFormKind.expense ? -amount : amount;
    final sourceLabel = ledgerState?.sourceName(state.sourceId) ?? 'Select';
    final destinationLabel =
        ledgerState?.sourceName(state.destinationId) ?? 'Select';
    final categoryLabel =
        _categoryLabel(ledgerState, state.categoryId) ?? 'None';

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
        Text(state.nameText, style: theme.textTheme.titleMedium),
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
                _row('Date', formatEntryDate(state.date)),
                if (kind == EntryFormKind.transfer) ...[
                  _row('From', sourceLabel),
                  _row('To', destinationLabel),
                ] else ...[
                  _row('Account', sourceLabel),
                  _row('Category', categoryLabel),
                ],
                _row(
                  'Include in Analysis',
                  state.includeInAnalysis ? 'Yes' : 'No',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: viewModel.startEditing,
            child: const Text('Edit'),
          ),
        ),
      ],
    );
  }

  String? _categoryLabel(LedgerState? ledgerState, String? id) {
    if (id == null || ledgerState == null) return null;
    final category = ledgerState.categories[id];
    if (category == null) return null;
    final parentID = category.parentID;
    if (parentID == null) return category.name;
    final parent = ledgerState.categories[parentID];
    return parent == null ? category.name : '${parent.name}/${category.name}';
  }
}
