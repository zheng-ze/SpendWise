import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/account_form_logic.dart';
import 'package:spendwise/ui/accounts/account_type_picker.dart';
import 'package:spendwise/ui/accounts/statement_day_picker.dart';
import 'package:spendwise/ui/common/amount_field.dart';
import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/form_scaffold.dart';
import 'package:spendwise/ui/common/two_column_picker_sheet.dart';

/// Opens the account/subpocket creation sheet. Creation-only, unlike the
/// entry form, so there is no entity parameter.
Future<void> showAccountFormSheet({
  required BuildContext context,
  required Ledger ledger,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.95,
      child: AccountForm(ledger: ledger),
    ),
  );
}

class AccountForm extends StatefulWidget {
  const AccountForm({super.key, required this.ledger});

  final Ledger ledger;

  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  late final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _balanceController = TextEditingController();

  AccountFormKind _kind = AccountFormKind.account;
  AccountType _type = AccountType.cash;
  int? _statementDay;
  String? _parentId;

  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  List<Account> get _pocketableParents =>
      pocketableParents(widget.ledger.state);

  bool get _isLockedToAccount => _pocketableParents.isEmpty;

  bool get _canSave => canSaveAccountForm(
    kind: _isLockedToAccount ? AccountFormKind.account : _kind,
    name: _nameController.text,
    parentId: _parentId,
  );

  void _setKind(AccountFormKind kind) {
    setState(() {
      _kind = kind;
      if (kind == AccountFormKind.account) _parentId = null;
    });
  }

  void _setType(AccountType type) {
    setState(() {
      _type = type;
      if (type != AccountType.card) _statementDay = null;
    });
  }

  Future<void> _pickParent() async {
    final parents = _pocketableParents;
    final outcome = await showTwoColumnPickerSheet(
      context: context,
      title: 'Select Account',
      groups: [
        for (final account in parents)
          PickerOption(id: account.id, label: account.name),
      ],
      selectedId: _parentId,
    );
    if (outcome == null) return;
    if (outcome is PickerChose) setState(() => _parentId = outcome.id);
  }

  Future<void> _save() async {
    // A stale picker selection (parent gone card, or archived between open
    // and save) must not sneak a pocket past this guard.
    final effectiveKind = _isLockedToAccount ? AccountFormKind.account : _kind;
    final name = _nameController.text.trim();

    try {
      if (effectiveKind == AccountFormKind.subpocket) {
        widget.ledger.addPocket(SubPocket(name: name), _parentId!);
      } else {
        final isCard = _type == AccountType.card;
        final account = Account(
          name: name,
          type: _type,
          statementDay: isCard ? _statementDay : null,
        );
        widget.ledger.addAccount(account);

        final balance = Decimal.tryParse(_balanceController.text);
        if (balance != null && balance != Decimal.zero) {
          widget.ledger.setOpeningBalance(balance, account.id);
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on LedgerError catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveKind = _isLockedToAccount ? AccountFormKind.account : _kind;

    return FormScaffold(
      title: effectiveKind == AccountFormKind.subpocket
          ? 'New Subpocket'
          : 'New Account',
      canSave: _canSave,
      onSave: _save,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          IgnorePointer(
            ignoring: _isLockedToAccount,
            child: SegmentedButton<AccountFormKind>(
              segments: const [
                ButtonSegment(
                  value: AccountFormKind.account,
                  label: Text('Account'),
                ),
                ButtonSegment(
                  value: AccountFormKind.subpocket,
                  label: Text('Subpocket'),
                ),
              ],
              selected: {effectiveKind},
              onSelectionChanged: _isLockedToAccount
                  ? null
                  : (selection) => _setKind(selection.first),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (effectiveKind == AccountFormKind.account) ...[
            AccountTypePicker(selected: _type, onSelected: _setType),
            if (_type == AccountType.card) ...[
              const SizedBox(height: 16),
              StatementDayPicker(
                selected: _statementDay,
                onSelected: (day) => setState(() => _statementDay = day),
              ),
            ],
            const SizedBox(height: 16),
            AmountField(
              controller: _balanceController,
              allowsNegative: true,
              hintText: 'Opening balance',
              onChanged: (_) => setState(() {}),
            ),
          ] else
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Account'),
              trailing: Text(_parentLabel() ?? 'Select'),
              onTap: _pickParent,
            ),
          ErrorSection(subject: 'account', error: _error),
        ],
      ),
    );
  }

  String? _parentLabel() {
    final id = _parentId;
    if (id == null) return null;
    return widget.ledger.state.sourceName(id);
  }
}
