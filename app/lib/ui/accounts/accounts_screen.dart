import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/accounts/account_row.dart';
import 'package:spendwise/ui/accounts/account_sections.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/common/column_text.dart';
import 'package:spendwise/ui/format/account_type_format.dart';
import 'package:spendwise/ui/format/amount_style.dart';
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

  static const _headerLeftInset = 16.0;
  static const _headerEdgePadding = 8.0;
  static const _summaryHorizontalPadding = 16.0;
  static const _summarySectionsGap = 8.0;
  static const _dividerHeight = 1.0;

  @override
  Widget build(BuildContext context) {
    final netWorth = viewState.netWorth;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        _headerLeftInset,
        _headerEdgePadding,
        _headerEdgePadding,
        _headerEdgePadding,
      ),
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
    );
    final summary = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _summaryHorizontalPadding,
      ),
      child: ColumnText(
        items: [
          ColumnTextItem(
            caption: 'Assets',
            value: formatMoney(netWorth.asset),
            valueColor: AmountStyle.of(context, kind: AmountKind.income).color,
          ),
          ColumnTextItem(
            caption: 'Liabilities',
            value: formatMoney(netWorth.liability),
            valueColor: AmountStyle.of(context, kind: AmountKind.expense).color,
          ),
          ColumnTextItem(
            caption: 'Total',
            value: formatMoney(netWorth.asset - netWorth.liability),
            valueColor: AmountStyle.of(
              context,
              signedValue: netWorth.asset - netWorth.liability,
            ).color,
          ),
        ],
      ),
    );
    final sections = Expanded(
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
    );

    return Column(
      children: [
        header,
        summary,
        const SizedBox(height: _summarySectionsGap),
        const Divider(height: _dividerHeight),
        sections,
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

  static const _sectionHorizontalPadding = 16.0;
  static const _sectionTopPadding = 16.0;
  static const _sectionBottomPadding = 4.0;
  static const _headerAmountGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Expanded(
      child: Text(
        accountTypeLabel(type),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    final trailing = switch (header) {
      SubtotalHeader(:final subtotal) => Text(
        formatMoney(subtotal, symbol: false),
        style: theme.textTheme.labelLarge?.copyWith(
          color: AmountStyle.of(context, signedValue: subtotal).color,
        ),
      ),
      CardHeader(:final payable, :final outstanding) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Payable ${formatMoney(payable, symbol: false)}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AmountStyle.of(context, kind: AmountKind.expense).color,
            ),
          ),
          const SizedBox(width: _headerAmountGap),
          Text(
            'Outstanding ${formatMoney(outstanding, symbol: false)}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    };
    final row = Row(children: [title, trailing]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _sectionHorizontalPadding,
        _sectionTopPadding,
        _sectionHorizontalPadding,
        _sectionBottomPadding,
      ),
      child: row,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Center(child: Text('No accounts yet', style: style));
  }
}
