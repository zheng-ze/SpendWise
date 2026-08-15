import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

const _typeLabels = <AccountType, String>{
  AccountType.cash: 'Cash',
  AccountType.checking: 'Checking',
  AccountType.savings: 'Savings',
  AccountType.card: 'Card',
  AccountType.prepaid: 'Prepaid',
  AccountType.investment: 'Investment',
  AccountType.insurance: 'Insurance',
  AccountType.other: 'Other',
  AccountType.loan: 'Loan',
  AccountType.overdraft: 'Overdraft',
};

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
      trailing: Text(_typeLabels[selected]!),
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
                  title: Text(_typeLabels[type]!),
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
