import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/accounts/account_sections.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/common/feedback/delete_confirmation.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/format/account_type_format.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({
    super.key,
    required this.shouldClearSelectionOnPop,
  });

  final bool Function() shouldClearSelectionOnPop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountsViewModelProvider).value;
    final detail = state?.selectedDetail;
    if (detail == null) return const SizedBox.shrink();

    final viewModel = ref.read(accountsViewModelProvider.notifier);
    return PopScope<Object?>(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && shouldClearSelectionOnPop()) {
          viewModel.clearSelectedDetail();
        }
      },
      child: Scaffold(
        key: const ValueKey('account-detail-page'),
        body: SafeArea(
          child: AccountDetailPane(
            detail: detail,
            viewModel: viewModel,
            onClose: viewModel.clearSelectedDetail,
          ),
        ),
      ),
    );
  }
}

class AccountDetailPane extends StatelessWidget {
  const AccountDetailPane({
    super.key,
    required this.detail,
    required this.viewModel,
    required this.onClose,
  });

  final AccountDetail detail;
  final AccountsViewModel viewModel;
  final VoidCallback onClose;

  static const _pagePadding = EdgeInsets.all(14);
  static const _sectionGap = 12.0;

  String get _subtitle {
    final pocket = detail.pocket;
    if (pocket != null) return 'Pocket in ${detail.account.name}';
    return accountTypeLabel(detail.type);
  }

  @override
  Widget build(BuildContext context) {
    final heading = _DetailHeading(
      title: detail.title,
      subtitle: _subtitle,
      detail: detail,
      onClose: onClose,
      viewModel: viewModel,
    );
    final balance = _DetailBalance(balance: detail.balance);
    final navigation = _DetailNavigation(detail: detail, viewModel: viewModel);

    return SingleChildScrollView(
      padding: _pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          const SizedBox(height: _sectionGap),
          balance,
          const SizedBox(height: _sectionGap),
          navigation,
        ],
      ),
    );
  }
}

class _DetailHeading extends StatelessWidget {
  const _DetailHeading({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.onClose,
    required this.viewModel,
  });

  final String title;
  final String subtitle;
  final AccountDetail detail;
  final VoidCallback onClose;
  final AccountsViewModel viewModel;

  static const _headingGap = 8.0;
  static const _titleSize = 20.0;
  static const _titleLineHeight = 1.2;

  @override
  Widget build(BuildContext context) {
    final titleColumn = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            key: const ValueKey('account-detail-title'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: _titleSize, height: _titleLineHeight),
          ),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
    final heading = Row(
      children: [
        IconButton(
          tooltip: 'Back to accounts',
          icon: const Icon(Icons.arrow_back),
          onPressed: onClose,
        ),
        const SizedBox(width: _headingGap),
        titleColumn,
        _AccountDetailMenu(detail: detail, viewModel: viewModel),
      ],
    );

    return heading;
  }
}

class _DetailBalance extends StatelessWidget {
  const _DetailBalance({required this.balance});

  final Decimal balance;

  static const _labelSize = 12.0;
  static const _amountSize = 30.0;
  static const _labelAmountGap = 3.0;

  @override
  Widget build(BuildContext context) {
    final amount = Text(
      formatMoney(balance),
      style: context.text.hero.copyWith(
        fontSize: _amountSize,
        color: AmountStyle.of(context, signedValue: balance).color,
      ),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Balance',
          style: TextStyle(fontSize: _labelSize, color: context.colors.subtext),
        ),
        const SizedBox(height: _labelAmountGap),
        amount,
      ],
    );
    return Tray(child: content);
  }
}

class _DetailNavigation extends StatelessWidget {
  const _DetailNavigation({required this.detail, required this.viewModel});

  final AccountDetail detail;
  final AccountsViewModel viewModel;

  static const _choiceGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final pocket = detail.pocket;
    if (pocket != null) {
      return Tray(
        title: 'Entries',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ScopeAction(
              label: 'View entries',
              onPressed: () => viewModel.openPocket(pocket.id),
            ),
            _ScopeAction(
              label: 'Back to ${detail.account.name}',
              onPressed: () => viewModel.selectDetail(detail.account.id),
            ),
          ],
        ),
      );
    }

    final scopeActions = <Widget>[
      _ScopeAction(
        label: 'All balances',
        onPressed: () => viewModel.openAccount(detail.account.id),
      ),
      _ScopeAction(
        label: 'Own balance',
        onPressed: () => viewModel.openAccountAlone(detail.account.id),
      ),
      for (final accountPocket in detail.account.pockets)
        _ScopeAction(
          label: accountPocket.name,
          onPressed: () => viewModel.openPocket(accountPocket.id),
        ),
    ];
    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final action in scopeActions) ...[
          action,
          if (action != scopeActions.last) const SizedBox(height: _choiceGap),
        ],
        if (detail.account.pockets.isNotEmpty)
          TextButton(
            onPressed: () => viewModel.toggleAccountPockets(detail.account.id),
            child: const Text('Manage pockets'),
          ),
      ],
    );

    return Tray(title: 'Entries', child: actions);
  }
}

class _ScopeAction extends StatelessWidget {
  const _ScopeAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    key: ValueKey('account-scope-$label'),
    onPressed: onPressed,
    child: Align(alignment: Alignment.centerLeft, child: Text(label)),
  );
}

enum _AccountMenuAction { fixBalance, edit, delete }

class _AccountDetailMenu extends StatelessWidget {
  const _AccountDetailMenu({required this.detail, required this.viewModel});

  final AccountDetail detail;
  final AccountsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isPocket = detail.pocket != null;
    return PopupMenuButton<_AccountMenuAction>(
      tooltip: 'Account actions',
      icon: const Icon(Icons.more_horiz),
      onSelected: (action) => _handleAction(context, action),
      itemBuilder: (context) => [
        if (!isPocket)
          const PopupMenuItem(
            value: _AccountMenuAction.fixBalance,
            child: Text('Fix balance'),
          ),
        PopupMenuItem(
          value: _AccountMenuAction.edit,
          child: Text(isPocket ? 'Edit pocket' : 'Edit account'),
        ),
        PopupMenuItem(
          value: _AccountMenuAction.delete,
          child: const Text('Move to recycle bin'),
        ),
      ],
    );
  }

  void _handleAction(BuildContext context, _AccountMenuAction action) {
    final holderId = detail.pocket?.id ?? detail.account.id;
    switch (action) {
      case _AccountMenuAction.fixBalance:
      case _AccountMenuAction.edit:
        viewModel.requestSourceEdit(holderId);
      case _AccountMenuAction.delete:
        _confirmDelete(context);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDeleteConfirmation(
      context,
      itemName: detail.title,
    );
    if (!context.mounted || !confirmed) return;

    final pocket = detail.pocket;
    if (pocket == null) {
      await viewModel.deleteAccount(detail.account.id);
    } else {
      await viewModel.deletePocket(pocket.id);
    }
    viewModel.clearSelectedDetail();
  }
}
