import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis/budgets/budget_counted_entries.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_counted_entry_list.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_chart.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/common/inputs/month_year_selector.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/helpers/amount_header.dart';

// MARK: - Screen

class BudgetDetailScreen extends ConsumerWidget {
  const BudgetDetailScreen({super.key, required this.budgetID});

  final String budgetID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(budgetDetailViewModelProvider(budgetID));
    final ledger = ref.watch(ledgerProvider);

    return asyncState.when(
      data: (viewState) => ledger == null
          ? const SizedBox.shrink()
          : _BudgetDetailBody(
              viewState: viewState,
              viewModel: ref.read(
                budgetDetailViewModelProvider(budgetID).notifier,
              ),
              ledger: ledger,
            ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('$error'))),
    );
  }
}

// MARK: - Body

class _BudgetDetailBody extends StatelessWidget {
  const _BudgetDetailBody({
    required this.viewState,
    required this.viewModel,
    required this.ledger,
  });

  final BudgetDetailViewState viewState;
  final BudgetDetailViewModel viewModel;
  final Ledger ledger;

  static const _chartHeight = 220.0;

  @override
  Widget build(BuildContext context) {
    final budget = viewState.budget;
    if (budget == null) {
      return const Scaffold(body: Center(child: Text('Budget deleted')));
    }

    final header = _BudgetDetailHeader(budget: budget, viewState: viewState);
    final yearSelector = Center(
      child: MonthYearSelector(
        value: viewState.displayedYear,
        step: MonthYearStep.year,
        onChanged: viewModel.changeYear,
      ),
    );
    final chart = SizedBox(
      height: _chartHeight,
      child: BudgetDetailChart(
        months: viewState.months,
        spend: viewState.spendSeries,
        limit: viewState.limitSeries,
        maxY: viewState.chartMaxYValue,
        selectedMonth: viewState.selectedMonth,
        onSelectMonth: viewModel.selectMonth,
        barColor: AmountStyle.of(context, kind: AmountKind.expense).color,
      ),
    );
    final entriesLabel = _BudgetDetailEntriesLabel(
      selectedMonth: viewState.selectedMonth,
    );
    final entryList = BudgetCountedEntryList(
      ledger: ledger,
      state: viewState.ledgerState,
      counted: viewState.countedEntries,
    );

    return Scaffold(
      appBar: _BudgetDetailAppBar(title: viewState.title, viewModel: viewModel),
      body: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          children: [header, yearSelector, chart, entriesLabel, entryList],
        ),
      ),
    );
  }
}

// MARK: - App Bar

class _BudgetDetailAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _BudgetDetailAppBar({required this.title, required this.viewModel});

  static const _editTooltip = 'Edit limit history';

  final String title;
  final BudgetDetailViewModel viewModel;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: _editTooltip,
          onPressed: viewModel.requestLimitEdit,
        ),
      ],
    );
  }
}

// MARK: - Header

class _BudgetDetailHeader extends StatelessWidget {
  const _BudgetDetailHeader({required this.budget, required this.viewState});

  final Budget budget;
  final BudgetDetailViewState viewState;

  static const _headerPadding = EdgeInsets.all(16);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final selectedMonth = viewState.selectedYearMonth;
    final limit = effectiveLimit(budget, selectedMonth);
    final spend = budgetCountedTotal(viewState.countedEntries);
    final overLimit = spend > limit;

    return Padding(
      padding: _headerPadding,
      child: AmountHeader(
        caption: '${formatMoney(spend)} of ${formatMoney(limit)}',
        amount: limit - spend,
        amountColor: overLimit
            ? AmountStyle.of(context, kind: AmountKind.expense).color
            : theme.colorScheme.onSurface,
      ),
    );
  }
}

// MARK: - Entries Label

class _BudgetDetailEntriesLabel extends StatelessWidget {
  const _BudgetDetailEntriesLabel({required this.selectedMonth});

  final DateTime selectedMonth;

  static const _labelPadding = EdgeInsets.fromLTRB(16, 24, 16, 8);

  static const _entriesSuffix = ' ENTRIES';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: _labelPadding,
      child: Text(
        '${formatMonthLabel(selectedMonth).toUpperCase()}$_entriesSuffix',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
