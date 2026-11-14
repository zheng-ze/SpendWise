import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/lists/category_icon.dart';
import 'package:spendwise/ui/common/pickers/symbol_picker.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/settings/category/category_form_state.dart';
import 'package:spendwise/ui/settings/category/parent_picker.dart';
import 'package:spendwise/ui/theme/category_palette.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _emptyContentPadding = EdgeInsets.zero;

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
  });

  static const _hint = 'Name';

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
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
    required this.locked,
    required this.onKindSelected,
  });

  static const _disabledOpacity = 0.5;
  static const _enabledOpacity = 1.0;
  static const _lockedNote =
      'Type is locked while transactions use this category.';
  static const _lockedNoteTopPadding = 4.0;

  final CategoryKind kind;
  final bool locked;
  final ValueChanged<CategoryKind> onKindSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selector = IgnorePointer(
      ignoring: locked,
      child: Opacity(
        opacity: locked ? _disabledOpacity : _enabledOpacity,
        child: SegmentedButton<CategoryKind>(
          segments: const [
            ButtonSegment(value: CategoryKind.income, label: Text('Income')),
            ButtonSegment(value: CategoryKind.expense, label: Text('Expense')),
          ],
          selected: {kind},
          onSelectionChanged: locked
              ? null
              : (selection) => onKindSelected(selection.first),
        ),
      ),
    );
    if (!locked) return selector;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        selector,
        Padding(
          padding: const EdgeInsets.only(top: _lockedNoteTopPadding),
          child: Text(
            _lockedNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
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

  final String symbol;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayColor = CategoryPalette.savedColor(
      toColorHex(color),
      context.colors,
    );
    return ListTile(
      contentPadding: _emptyContentPadding,
      title: const Text(_title),
      subtitle: Text(symbolDisplayName(symbol)),
      leading: CategoryIcon(symbolName: symbol, color: displayColor),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// MARK: - Analysis Switch

class CategoryAnalysisSwitch extends StatelessWidget {
  const CategoryAnalysisSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const _title = 'Include in analysis';

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: _emptyContentPadding,
      title: const Text(_title),
      value: value,
      onChanged: onChanged,
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: _emptyContentPadding,
      title: const Text(_title),
      trailing: Text(parentLabel ?? topLevelLabel),
      onTap: onTap,
    );
  }
}

// MARK: - Delete Button

class CategoryDeleteButton extends StatelessWidget {
  const CategoryDeleteButton({super.key, required this.onPressed});

  static const _label = 'Move to recycle bin';
  static const _fullWidth = double.infinity;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: _fullWidth,
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
        onPressed: onPressed,
        child: const Text(_label),
      ),
    );
  }
}
