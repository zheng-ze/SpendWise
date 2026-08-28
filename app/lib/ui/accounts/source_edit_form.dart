import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/account_type_picker.dart';
import 'package:spendwise/ui/accounts/source_edit_form_logic.dart';
import 'package:spendwise/ui/accounts/statement_day_picker.dart';
import 'package:spendwise/ui/common/amount_field.dart';
import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/form_scaffold.dart';
import 'package:spendwise/ui/format/amount_parse.dart';
import 'package:spendwise/ui/format/money_format.dart';

/// Opens the edit sheet for an existing account or subpocket, reached from
/// the scoped transactions screen's action button.
Future<void> showSourceEditFormSheet({
  required BuildContext context,
  required Ledger ledger,
  required String holderID,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => SourceEditForm(ledger: ledger, holderID: holderID),
  );
}

class SourceEditForm extends StatefulWidget {
  const SourceEditForm({
    super.key,
    required this.ledger,
    required this.holderID,
  });

  final Ledger ledger;
  final String holderID;

  @override
  State<SourceEditForm> createState() => _SourceEditFormState();
}

class _SourceEditFormState extends State<SourceEditForm> {
  late final Account? _account =
      widget.ledger.state.moneySources[widget.holderID]?.asAccount;
  late final SubPocket? _pocket = _account == null
      ? widget.ledger.state.moneySources[widget.holderID]?.asPocket
      : null;

  late final TextEditingController _nameController = TextEditingController(
    text: _account?.name ?? _pocket?.name ?? '',
  );
  late final TextEditingController _balanceController = TextEditingController(
    text: formatPlainAmount(_currentBalance),
  );

  late AccountType _type = _account?.type ?? AccountType.cash;
  late int? _statementDay = _account?.statementDay;
  late bool _incomingTransfersAsExpenses =
      _account?.incomingTransfersAsExpenses ??
      _pocket?.incomingTransfersAsExpenses ??
      false;
  late bool _includeInNetWorth = _account?.includeInNetWorth ?? true;

  LedgerError? _error;

  bool get _isAccount => _account != null;

  // A pocket has no type of its own, so its eligibility follows whichever
  // account holds it.
  AccountType? get _eligibleType {
    if (_isAccount) return _type;
    return widget.ledger.state.owningAccount(widget.holderID)?.type;
  }

  bool get _showsTransferToggle =>
      _eligibleType?.allowsTransfersAsExpense ?? false;

  Decimal get _currentBalance {
    final state = widget.ledger.state;
    return Accounting.balance(
      of: widget.holderID,
      entries: state.entries.values.toList(),
      sourceIDs: state.moneySources.keys.toSet(),
    );
  }

  Decimal? get _parsedBalance => parseAmountInput(_balanceController.text);

  bool get _canSave => canSaveSourceEditForm(
    name: _nameController.text,
    balance: _parsedBalance,
  );

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _setType(AccountType type) {
    setState(() {
      _type = type;
      if (type != AccountType.card) _statementDay = null;
      if (!type.allowsTransfersAsExpense) _incomingTransfersAsExpenses = false;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final enteredBalance = _parsedBalance ?? Decimal.zero;

    try {
      final account = _account;
      final pocket = _pocket;
      if (account != null) {
        widget.ledger.updateAccount(
          Account(
            id: account.id,
            name: name,
            type: _type,
            statementDay: _type == AccountType.card ? _statementDay : null,
            incomingTransfersAsExpenses: _incomingTransfersAsExpenses,
            includeInNetWorth: _includeInNetWorth,
            lifecycle: account.lifecycle,
          ),
        );
      } else if (pocket != null) {
        widget.ledger.updatePocket(
          SubPocket(
            id: pocket.id,
            name: name,
            incomingTransfersAsExpenses: _incomingTransfersAsExpenses,
            lifecycle: pocket.lifecycle,
          ),
        );
      }

      final adjustment = balanceAdjustmentEntry(
        enteredBalance: enteredBalance,
        currentBalance: _currentBalance,
        holderID: widget.holderID,
      );
      if (adjustment != null) widget.ledger.addEntry(adjustment);

      if (!mounted) return;
      Navigator.of(context).pop();
    } on LedgerError catch (error) {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: _isAccount ? 'Edit Account' : 'Edit Subpocket',
      canSave: _canSave,
      onSave: _save,
      error: ErrorSection(subject: 'account', error: _error),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Name'),
            onChanged: (_) => setState(() {}),
          ),
          if (_isAccount) ...[
            const SizedBox(height: 16),
            AccountTypePicker(selected: _type, onSelected: _setType),
            if (_type == AccountType.card) ...[
              const SizedBox(height: 16),
              StatementDayPicker(
                selected: _statementDay,
                onSelected: (day) => setState(() => _statementDay = day),
              ),
            ],
          ],
          const SizedBox(height: 16),
          AmountField(
            controller: _balanceController,
            allowsNegative: true,
            hintText: 'Balance',
            onChanged: (_) => setState(() {}),
          ),
          if (_showsTransferToggle) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Transfers in count as expenses'),
              subtitle: const Text(
                'When on, money transferred into this holder is treated as '
                'spending in analysis.',
              ),
              value: _incomingTransfersAsExpenses,
              onChanged: (value) =>
                  setState(() => _incomingTransfersAsExpenses = value),
            ),
          ],
          if (_isAccount)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include in net worth'),
              value: _includeInNetWorth,
              onChanged: (value) => setState(() => _includeInNetWorth = value),
            ),
        ],
      ),
    );
  }
}
