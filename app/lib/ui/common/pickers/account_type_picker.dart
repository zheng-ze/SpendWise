import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/format/account_type_format.dart';

// MARK: - Constants

const _emptyContentPadding = EdgeInsets.zero;

// MARK: - AccountTypePicker
class AccountTypePicker extends StatelessWidget {
  const AccountTypePicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.sheetPresentation,
  });

  final AccountType selected;
  final ValueChanged<AccountType> onSelected;

  final AppSheetPresentation Function(BuildContext)? sheetPresentation;

  static const _sheetHeightFactor = 0.7;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: _emptyContentPadding,
        title: const Text('Type'),
        trailing: Text(accountTypeLabel(selected)),
        onTap: () => _pick(context),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final presentation = sheetPresentation;
    final chosen = presentation == null
        ? await showModalBottomSheet<AccountType>(
            context: context,
            isScrollControlled: true,
            builder: (_) => FractionallySizedBox(
              heightFactor: _sheetHeightFactor,
              child: SafeArea(
                child: SingleChildScrollView(child: _options(context)),
              ),
            ),
          )
        : await showPickerAppSheet<AccountType>(
            context,
            presentation: presentation,
            builder: (routeContext) => AppPickerSheet(
              title: 'Account type',
              body: _options(routeContext),
            ),
          );
    if (!context.mounted || chosen == null) return;
    onSelected(chosen);
  }

  Widget _options(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final type in AccountType.values)
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              title: Text(accountTypeLabel(type)),
              trailing: type == selected ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(type),
            ),
          ),
      ],
    );
  }
}
