import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/lists/category_icon.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _titleLabel = 'Inside which category?';

const topLevelLabel = 'Top level';

const _selectedIcon = Icons.check;

const _topLevelIcon = Icons.sell_outlined;

const double _rowMinHeight = 48;
const double _rowVerticalPadding = 10;
const double _rowGap = 8;
const double _dividerWidth = 1;
const double _leadingSize = 28;
const double _topLevelIconSize = 18;
const double _labelFontSize = 12;
const _selectedWeight = FontWeight.w600;
const _unselectedWeight = FontWeight.w400;

// MARK: - ParentChoice
class ParentChoice {
  const ParentChoice(this.parentID);

  final String? parentID;
}

// MARK: - Show
Future<ParentChoice?> showParentPickerSheet({
  required BuildContext context,
  required AppSheetPresentation Function(BuildContext) presentation,
  required List<TransactionCategory> parents,
  required String? currentParentID,
  PickerRouteCallback? onRouteCreated,
}) {
  final topLevel = _ParentRow(
    label: topLevelLabel,
    leading: const _TopLevelLeading(),
    choice: const ParentChoice(null),
    selected: currentParentID == null,
  );
  final rows = [
    topLevel,
    for (final parent in parents)
      _ParentRow(
        label: parent.name,
        leading: CategoryIcon(
          symbolName: parent.symbol,
          color: parseColorHex(parent.colorHex),
          size: _leadingSize,
        ),
        choice: ParentChoice(parent.id),
        selected: parent.id == currentParentID,
      ),
  ];
  final sheet = AppPickerSheet(
    title: _titleLabel,
    body: SingleChildScrollView(child: Column(children: rows)),
  );
  return showPickerAppSheet<ParentChoice>(
    context,
    presentation: presentation,
    onRouteCreated: onRouteCreated,
    builder: (_) => sheet,
  );
}

// MARK: - TopLevelLeading
class _TopLevelLeading extends StatelessWidget {
  const _TopLevelLeading();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _leadingSize,
      height: _leadingSize,
      child: Icon(
        _topLevelIcon,
        size: _topLevelIconSize,
        color: context.colors.subtext,
      ),
    );
  }
}

// MARK: - ParentRow
class _ParentRow extends StatelessWidget {
  const _ParentRow({
    required this.label,
    required this.leading,
    required this.choice,
    required this.selected,
  });

  final String label;
  final Widget leading;
  final ParentChoice choice;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labelStyle = TextStyle(
      color: colors.text,
      fontSize: _labelFontSize,
      fontWeight: selected ? _selectedWeight : _unselectedWeight,
    );
    final divider = BorderSide(color: colors.edge, width: _dividerWidth);
    final check = Icon(_selectedIcon, color: colors.action);
    final row = Row(
      spacing: _rowGap,
      children: [
        leading,
        Expanded(child: Text(label, style: labelStyle)),
        if (selected) check,
      ],
    );
    final content = Container(
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      padding: const EdgeInsets.symmetric(vertical: _rowVerticalPadding),
      decoration: BoxDecoration(border: Border(bottom: divider)),
      child: row,
    );
    return InkWell(
      onTap: () => Navigator.of(context).pop(choice),
      child: content,
    );
  }
}
