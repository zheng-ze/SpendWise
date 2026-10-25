import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/accounts/account_sections.dart';
import 'package:spendwise/ui/common/lists/swipe_row.dart';
import 'package:spendwise/ui/format/account_type_format.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - AccountRowTile
class AccountRowTile extends StatelessWidget {
  const AccountRowTile({
    super.key,
    required this.row,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onTap,
    required this.onAccountDeleted,
    required this.onAccountEdit,
    required this.onOpenAccountAlone,
    required this.onOpenPocket,
    required this.onPocketDeleted,
    required this.onPocketEdit,
  });

  final AccountRow row;
  final bool expanded;
  final VoidCallback? onToggleExpanded;
  final VoidCallback onTap;
  final VoidCallback onAccountDeleted;
  final VoidCallback onAccountEdit;
  final VoidCallback onOpenAccountAlone;
  final void Function(PocketRow pocket) onOpenPocket;
  final void Function(PocketRow pocket) onPocketDeleted;
  final void Function(PocketRow pocket) onPocketEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwipeRow(
          itemKey: ValueKey('account-${row.id}'),
          itemName: row.name,
          onDeleted: onAccountDeleted,
          onEdit: onAccountEdit,
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
            SwipeRow(
              itemKey: ValueKey('pocket-${pocket.id}'),
              itemName: pocket.name,
              onDeleted: () => onPocketDeleted(pocket),
              onEdit: () => onPocketEdit(pocket),
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

// MARK: - AccountRowBody
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

  static const _expandControlWidth = 40.0;
  static const _rowHorizontalPadding = 8.0;
  static const _rowVerticalPadding = 10.0;
  static const _medallionSize = 32.0;
  static const _medallionRadius = 9.0;
  static const _medallionIconSize = 18.0;
  static const _medallionTextGap = 10.0;
  static const _titleCaptionGap = 2.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final expandControl = SizedBox(
      width: _expandControlWidth,
      child: onToggleExpanded == null
          ? null
          : IconButton(
              icon: Icon(expanded ? Icons.expand_more : Icons.chevron_right),
              onPressed: onToggleExpanded,
            ),
    );
    final medallion = Container(
      width: _medallionSize,
      height: _medallionSize,
      decoration: BoxDecoration(
        color: context.colors.tint,
        borderRadius: BorderRadius.circular(_medallionRadius),
      ),
      alignment: Alignment.center,
      child: Icon(
        _accountIcon(row.type),
        size: _medallionIconSize,
        color: context.colors.action,
      ),
    );
    final title = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.name, style: theme.textTheme.bodyLarge),
          const SizedBox(height: _titleCaptionGap),
          Text(
            accountTypeLabel(row.type),
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.colors.subtext,
            ),
          ),
        ],
      ),
    );
    final amount = switch (row.amount) {
      SingleTotal(:final total) => Text(
        formatMoney(total, symbol: false),
        style: theme.textTheme.titleSmall?.copyWith(
          color: AmountStyle.of(context, signedValue: total).color,
        ),
      ),
      CardAmounts(:final payable, :final outstanding) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatMoney(payable, symbol: false),
            style: theme.textTheme.titleSmall?.copyWith(
              color: AmountStyle.of(context, kind: AmountKind.expense).color,
            ),
          ),
          Text(
            formatMoney(outstanding, symbol: false),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    };
    final rowContent = Row(
      children: [
        expandControl,
        medallion,
        const SizedBox(width: _medallionTextGap),
        title,
        amount,
      ],
    );
    final padded = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _rowHorizontalPadding,
        vertical: _rowVerticalPadding,
      ),
      child: rowContent,
    );

    return InkWell(onTap: onTap, child: padded);
  }

  IconData _accountIcon(AccountType type) => switch (type) {
    AccountType.cash => Icons.account_balance_wallet_outlined,
    AccountType.checking => Icons.account_balance_outlined,
    AccountType.savings => Icons.savings_outlined,
    AccountType.card => Icons.credit_card_outlined,
    AccountType.prepaid => Icons.payments_outlined,
    AccountType.investment => Icons.trending_up,
    AccountType.insurance => Icons.shield_outlined,
    AccountType.other => Icons.account_balance_wallet_outlined,
    AccountType.loan => Icons.request_quote_outlined,
    AccountType.overdraft => Icons.warning_amber_outlined,
  };
}

// MARK: - SubRow
class _SubRow extends StatelessWidget {
  const _SubRow({
    required this.title,
    required this.amount,
    required this.onTap,
  });

  final String title;
  final Decimal amount;
  final VoidCallback onTap;

  static const _subRowLeftInset = 48.0;
  static const _subRowEdgePadding = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _subRowLeftInset,
            _subRowEdgePadding,
            _subRowEdgePadding,
            _subRowEdgePadding,
          ),
          child: Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
              Text(
                formatMoney(amount, symbol: false),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AmountStyle.of(context, signedValue: amount).color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
