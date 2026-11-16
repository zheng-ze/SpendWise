import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

// MARK: - Constants

const _emptyContentPadding = EdgeInsets.zero;

// MARK: - StatementDayPicker
class StatementDayPicker extends StatelessWidget {
  const StatementDayPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.sheetPresentation,
  });

  final int? selected;
  final ValueChanged<int> onSelected;

  final AppSheetPresentation Function(BuildContext)? sheetPresentation;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: _emptyContentPadding,
        title: const Text('Statement Day'),
        trailing: Text(selected?.toString() ?? 'Select'),
        onTap: () => _pick(context),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final chosen = await showPickerAppSheet<int>(
      context,
      presentation: sheetPresentation,
      builder: (routeContext) => AppPickerSheet(
        title: 'Statement day',
        body: _StatementDayOptions(
          selected: selected,
          onSelected: (day) => Navigator.of(routeContext).pop(day),
        ),
      ),
    );
    if (!context.mounted || chosen == null) return;
    onSelected(chosen);
  }
}

class _StatementDayOptions extends StatelessWidget {
  const _StatementDayOptions({
    required this.selected,
    required this.onSelected,
  });

  final int? selected;
  final ValueChanged<int> onSelected;

  static const _lastDay = 28;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var day = 1; day <= _lastDay; day++)
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              title: Text('$day'),
              trailing: day == selected ? const Icon(Icons.check) : null,
              onTap: () => onSelected(day),
            ),
          ),
      ],
    );
  }
}
