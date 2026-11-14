import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/inputs/form_section_card.dart';
import 'package:spendwise/ui/common/lists/category_icon.dart';
import 'package:spendwise/ui/common/lists/medallion_row.dart';
import 'package:spendwise/ui/theme/category_palette.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Subcategories Section

class CategorySubcategoriesSection extends StatelessWidget {
  const CategorySubcategoriesSection({
    super.key,
    required this.subcategories,
    required this.onSubcategoryTap,
    required this.onAddSubcategory,
  });

  static const _label = 'Subcategories';
  static const _addLabel = 'Add subcategory';
  static const _labelWeight = FontWeight.w600;
  static const _labelPadding = EdgeInsets.only(bottom: 8.0);
  static const _rowPadding = EdgeInsets.symmetric(vertical: 8.0);
  static const _addPadding = EdgeInsets.symmetric(vertical: 4.0);
  static const _iconSize = 30.0;
  static const _chevronSize = 20.0;
  static const _addIconSize = 18.0;
  static const _chevronIcon = Icons.chevron_right;
  static const _addIcon = Icons.add;

  final List<TransactionCategory> subcategories;
  final ValueChanged<TransactionCategory> onSubcategoryTap;
  final VoidCallback onAddSubcategory;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labelStyle = context.text.small.copyWith(
      color: colors.subtext,
      fontWeight: _labelWeight,
    );
    final label = Padding(
      padding: _labelPadding,
      child: Text(_label.toUpperCase(), style: labelStyle),
    );
    final rows = [
      for (final subcategory in subcategories)
        _SubcategoryRow(
          key: ValueKey(subcategory.id),
          subcategory: subcategory,
          onTap: () => onSubcategoryTap(subcategory),
          iconSize: _iconSize,
          chevronSize: _chevronSize,
          chevronIcon: _chevronIcon,
          padding: _rowPadding,
        ),
    ];
    final addButton = TextButton.icon(
      onPressed: onAddSubcategory,
      icon: const Icon(_addIcon, size: _addIconSize),
      label: const Text(_addLabel),
    );
    final addRow = Padding(
      padding: _addPadding,
      child: Align(alignment: Alignment.centerLeft, child: addButton),
    );
    final card = FormSectionCard(children: [...rows, addRow]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [label, card],
    );
  }
}

// MARK: - Subcategory Row

class _SubcategoryRow extends StatelessWidget {
  const _SubcategoryRow({
    super.key,
    required this.subcategory,
    required this.onTap,
    required this.iconSize,
    required this.chevronSize,
    required this.chevronIcon,
    required this.padding,
  });

  final TransactionCategory subcategory;
  final VoidCallback onTap;
  final double iconSize;
  final double chevronSize;
  final IconData chevronIcon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final icon = CategoryIcon(
      symbolName: subcategory.symbol,
      color: CategoryPalette.savedColor(subcategory.colorHex, colors),
      size: iconSize,
    );
    final chevron = Icon(chevronIcon, size: chevronSize);
    final row = MedallionRow(
      leading: icon,
      title: subcategory.name,
      trailing: chevron,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: row),
    );
  }
}
