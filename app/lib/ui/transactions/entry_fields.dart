import 'package:domain/domain.dart' show LedgerStateQueries;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/amount_field.dart';
import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/common/recurrence_picker.dart'
    show frequencyLabels;
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/transactions/entry_form_logic.dart';
import 'package:spendwise/ui/transactions/entry_form_view_model.dart';

/// Field body shared by the edit and new-entry forms: kind selector, amount,
/// name, date, recurrence (new entries only), account/category or from/to,
/// and the include-in-analysis switch.
///
/// A [StatefulWidget], not stateless: the amount/name text fields need their
/// own [TextEditingController]s (a View-owned resource per this repo's
/// Flutter conventions), kept in sync with [state]'s raw text so an
/// external change — a revert, a receipt scan — updates what's on screen.
class EntryFields extends ConsumerStatefulWidget {
  const EntryFields({
    super.key,
    required this.viewModel,
    required this.state,
    required this.readOnly,
    this.showDelete = false,
  });

  final EntryFormViewModel viewModel;
  final EntryFormViewState state;
  final bool readOnly;
  final bool showDelete;

  @override
  ConsumerState<EntryFields> createState() => _EntryFieldsState();
}

class _EntryFieldsState extends ConsumerState<EntryFields> {
  late final _amountController = TextEditingController(
    text: widget.state.amountText,
  );
  late final _nameController = TextEditingController(
    text: widget.state.nameText,
  );

  @override
  void didUpdateWidget(EntryFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_amountController.text != widget.state.amountText) {
      _amountController.text = widget.state.amountText;
    }
    if (_nameController.text != widget.state.nameText) {
      _nameController.text = widget.state.nameText;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Widget _kindSelector() {
    return Center(
      child: IgnorePointer(
        ignoring: widget.readOnly,
        child: SegmentedButton<EntryFormKind>(
          segments: const [
            ButtonSegment(value: EntryFormKind.expense, label: Text('Expense')),
            ButtonSegment(value: EntryFormKind.income, label: Text('Income')),
            ButtonSegment(
              value: EntryFormKind.transfer,
              label: Text('Transfer'),
            ),
          ],
          selected: {widget.state.kind},
          onSelectionChanged: widget.readOnly
              ? null
              : (selection) => widget.viewModel.setKind(selection.first),
        ),
      ),
    );
  }

  Widget _dateRow({required bool isNew}) {
    final state = widget.state;
    return Row(
      children: [
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            trailing: Text(formatEntryDate(state.date)),
            onTap: widget.readOnly ? null : widget.viewModel.requestPickDate,
          ),
        ),
        if (isNew)
          IconButton(
            onPressed: widget.viewModel.requestPickRecurrence,
            icon: Icon(
              Icons.repeat,
              color: state.recurrence == null
                  ? null
                  : Theme.of(context).colorScheme.primary,
            ),
            tooltip: state.recurrence == null
                ? 'Repeat'
                : frequencyLabels[state.recurrence!],
          ),
      ],
    );
  }

  List<Widget> _recurrenceSection() {
    final state = widget.state;
    return [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Ends'),
        value: state.hasEndDate,
        onChanged: widget.viewModel.setEndDateEnabled,
      ),
      if (state.hasEndDate)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('End date'),
          trailing: Text(formatEntryDate(state.endDate ?? state.date)),
          onTap: widget.viewModel.requestPickEndDate,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final readOnly = widget.readOnly;
    final viewModel = widget.viewModel;
    final ledgerState = ref.watch(ledgerProvider)?.state;
    final isNew = state.mode == EntryFormMode.newEntry;

    String? sourceLabel(String? id) => ledgerState?.sourceName(id);
    String? categoryLabel(String? id) {
      if (id == null || ledgerState == null) return null;
      final category = ledgerState.categories[id];
      if (category == null) return null;
      final parentID = category.parentID;
      if (parentID == null) return category.name;
      final parent = ledgerState.categories[parentID];
      return parent == null ? category.name : '${parent.name}/${category.name}';
    }

    Widget? categoryLeading() {
      final id = state.categoryId;
      if (id == null || ledgerState == null) return null;
      final category = ledgerState.categories[id];
      if (category == null) return null;
      return CategoryIcon(
        symbolName: category.symbol,
        color: parseColorHex(category.colorHex),
        size: 24,
      );
    }

    final kind = state.kind;
    final sourceDestinationRows = [
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(kind == EntryFormKind.transfer ? 'From' : 'Account'),
        trailing: Text(sourceLabel(state.sourceId) ?? 'Select'),
        onTap: readOnly ? null : viewModel.requestPickSource,
      ),
      if (kind == EntryFormKind.transfer)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('To'),
          trailing: Text(sourceLabel(state.destinationId) ?? 'Select'),
          onTap: readOnly ? null : viewModel.requestPickDestination,
        )
      else
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: categoryLeading(),
          title: const Text('Category'),
          trailing: Text(categoryLabel(state.categoryId) ?? 'None'),
          onTap: readOnly || state.isSystemEntry
              ? null
              : viewModel.requestPickCategory,
        ),
    ];

    // A Column, not a ListView: the caller already scrolls this, and a
    // nested scrollable has no bounded height to lay out against.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kindSelector(),
        const SizedBox(height: 16),
        IgnorePointer(
          ignoring: readOnly,
          child: AmountField(
            controller: _amountController,
            allowsNegative: false,
            onChanged: viewModel.setAmount,
          ),
        ),
        const SizedBox(height: 16),
        IgnorePointer(
          ignoring: readOnly || state.isSystemEntry,
          child: TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Name'),
            onChanged: viewModel.setName,
          ),
        ),
        const SizedBox(height: 16),
        _dateRow(isNew: isNew),
        if (isNew && state.recurrence != null) ..._recurrenceSection(),
        ...sourceDestinationRows,
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include in Analysis'),
          value: state.includeInAnalysis,
          onChanged: readOnly || state.isSystemEntry
              ? null
              : viewModel.setIncludeInAnalysis,
        ),
        if (widget.showDelete) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: viewModel.delete,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete Entry'),
            ),
          ),
        ],
      ],
    );
  }
}
