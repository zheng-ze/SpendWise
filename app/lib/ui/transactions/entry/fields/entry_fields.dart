import 'package:domain/domain.dart' show LedgerStateQueries;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/inputs/amount_field.dart';
import 'package:spendwise/ui/common/lists/category_icon.dart';
import 'package:spendwise/ui/common/pickers/recurrence_picker.dart'
    show frequencyLabels;
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';

// MARK: - Visual Constants

const _fieldContentPadding = EdgeInsets.zero;
const _actionWidth = double.infinity;
const _rowGap = 16.0;
const _stackedValueGap = 4.0;

// MARK: - EntryFields
class EntryFields extends ConsumerStatefulWidget {
  const EntryFields({
    super.key,
    required this.viewModel,
    required this.state,
    required this.readOnly,
    this.showDelete = false,
    this.includeHead = true,
  });

  final EntryFormViewModel viewModel;
  final EntryFormViewState state;
  final bool readOnly;
  final bool showDelete;
  final bool includeHead;

  @override
  ConsumerState<EntryFields> createState() => _EntryFieldsState();
}

// MARK: - EntryFieldsState
class _EntryFieldsState extends ConsumerState<EntryFields> {
  static const _categoryIconSize = 24.0;
  static const _sectionSpacing = 16.0;
  static const _deleteSpacing = 8.0;

  late final _amountController = TextEditingController(
    text: widget.state.amountText,
  );
  late final _nameController = TextEditingController(
    text: widget.state.nameText,
  );

  @override
  void didUpdateWidget(EntryFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.includeHead) return;
    if (_amountController.text != widget.state.amountText) {
      _amountController.text = widget.state.amountText;
    }
    if (_nameController.text != widget.state.nameText) {
      _nameController.text = widget.state.nameText;
    }
  }

  @override
  void dispose() {
    if (widget.includeHead) {
      _amountController.dispose();
      _nameController.dispose();
    }
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
          child: _EntryValueRow(
            title: 'Date',
            value: formatEntryDate(state.date),
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
        contentPadding: _fieldContentPadding,
        title: const Text('Ends'),
        value: state.hasEndDate,
        onChanged: widget.viewModel.setEndDateEnabled,
      ),
      if (state.hasEndDate)
        _EntryValueRow(
          title: 'End date',
          value: formatEntryDate(state.endDate ?? state.date),
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
        size: _categoryIconSize,
      );
    }

    final kind = state.kind;
    final sourceDestinationRows = [
      _EntryValueRow(
        title: kind == EntryFormKind.transfer ? 'From' : 'Account',
        value: sourceLabel(state.sourceId) ?? 'Select',
        onTap: readOnly ? null : viewModel.requestPickSource,
      ),
      if (kind == EntryFormKind.transfer)
        _EntryValueRow(
          title: 'To',
          value: sourceLabel(state.destinationId) ?? 'Select',
          onTap: readOnly ? null : viewModel.requestPickDestination,
        )
      else
        _EntryValueRow(
          leading: categoryLeading(),
          title: 'Category',
          value: categoryLabel(state.categoryId) ?? 'None',
          onTap: readOnly || state.isSystemEntry
              ? null
              : viewModel.requestPickCategory,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.includeHead) ...[
          _kindSelector(),
          const SizedBox(height: _sectionSpacing),
          IgnorePointer(
            ignoring: readOnly,
            child: AmountField(
              controller: _amountController,
              allowsNegative: false,
              onChanged: viewModel.setAmount,
            ),
          ),
          const SizedBox(height: _sectionSpacing),
          IgnorePointer(
            ignoring: readOnly || state.isSystemEntry,
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'Name'),
              onChanged: viewModel.setName,
            ),
          ),
          const SizedBox(height: _sectionSpacing),
        ],
        _dateRow(isNew: isNew),
        if (isNew && state.recurrence != null) ..._recurrenceSection(),
        ...sourceDestinationRows,
        SwitchListTile(
          contentPadding: _fieldContentPadding,
          title: const Text('Include in Analysis'),
          value: state.includeInAnalysis,
          onChanged: readOnly || state.isSystemEntry
              ? null
              : viewModel.setIncludeInAnalysis,
        ),
        if (widget.showDelete) ...[
          const SizedBox(height: _deleteSpacing),
          SizedBox(
            width: _actionWidth,
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

class _EntryValueRow extends StatelessWidget {
  const _EntryValueRow({
    required this.title,
    required this.value,
    this.leading,
    this.onTap,
  });

  final String title;
  final String value;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: _fieldContentPadding,
      leading: leading,
      title: _TitleAndValue(title: title, value: value),
      onTap: onTap,
    );
  }
}

class _TitleAndValue extends StatelessWidget {
  const _TitleAndValue({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurface,
    );
    final valueStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final titleText = Text(title, style: titleStyle);
    final valueText = Text(value, style: valueStyle, textAlign: TextAlign.end);
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleWidth = _textWidth(context, title, titleStyle);
        final valueWidth = _textWidth(context, value, valueStyle);
        final fitsSideBySide =
            titleWidth + _rowGap + valueWidth <= constraints.maxWidth;
        if (fitsSideBySide) {
          return Row(
            children: [
              titleText,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: _rowGap),
                  child: valueText,
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleText,
            const SizedBox(height: _stackedValueGap),
            Align(alignment: AlignmentDirectional.centerEnd, child: valueText),
          ],
        );
      },
    );
  }

  double _textWidth(BuildContext context, String text, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
