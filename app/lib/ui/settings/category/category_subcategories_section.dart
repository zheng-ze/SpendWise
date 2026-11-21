import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/inputs/form_section_card.dart';
import 'package:spendwise/ui/common/lists/category_icon.dart';
import 'package:spendwise/ui/common/lists/medallion_row.dart';
import 'package:spendwise/ui/common/lists/section_label.dart';
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
  static const _labelPadding = EdgeInsets.only(bottom: 10.0);
  static const _rowPadding = EdgeInsets.symmetric(vertical: 7.0);
  static const _addPadding = EdgeInsets.symmetric(vertical: 4.0);
  static const _iconSize = 30.0;
  static const _chevronSize = 13.0;
  static const _dividerHeight = 1.0;
  static const _addVerticalPadding = 6.0;
  static const _addHorizontalPadding = 0.0;
  static const _addFontSize = 12.0;
  static const _addFontWeight = FontWeight.w600;
  static const _addIconSize = 18.0;
  static const _chevronIcon = Icons.chevron_right;
  static const _addIcon = Icons.add;

  final List<TransactionCategory> subcategories;
  final ValueChanged<TransactionCategory> onSubcategoryTap;
  final VoidCallback onAddSubcategory;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const label = SectionLabel(_label, padding: _labelPadding);
    final divider = Container(height: _dividerHeight, color: colors.edge);
    final rows = [
      for (final subcategory in subcategories) ...[
        _SubcategoryRow(
          key: ValueKey(subcategory.id),
          subcategory: subcategory,
          onTap: () => onSubcategoryTap(subcategory),
          iconSize: _iconSize,
          chevronSize: _chevronSize,
          chevronIcon: _chevronIcon,
          padding: _rowPadding,
        ),
        divider,
      ],
    ];
    final addStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: _addHorizontalPadding,
        vertical: _addVerticalPadding,
      ),
      textStyle: const TextStyle(
        fontSize: _addFontSize,
        fontWeight: _addFontWeight,
      ),
    );
    final addButton = TextButton.icon(
      style: addStyle,
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
    final chevron = Icon(chevronIcon, size: chevronSize, color: colors.subtext);
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
