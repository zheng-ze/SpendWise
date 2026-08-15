import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/accounts/account_sections.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/money_format.dart';

class AccountRowTile extends StatelessWidget {
  const AccountRowTile({
    super.key,
    required this.row,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onTap,
    required this.confirmDeleteAccount,
    required this.onAccountDeleted,
    required this.onOpenAccountAlone,
    required this.onOpenPocket,
    required this.confirmDeletePocket,
    required this.onPocketDeleted,
  });

  final AccountRow row;
  final bool expanded;
  final VoidCallback? onToggleExpanded;
  final VoidCallback onTap;
  final Future<bool> Function() confirmDeleteAccount;
  final VoidCallback onAccountDeleted;
  final VoidCallback onOpenAccountAlone;
  final void Function(PocketRow pocket) onOpenPocket;
  final Future<bool> Function(PocketRow pocket) confirmDeletePocket;
  final void Function(PocketRow pocket) onPocketDeleted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Dismissible(
          key: ValueKey('account-${row.id}'),
          direction: DismissDirection.endToStart,
          background: const _DeleteBackground(),
          confirmDismiss: (_) => confirmDeleteAccount(),
          onDismissed: (_) => onAccountDeleted(),
          child: _AccountRowBody(
            row: row,
            expanded: expanded,
            onToggleExpanded: onToggleExpanded,
            onTap: onTap,
          ),
        ),
        if (expanded) ...[
          _SubRow(
            title: 'Excluding subpockets',
            amount: row.ownBalance,
            onTap: onOpenAccountAlone,
          ),
          for (final pocket in row.pockets)
            Dismissible(
              key: ValueKey('pocket-${pocket.id}'),
              direction: DismissDirection.endToStart,
              background: const _DeleteBackground(),
              confirmDismiss: (_) => confirmDeletePocket(pocket),
              onDismissed: (_) => onPocketDeleted(pocket),
              child: _SubRow(
                title: pocket.name,
                amount: pocket.balance,
                onTap: () => onOpenPocket(pocket),
              ),
            ),
        ],
      ],
    );
  }
}

class _AccountRowBody extends StatelessWidget {
  const _AccountRowBody({
    required this.row,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onTap,
  });

  final AccountRow row;
  final bool expanded;
  final VoidCallback? onToggleExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AmountColors.of(theme);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: onToggleExpanded == null
                  ? null
                  : IconButton(
                      icon: Icon(
                        expanded ? Icons.expand_more : Icons.chevron_right,
                      ),
                      onPressed: onToggleExpanded,
                    ),
            ),
            Expanded(child: Text(row.name, style: theme.textTheme.bodyLarge)),
            switch (row.amount) {
              SingleTotal(:final total) => Text(
                formatCurrency(total),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.netAmountColor(total),
                ),
              ),
              CardAmounts(:final payable, :final outstanding) => Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(payable),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.loss,
                    ),
                  ),
                  Text(
                    formatCurrency(outstanding),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow({
    required this.title,
    required this.amount,
    required this.onTap,
  });

  final String title;
  final Decimal amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AmountColors.of(theme);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 8, 8, 8),
          child: Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
              Text(
                formatCurrency(amount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.netAmountColor(amount),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.error,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }
}
