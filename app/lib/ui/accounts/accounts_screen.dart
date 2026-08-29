import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/accounts/account_row.dart';
import 'package:spendwise/ui/accounts/account_sections.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/common/column_text.dart';
import 'package:spendwise/ui/format/account_type_format.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/money_format.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(accountsViewModelProvider);
    final viewModel = ref.watch(accountsViewModelProvider.notifier);

    return asyncState.when(
      data: (viewState) => Scaffold(
        body: SafeArea(
          child: _AccountsBody(viewState: viewState, viewModel: viewModel),
        ),
      ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('$error'))),
    );
  }
}

class _AccountsBody extends StatelessWidget {
  const _AccountsBody({required this.viewState, required this.viewModel});

  final AccountsViewState viewState;
  final AccountsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colors = AmountColors.of(Theme.of(context));
    final netWorth = viewState.netWorth;

    return Column(
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
                onPressed: viewModel.requestNewAccount,
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
          child: viewState.sections.isEmpty
              ? const _EmptyState()
              : ListView(
                  children: [
                    for (final section in viewState.sections)
                      _AccountSection(
                        section: section,
                        expandedAccountID: viewState.expandedAccountId,
                        viewModel: viewModel,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.section,
    required this.expandedAccountID,
    required this.viewModel,
  });

  final AccountSection section;
  final String? expandedAccountID;
  final AccountsViewModel viewModel;

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
                : () => viewModel.toggleExpanded(row.id),
            onTap: () => viewModel.openAccount(row.id),
            onAccountDeleted: () => viewModel.deleteAccount(row.id),
            onOpenAccountAlone: () => viewModel.openAccountAlone(row.id),
            onOpenPocket: (pocket) => viewModel.openPocket(pocket.id),
            onPocketDeleted: (pocket) => viewModel.deletePocket(pocket.id),
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
              accountTypeLabel(type),
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
