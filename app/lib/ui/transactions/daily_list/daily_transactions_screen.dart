import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/column_text.dart';
import 'package:spendwise/ui/common/expanding_fab.dart';
import 'package:spendwise/ui/common/month_year_selector.dart';
import 'package:spendwise/ui/common/swipe_to_delete_row.dart';
import 'package:spendwise/ui/common/top_tab_bar.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/daily_list/day_header.dart';
import 'package:spendwise/ui/transactions/daily_list/day_sections.dart';
import 'package:spendwise/ui/transactions/daily_list/empty_state.dart';
import 'package:spendwise/ui/transactions/monthly/monthly_transactions_view.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_cell.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

const _tabTitles = ['Daily', 'Monthly'];

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key, this.scope, this.onBackPressed});

  final TransactionsScope? scope;

  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const SizedBox.shrink();

    final async = ref.watch(transactionsViewModelProvider(scope));
    final viewModel = ref.read(transactionsViewModelProvider(scope).notifier);

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
      data: (state) => _TransactionsScreenBody(
        state: state,
        viewModel: viewModel,
        onBackPressed: onBackPressed,
      ),
    );
  }
}

class _TransactionsScreenBody extends StatelessWidget {
  const _TransactionsScreenBody({
    required this.state,
    required this.viewModel,
    this.onBackPressed,
  });

  final TransactionsViewState state;
  final TransactionsViewModel viewModel;
  final VoidCallback? onBackPressed;

  Widget _content(BuildContext context) {
    if (state.mode == TransactionsScreenMode.daily) {
      return _DailyContent(state: state, viewModel: viewModel);
    }
    return MonthlyTransactionsView(
      summaries: state.monthSummaries,
      onWeekTap: viewModel.switchToDaily,
    );
  }

  Widget _fab(BuildContext context) {
    return ExpandingFab(
      primary: FabAction(
        label: 'Add Transaction',
        icon: Icons.add,
        onTap: viewModel.requestNewEntry,
      ),
      secondary: !state.showEditSourceAction
          ? null
          : FabAction(
              label: 'Edit ${state.title}',
              icon: Icons.edit_outlined,
              onTap: viewModel.requestEditSource,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = state.mode == TransactionsScreenMode.daily
        ? MonthYearStep.month
        : MonthYearStep.year;

    return Scaffold(
      appBar: AppBar(
        leading: onBackPressed == null
            ? null
            : BackButton(onPressed: onBackPressed),
        title: Text(state.title),
        actions: [
          MonthYearSelector(
            value: state.selectedDate,
            step: step,
            onChanged: viewModel.setDate,
          ),
        ],
        centerTitle: false,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              TopTabBar(
                titles: _tabTitles,
                selectedIndex: state.mode.index,
                onSelected: (index) =>
                    viewModel.setMode(TransactionsScreenMode.values[index]),
              ),
              const Divider(height: 1),
              _TotalsBar(state: state),
              const Divider(height: 1),
              Expanded(child: _content(context)),
            ],
          ),
          _fab(context),
        ],
      ),
    );
  }
}

class _TotalsBar extends StatelessWidget {
  const _TotalsBar({required this.state});

  final TransactionsViewState state;

  @override
  Widget build(BuildContext context) {
    final colors = AmountColors.of(Theme.of(context));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ColumnText(
        items: [
          ColumnTextItem(
            caption: 'Income',
            value: formatCurrency(state.income),
            valueColor: colors.gain,
          ),
          ColumnTextItem(
            caption: 'Expenses',
            value: formatCurrency(state.expenses),
            valueColor: colors.loss,
          ),
          ColumnTextItem(
            caption: 'Total',
            value: formatCurrency(state.total),
            valueColor: colors.netAmountColor(state.total),
          ),
        ],
      ),
    );
  }
}

class _DailyContent extends StatelessWidget {
  const _DailyContent({required this.state, required this.viewModel});

  final TransactionsViewState state;
  final TransactionsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final sections = state.daySections;
    if (sections.isEmpty) return const TransactionsEmptyState();

    return CustomScrollView(
      slivers: [
        for (final section in sections)
          SliverMainAxisGroup(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: DayHeaderDelegate(
                  day: section.date,
                  net: section.income - section.expenses,
                ),
              ),
              _DaySliverList(section: section, viewModel: viewModel),
            ],
          ),
      ],
    );
  }
}

class _DaySliverList extends StatelessWidget {
  const _DaySliverList({required this.section, required this.viewModel});

  final DaySection section;
  final TransactionsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: section.rows.length,
      itemBuilder: (context, index) {
        final row = section.rows[index];
        final cell = TransactionCell(
          row: row,
          onTap: () => viewModel.openEntry(row.id),
        );

        return SwipeToDeleteRow(
          itemKey: ValueKey(row.id),
          itemName: row.title,
          onDeleted: () => viewModel.deleteEntry(row.id),
          child: cell,
        );
      },
    );
  }
}
