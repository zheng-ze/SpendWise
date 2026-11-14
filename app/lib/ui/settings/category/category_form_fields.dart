import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/inputs/form_sheet_row.dart';
import 'package:spendwise/ui/common/inputs/segmented_control.dart';
import 'package:spendwise/ui/common/lists/category_icon.dart';
import 'package:spendwise/ui/common/pickers/symbol_picker.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/settings/category/category_form_state.dart';
import 'package:spendwise/ui/settings/category/parent_picker.dart';
import 'package:spendwise/ui/theme/category_palette.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _emptyContentPadding = EdgeInsets.zero;
const _trailingGap = 8.0;
const _trailingIconSize = 20.0;
const _analysisTitle = 'Count in Trends and budgets';

// MARK: - Swatches

const categorySwatches = [
  defaultCategoryColor,
  Color(0xFFFF3B30),
  Color(0xFFFF9500),
  Color(0xFFFFCC00),
  Color(0xFF34C759),
  Color(0xFF5AC8FA),
  Color(0xFFAF52DE),
  Color(0xFF8E8E93),
];

// MARK: - Name Field

class CategoryFormNameField extends StatelessWidget {
  const CategoryFormNameField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.autofocus,
  });

  static const _hint = 'Name';

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      decoration: const InputDecoration(hintText: _hint),
      onChanged: onChanged,
    );
  }
}

// MARK: - Kind Selector

class CategoryKindSelector extends StatelessWidget {
  const CategoryKindSelector({
    super.key,
    required this.kind,
    required this.onKindSelected,
  });

  static const _options = [
    SegmentedOption(value: CategoryKind.expense, label: 'Expense'),
    SegmentedOption(value: CategoryKind.income, label: 'Income'),
  ];

  final CategoryKind kind;
  final ValueChanged<CategoryKind> onKindSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedControl<CategoryKind>(
      options: _options,
      value: kind,
      onChanged: onKindSelected,
    );
  }
}

// MARK: - Symbol Tile

class CategorySymbolTile extends StatelessWidget {
  const CategorySymbolTile({
    super.key,
    required this.symbol,
    required this.color,
    required this.onTap,
  });

  static const _title = 'Icon and colour';
  static const _iconSize = 24.0;

  final String symbol;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayColor = CategoryPalette.savedColor(
      toColorHex(color),
      context.colors,
    );
    final value = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: _trailingGap,
      children: [
        CategoryIcon(symbolName: symbol, color: displayColor, size: _iconSize),
        Text(symbolDisplayName(symbol)),
        const _TrailingChevron(),
      ],
    );
    return FormSheetRow(label: _title, trailing: value, onTap: onTap);
  }
}

// MARK: - Analysis Switch

class CategoryAnalysisSwitch extends StatelessWidget {
  const CategoryAnalysisSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const _title = _analysisTitle;
  static const _hint =
      'Turn off for money you get back, such as work expenses you claim.';

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: _emptyContentPadding,
      title: const Text(_title),
      subtitle: const Text(_hint),
      value: value,
      onChanged: onChanged,
    );
  }
}

// MARK: - More Options

class CategoryMoreOptions extends StatefulWidget {
  const CategoryMoreOptions({
    super.key,
    required this.includeInAnalysis,
    required this.onIncludeInAnalysisChanged,
    required this.isEditing,
    required this.kind,
    required this.isReferenced,
  });

  static const _title = 'More options';
  static const _typeSuffix = ', type';

  final bool includeInAnalysis;
  final ValueChanged<bool> onIncludeInAnalysisChanged;
  final bool isEditing;
  final CategoryKind kind;
  final bool isReferenced;

  @override
  State<CategoryMoreOptions> createState() => _CategoryMoreOptionsState();
}

class _CategoryMoreOptionsState extends State<CategoryMoreOptions> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final closedSubtitle = widget.isEditing
        ? '$_analysisTitle${CategoryMoreOptions._typeSuffix}'
        : _analysisTitle;
    final chevron = Icon(
      _expanded ? Icons.expand_less : Icons.expand_more,
      size: _trailingIconSize,
    );
    final header = ListTile(
      contentPadding: _emptyContentPadding,
      title: const Text(CategoryMoreOptions._title),
      subtitle: _expanded ? null : Text(closedSubtitle),
      trailing: chevron,
      onTap: _toggle,
    );
    final analysis = CategoryAnalysisSwitch(
      value: widget.includeInAnalysis,
      onChanged: widget.onIncludeInAnalysisChanged,
    );
    final type = CategoryTypeRow(
      kind: widget.kind,
      showsCaption: widget.isReferenced,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (_expanded) analysis,
        if (_expanded && widget.isEditing) type,
      ],
    );
  }
}

// MARK: - Type Row

class CategoryTypeRow extends StatelessWidget {
  const CategoryTypeRow({
    super.key,
    required this.kind,
    required this.showsCaption,
  });

  static const _title = 'Type';
  static const _caption = 'The type is fixed once entries use this category.';
  static const _captionGap = 4.0;

  final CategoryKind kind;
  final bool showsCaption;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      CategoryKind.expense => 'Expense',
      CategoryKind.income => 'Income',
    };
    final value = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: _trailingGap,
      children: [
        const Icon(Icons.lock_outline, size: _trailingIconSize),
        Text(label),
      ],
    );
    final row = FormSheetRow(label: _title, trailing: value);
    if (!showsCaption) return row;
    final caption = Padding(
      padding: const EdgeInsets.only(bottom: _captionGap),
      child: Text(_caption, style: Theme.of(context).textTheme.bodySmall),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [row, caption],
    );
  }
}

// MARK: - Parent Tile

class CategoryParentTile extends StatelessWidget {
  const CategoryParentTile({
    super.key,
    required this.parentLabel,
    required this.onTap,
  });

  static const _title = 'Inside';

  final String? parentLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = Text(parentLabel ?? topLevelLabel);
    final value = onTap == null
        ? label
        : Row(
            mainAxisSize: MainAxisSize.min,
            spacing: _trailingGap,
            children: [label, const _TrailingChevron()],
          );
    return FormSheetRow(label: _title, trailing: value, onTap: onTap);
  }
}

// MARK: - Trailing Chevron

class _TrailingChevron extends StatelessWidget {
  const _TrailingChevron();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.chevron_right, size: _trailingIconSize);
  }
}
