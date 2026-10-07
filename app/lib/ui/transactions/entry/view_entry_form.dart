import 'package:domain/domain.dart'
    show Decimal, LedgerState, LedgerStateQueries;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/form_scaffold.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_logic.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';

class ViewEntryForm extends ConsumerWidget {
  const ViewEntryForm({
    super.key,
    required this.viewModel,
    required this.state,
  });

  final EntryFormViewModel viewModel;
  final EntryFormViewState state;

  static const _chipHorizontalPadding = 10.0;
  static const _chipVerticalPadding = 4.0;
  static const _chipBorderRadius = 999.0;
  static const _headerNameGap = 8.0;
  static const _nameAmountGap = 4.0;
  static const _contentGap = 16.0;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ledgerState = ref.watch(ledgerProvider)?.state;
    final amount = state.parsedAmount ?? Decimal.zero;
    final kind = state.kind;
    final signedAmount = kind == EntryFormKind.expense ? -amount : amount;
    final sourceLabel = ledgerState?.sourceName(state.sourceId) ?? 'Select';
    final destinationLabel =
        ledgerState?.sourceName(state.destinationId) ?? 'Select';
    final categoryLabel =
        _categoryLabel(ledgerState, state.categoryId) ?? 'None';
    final amountStyle = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.bold,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: AmountStyle.of(context, kind: _amountKind).color,
    );
    final detailRows = [
      _DetailRow(label: 'Date', value: formatEntryDate(state.date)),
      if (kind == EntryFormKind.transfer) ...[
        _DetailRow(label: 'From', value: sourceLabel),
        _DetailRow(label: 'To', value: destinationLabel),
      ] else ...[
        _DetailRow(label: 'Account', value: sourceLabel),
        _DetailRow(label: 'Category', value: categoryLabel),
      ],
      _DetailRow(
        label: 'Include in Analysis',
        value: state.includeInAnalysis ? 'Yes' : 'No',
      ),
    ];

    return SheetShell(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: _chipHorizontalPadding,
            vertical: _chipVerticalPadding,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(_chipBorderRadius),
          ),
          child: Text(_kindLabel(kind), style: theme.textTheme.labelSmall),
        ),
        const SizedBox(height: _headerNameGap),
        Text(state.nameText, style: theme.textTheme.titleMedium),
        const SizedBox(height: _nameAmountGap),
        Text(
          formatSignedMoney(signedAmount, kind: _amountKind),
          style: amountStyle,
        ),
        const SizedBox(height: _contentGap),
        Flexible(
          child: SingleChildScrollView(child: Column(children: detailRows)),
        ),
        const SizedBox(height: _contentGap),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  static const _rowVerticalPadding = 8.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _rowVerticalPadding),
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
}
