import 'package:domain/domain.dart' show LedgerStateQueries;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/inputs/amount_field.dart';
import 'package:spendwise/ui/common/lists/category_icon.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';

// MARK: - Visual Constants

const _fieldContentPadding = EdgeInsets.zero;
const _actionWidth = double.infinity;
const _rowGap = 16.0;
const _stackedValueGap = 4.0;
const _dividerThickness = 1.0;

// MARK: - EntryFields
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

  Widget _dateRow() {
    return _EntryValueRow(
      title: 'Date',
      value: formatEntryDate(widget.state.date),
      onTap: widget.readOnly ? null : widget.viewModel.requestPickDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final readOnly = widget.readOnly;
    final viewModel = widget.viewModel;
    final ledgerState = ref.watch(ledgerProvider)?.state;

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

    final amountField = IgnorePointer(
      ignoring: readOnly,
      child: AmountField(
        controller: _amountController,
        allowsNegative: false,
        onChanged: viewModel.setAmount,
      ),
    );
    final nameField = IgnorePointer(
      ignoring: readOnly || state.isSystemEntry,
      child: TextField(
        controller: _nameController,
        decoration: const InputDecoration(hintText: 'Name'),
        onChanged: viewModel.setName,
      ),
    );
    final head = [
      _kindSelector(),
      const SizedBox(height: _sectionSpacing),
      amountField,
      const SizedBox(height: _sectionSpacing),
      nameField,
      const SizedBox(height: _sectionSpacing),
    ];

    final analysisSwitch = SwitchListTile(
      contentPadding: _fieldContentPadding,
      title: const Text('Include in Analysis'),
      value: state.includeInAnalysis,
      onChanged: readOnly || state.isSystemEntry
          ? null
          : viewModel.setIncludeInAnalysis,
    );
    final rows = [_dateRow(), ...sourceDestinationRows, analysisSwitch];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...head,
        ...rows,
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

class EntryRowDivider extends StatelessWidget {
  const EntryRowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: _dividerThickness,
      thickness: _dividerThickness,
      color: context.colors.edge,
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
