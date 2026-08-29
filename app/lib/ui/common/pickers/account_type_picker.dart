import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/account_type_format.dart';

class AccountTypePicker extends StatelessWidget {
  const AccountTypePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final AccountType selected;
  final ValueChanged<AccountType> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Type'),
      trailing: Text(accountTypeLabel(selected)),
      onTap: () => _pick(context),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final chosen = await showModalBottomSheet<AccountType>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.7,
        child: SafeArea(
          child: ListView(
            children: [
              for (final type in AccountType.values)
                ListTile(
                  title: Text(accountTypeLabel(type)),
                  trailing: type == selected ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(context).pop(type),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) onSelected(chosen);
  }
}
