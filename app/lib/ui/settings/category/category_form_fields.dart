import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/inputs/form_section_card.dart';
import 'package:spendwise/ui/common/inputs/form_sheet_row.dart';
import 'package:spendwise/ui/common/inputs/segmented_control.dart';
import 'package:spendwise/ui/common/lists/category_icon.dart';
import 'package:spendwise/ui/common/lists/section_label.dart';
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
const _expandIcon = Icons.expand_more;
const _collapseIcon = Icons.expand_less;
const _lockIcon = Icons.lock_outline;
const _chevronIcon = Icons.chevron_right;
const _analysisTitle = 'Count in Trends and budgets';
const _categoryTypeHint = 'The type is fixed once entries use this category.';
const _subcategoryCountHint = 'Include this subcategory in totals';

// MARK: - Swatches

const categorySwatches = [
  Color(0xFFFF9500),
  Color(0xFF34C759),
  Color(0xFF5856D6),
  Color(0xFF30D158),
  Color(0xFF63E6BE),
  defaultCategoryColor,
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
    this.hint,
  });

  static const _title = _analysisTitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: _emptyContentPadding,
      title: const Text(_title),
      subtitle: hint == null ? null : Text(hint!),
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
    required this.isSubcategory,
  });

  static const _title = 'More options';

  final bool includeInAnalysis;
  final ValueChanged<bool> onIncludeInAnalysisChanged;
  final bool isSubcategory;

  @override
  State<CategoryMoreOptions> createState() => _CategoryMoreOptionsState();
}

class _CategoryMoreOptionsState extends State<CategoryMoreOptions> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final chevron = Icon(
      _expanded ? _collapseIcon : _expandIcon,
      size: _trailingIconSize,
    );
    final header = ListTile(
      contentPadding: _emptyContentPadding,
      title: const Text(CategoryMoreOptions._title),
      subtitle: _expanded ? null : const Text(_analysisTitle),
      trailing: chevron,
      onTap: _toggle,
    );
    final analysis = CategoryAnalysisSwitch(
      value: widget.includeInAnalysis,
      onChanged: widget.onIncludeInAnalysisChanged,
      hint: widget.isSubcategory ? _subcategoryCountHint : null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, if (_expanded) analysis],
    );
  }
}

// MARK: - More Options Section

class CategoryMoreOptionsSection extends StatelessWidget {
  const CategoryMoreOptionsSection({
    super.key,
    required this.includeInAnalysis,
    required this.onIncludeInAnalysisChanged,
    required this.kind,
    required this.isSubcategory,
    required this.parentLabel,
  });

  static const _label = 'More options';
  static const _labelPadding = EdgeInsets.only(bottom: 8.0);

  final bool includeInAnalysis;
  final ValueChanged<bool> onIncludeInAnalysisChanged;
  final CategoryKind kind;
  final bool isSubcategory;
  final String? parentLabel;

  @override
  Widget build(BuildContext context) {
    const label = SectionLabel(_label, padding: _labelPadding);
    final typeHint = isSubcategory
        ? (parentLabel == null ? null : 'Set by $parentLabel')
        : _categoryTypeHint;
    final analysis = CategoryAnalysisSwitch(
      value: includeInAnalysis,
      onChanged: onIncludeInAnalysisChanged,
      hint: isSubcategory ? _subcategoryCountHint : null,
    );
    final type = CategoryTypeRow(kind: kind, hint: typeHint);
    final card = FormSectionCard(children: [analysis, type]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [label, card],
    );
  }
}

// MARK: - Type Row

class CategoryTypeRow extends StatelessWidget {
  const CategoryTypeRow({super.key, required this.kind, required this.hint});

  static const _title = 'Type';
  static const _captionGap = 4.0;

  final CategoryKind kind;
  final String? hint;

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
        const Icon(_lockIcon, size: _trailingIconSize),
        Text(label),
      ],
    );
    final row = FormSheetRow(label: _title, trailing: value);
    final hintText = hint;
    if (hintText == null) return row;
    final caption = Padding(
      padding: const EdgeInsets.only(bottom: _captionGap),
      child: Text(hintText, style: Theme.of(context).textTheme.bodySmall),
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
    return const Icon(_chevronIcon, size: _trailingIconSize);
  }
}
