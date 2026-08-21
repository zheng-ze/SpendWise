import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/amount_field.dart';
import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/transactions/entry_form_controller.dart';
import 'package:spendwise/ui/transactions/entry_form_logic.dart';
import 'package:spendwise/ui/transactions/recurrence_picker.dart'
    show frequencyLabels;

/// Field body shared by the edit and new-entry forms: kind selector, amount,
/// name, date, recurrence (new entries only), account/category or from/to,
/// and the include-in-analysis switch.
class EntryFields extends StatelessWidget {
  const EntryFields({
    super.key,
    required this.controller,
    required this.readOnly,
    this.showDelete = false,
  });

  final EntryFormController controller;
  final bool readOnly;
  final bool showDelete;

  Widget _kindSelector(BuildContext context) {
    return Center(
      child: IgnorePointer(
        ignoring: readOnly,
        child: SegmentedButton<EntryFormKind>(
          segments: const [
            ButtonSegment(value: EntryFormKind.expense, label: Text('Expense')),
            ButtonSegment(value: EntryFormKind.income, label: Text('Income')),
            ButtonSegment(
              value: EntryFormKind.transfer,
              label: Text('Transfer'),
            ),
          ],
          selected: {controller.kind},
          onSelectionChanged: readOnly
              ? null
              : (selection) => controller.setKind(selection.first),
        ),
      ),
    );
  }

  Widget _dateRow(BuildContext context, {required bool isNew}) {
    return Row(
      children: [
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            trailing: Text(formatEntryDate(controller.date)),
            onTap: readOnly ? null : () => controller.pickDate(context),
          ),
        ),
        if (isNew)
          IconButton(
            onPressed: () => controller.pickRecurrence(context),
            icon: Icon(
              Icons.repeat,
              color: controller.recurrence == null
                  ? null
                  : Theme.of(context).colorScheme.primary,
            ),
            tooltip: controller.recurrence == null
                ? 'Repeat'
                : frequencyLabels[controller.recurrence!],
          ),
      ],
    );
  }

  List<Widget> _recurrenceSection(BuildContext context) {
    return [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Ends'),
        value: controller.hasEndDate,
        onChanged: controller.setEndDateEnabled,
      ),
      if (controller.hasEndDate)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('End date'),
          trailing: Text(
            formatEntryDate(controller.endDate ?? controller.date),
          ),
          onTap: () => controller.pickEndDate(context),
        ),
    ];
  }

  List<Widget> _sourceDestinationRows(BuildContext context) {
    final kind = controller.kind;
    return [
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(kind == EntryFormKind.transfer ? 'From' : 'Account'),
        trailing: Text(controller.sourceLabel(controller.sourceId) ?? 'Select'),
        onTap: readOnly ? null : () => controller.pickSource(context),
      ),
      if (kind == EntryFormKind.transfer)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('To'),
          trailing: Text(
            controller.sourceLabel(controller.destinationId) ?? 'Select',
          ),
          onTap: readOnly ? null : () => controller.pickDestination(context),
        )
      else
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _categoryLeading(),
          title: const Text('Category'),
          trailing: Text(
            controller.categoryLabel(controller.categoryId) ?? 'None',
          ),
          onTap: readOnly || controller.isSystemEntry
              ? null
              : () => controller.pickCategory(context),
        ),
    ];
  }

  Widget? _categoryLeading() {
    final id = controller.categoryId;
    if (id == null) return null;
    final category = controller.ledger.state.categories[id];
    if (category == null) return null;
    return CategoryIcon(
      symbolName: category.symbol,
      color: parseColorHex(category.colorHex),
      size: 24,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = controller.mode == EntryFormMode.newEntry;

    // A Column, not a ListView: the caller already scrolls this, and a
    // nested scrollable has no bounded height to lay out against.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kindSelector(context),
        const SizedBox(height: 16),
        IgnorePointer(
          ignoring: readOnly,
          child: AmountField(
            controller: controller.amountController,
            allowsNegative: false,
            onChanged: (_) => controller.refresh(),
          ),
        ),
        const SizedBox(height: 16),
        IgnorePointer(
          ignoring: readOnly || controller.isSystemEntry,
          child: TextField(
            controller: controller.nameController,
            decoration: const InputDecoration(hintText: 'Name'),
            onChanged: (_) => controller.refresh(),
          ),
        ),
        const SizedBox(height: 16),
        _dateRow(context, isNew: isNew),
        if (isNew && controller.recurrence != null)
          ..._recurrenceSection(context),
        ..._sourceDestinationRows(context),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include in Analysis'),
          value: controller.includeInAnalysis,
          onChanged: readOnly || controller.isSystemEntry
              ? null
              : controller.setIncludeInAnalysis,
        ),
        if (showDelete) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => controller.delete(context),
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
