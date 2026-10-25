import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/accounts/account_row.dart';
import 'package:spendwise/ui/accounts/account_sections.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/common/lists/summary_band.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/format/account_type_format.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

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
    final accountList = _AccountsList(
      viewState: viewState,
      viewModel: viewModel,
    );
    return accountList;
  }
}

class _AccountsList extends StatelessWidget {
  const _AccountsList({required this.viewState, required this.viewModel});

  final AccountsViewState viewState;
  final AccountsViewModel viewModel;

  static const _listPadding = EdgeInsets.all(14);
  static const _sectionGap = 10.0;
  static const _emptyTopPadding = 28.0;
  static const _emptyTextSize = 14.0;

  @override
  Widget build(BuildContext context) {
    final netWorth = viewState.netWorth;
    final summary = SummaryBand(
      leadLabel: 'Net worth',
      leadAmount: netWorth.asset - netWorth.liability,
      cells: [
        SummaryBandCell(label: 'Assets', amount: netWorth.asset),
        SummaryBandCell(label: 'Owed', amount: netWorth.liability),
      ],
    );
    final sections = [
      for (final section in viewState.sections)
        _AccountSection(
          section: section,
          expandedAccountID: viewState.expandedAccountId,
          viewModel: viewModel,
        ),
    ];
    final empty = viewState.sections.isEmpty
        ? Padding(
            padding: const EdgeInsets.only(top: _emptyTopPadding),
            child: Center(
              child: Text(
                'No accounts yet',
                style: TextStyle(
                  color: context.colors.subtext,
                  fontSize: _emptyTextSize,
                ),
              ),
            ),
          )
        : null;

    return ListView(
      padding: _listPadding,
      children: [
        summary,
        const SizedBox(height: _sectionGap),
        ...sections,
        ?empty,
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

  static const _sectionBottomSpacing = 10.0;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final row in section.rows)
        AccountRowTile(
          row: row,
          expanded: expandedAccountID == row.id,
          onToggleExpanded: row.pockets.isEmpty
              ? null
              : () => viewModel.toggleExpanded(row.id),
          onTap: () => viewModel.openAccount(row.id),
          onAccountDeleted: () => viewModel.deleteAccount(row.id),
          onAccountEdit: () => viewModel.requestSourceEdit(row.id),
          onOpenAccountAlone: () => viewModel.openAccountAlone(row.id),
          onOpenPocket: (pocket) => viewModel.openPocket(pocket.id),
          onPocketDeleted: (pocket) => viewModel.deletePocket(pocket.id),
          onPocketEdit: (pocket) => viewModel.requestSourceEdit(pocket.id),
        ),
    ];
    final header = _SectionHeader(section: section);
    return Padding(
      padding: const EdgeInsets.only(bottom: _sectionBottomSpacing),
      child: Tray(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [header, ...rows],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section});

  final AccountSection section;

  static const _headerAmountGap = 8.0;
  static const _headerBottomPadding = 6.0;
  static const _titleSize = 14.0;
  static const _titleWeight = FontWeight.w600;

  @override
  Widget build(BuildContext context) {
    final header = section.header;
    final trailing = switch (header) {
      SubtotalHeader(:final subtotal) => _SectionAmount(
        amount: formatMoney(subtotal, symbol: false),
        color: AmountStyle.of(context, signedValue: subtotal).color,
      ),
      CardHeader(:final payable, :final outstanding) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SectionAmount(
            amount: 'Payable ${formatMoney(payable, symbol: false)}',
            color: AmountStyle.of(context, kind: AmountKind.expense).color,
          ),
          const SizedBox(width: _headerAmountGap),
          _SectionAmount(
            amount: 'Outstanding ${formatMoney(outstanding, symbol: false)}',
            color: context.colors.subtext,
          ),
        ],
      ),
    };
    final title = Expanded(
      child: Text(
        accountTypeLabel(section.type),
        style: TextStyle(
          fontSize: _titleSize,
          fontWeight: _titleWeight,
          color: context.colors.text,
        ),
      ),
    );
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [title, trailing],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: _headerBottomPadding),
      child: row,
    );
  }
}

class _SectionAmount extends StatelessWidget {
  const _SectionAmount({required this.amount, required this.color});

  final String amount;
  final Color color;

  static const _amountSize = 10.0;

  @override
  Widget build(BuildContext context) => Text(
    amount,
    style: TextStyle(fontSize: _amountSize, color: color),
  );
}
