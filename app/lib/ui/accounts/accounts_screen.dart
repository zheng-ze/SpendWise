import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/account_form.dart';
import 'package:spendwise/ui/accounts/account_row.dart';
import 'package:spendwise/ui/accounts/account_sections.dart';
import 'package:spendwise/ui/accounts/delete_holder_confirmation.dart';
import 'package:spendwise/ui/common/column_text.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/daily_transactions_screen.dart';

const _typeLabels = {
  AccountType.cash: 'Cash',
  AccountType.checking: 'Checking',
  AccountType.savings: 'Savings',
  AccountType.card: 'Cards',
  AccountType.prepaid: 'Prepaid',
  AccountType.investment: 'Investment',
  AccountType.insurance: 'Insurance',
  AccountType.other: 'Other',
};

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: ledger,
      builder: (context, _) => _AccountsScreenBody(ledger: ledger),
    );
  }
}

class _AccountsScreenBody extends StatefulWidget {
  const _AccountsScreenBody({required this.ledger});

  final Ledger ledger;

  @override
  State<_AccountsScreenBody> createState() => _AccountsScreenBodyState();
}

class _AccountsScreenBodyState extends State<_AccountsScreenBody> {
  String? _expandedAccountID;

  void _toggleExpanded(String accountID) {
    setState(() {
      _expandedAccountID = _expandedAccountID == accountID ? null : accountID;
    });
  }

  void _openAccount(AccountRow row) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionsScreen(
          title: row.name,
          scopeIDs: {row.id, for (final pocket in row.pockets) pocket.id},
        ),
      ),
    );
  }

  void _openAccountAlone(AccountRow row) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionsScreen(title: row.name, scopeIDs: {row.id}),
      ),
    );
  }

  void _openPocket(PocketRow pocket) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            TransactionsScreen(title: pocket.name, scopeIDs: {pocket.id}),
      ),
    );
  }

  Future<bool> _confirmDeleteAccount(AccountRow row) {
    final referenceCount = widget.ledger.state.entriesReferencing(row.id);
    return showDeleteHolderConfirmation(
      context,
      name: row.name,
      referenceCount: referenceCount,
    );
  }

  void _accountDeleted(AccountRow row) {
    widget.ledger.deleteAccount(row.id);
    if (_expandedAccountID == row.id) {
      setState(() => _expandedAccountID = null);
    }
  }

  Future<bool> _confirmDeletePocket(PocketRow pocket) {
    final referenceCount = widget.ledger.state.entriesReferencing(pocket.id);
    return showDeleteHolderConfirmation(
      context,
      name: pocket.name,
      referenceCount: referenceCount,
    );
  }

  void _pocketDeleted(PocketRow pocket) =>
      widget.ledger.deletePocket(pocket.id);

  @override
  Widget build(BuildContext context) {
    final state = widget.ledger.state;
    final sections = accountSections(state, now: DateTime.now());
    final netWorth = Accounting.netWorth(state);
    final colors = AmountColors.of(Theme.of(context));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Accounts',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => showAccountFormSheet(
                      context: context,
                      ledger: widget.ledger,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ColumnText(
                items: [
                  ColumnTextItem(
                    caption: 'Assets',
                    value: formatCurrency(netWorth.asset),
                    valueColor: colors.gain,
                  ),
                  ColumnTextItem(
                    caption: 'Liabilities',
                    value: formatCurrency(netWorth.liability),
                    valueColor: colors.loss,
                  ),
                  ColumnTextItem(
                    caption: 'Total',
                    value: formatCurrency(netWorth.asset - netWorth.liability),
                    valueColor: colors.netAmountColor(
                      netWorth.asset - netWorth.liability,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: sections.isEmpty
                  ? const _EmptyState()
                  : ListView(
                      children: [
                        for (final section in sections)
                          _AccountSection(
                            section: section,
                            expandedAccountID: _expandedAccountID,
                            onToggleExpanded: _toggleExpanded,
                            onOpenAccount: _openAccount,
                            onOpenAccountAlone: _openAccountAlone,
                            onOpenPocket: _openPocket,
                            confirmDeleteAccount: _confirmDeleteAccount,
                            onAccountDeleted: _accountDeleted,
                            confirmDeletePocket: _confirmDeletePocket,
                            onPocketDeleted: _pocketDeleted,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.section,
    required this.expandedAccountID,
    required this.onToggleExpanded,
    required this.onOpenAccount,
    required this.onOpenAccountAlone,
    required this.onOpenPocket,
    required this.confirmDeleteAccount,
    required this.onAccountDeleted,
    required this.confirmDeletePocket,
    required this.onPocketDeleted,
  });

  final AccountSection section;
  final String? expandedAccountID;
  final void Function(String accountID) onToggleExpanded;
  final void Function(AccountRow row) onOpenAccount;
  final void Function(AccountRow row) onOpenAccountAlone;
  final void Function(PocketRow pocket) onOpenPocket;
  final Future<bool> Function(AccountRow row) confirmDeleteAccount;
  final void Function(AccountRow row) onAccountDeleted;
  final Future<bool> Function(PocketRow pocket) confirmDeletePocket;
  final void Function(PocketRow pocket) onPocketDeleted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeaderRow(type: section.type, header: section.header),
        for (final row in section.rows)
          AccountRowTile(
            row: row,
            expanded: expandedAccountID == row.id,
            onToggleExpanded: row.pockets.isEmpty
                ? null
                : () => onToggleExpanded(row.id),
            onTap: () => onOpenAccount(row),
            confirmDeleteAccount: () => confirmDeleteAccount(row),
            onAccountDeleted: () => onAccountDeleted(row),
            onOpenAccountAlone: () => onOpenAccountAlone(row),
            onOpenPocket: onOpenPocket,
            confirmDeletePocket: confirmDeletePocket,
            onPocketDeleted: onPocketDeleted,
          ),
      ],
    );
  }
}

class _SectionHeaderRow extends StatelessWidget {
  const _SectionHeaderRow({required this.type, required this.header});

  final AccountType type;
  final SectionHeader header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AmountColors.of(theme);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _typeLabels[type]!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          switch (header) {
            SubtotalHeader(:final subtotal) => Text(
              formatCurrency(subtotal),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.netAmountColor(subtotal),
              ),
            ),
            CardHeader(:final payable, :final outstanding) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Payable ${formatCurrency(payable)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.loss,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Outstanding ${formatCurrency(outstanding)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          },
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No accounts yet',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
