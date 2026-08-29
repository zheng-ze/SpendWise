import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/budgets/budgets_flow.dart';
import 'package:spendwise/ui/common/month_year_selector.dart';
import 'package:spendwise/ui/common/top_tab_bar.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/stats/stats_donut.dart';
import 'package:spendwise/ui/stats/stats_legend.dart';
import 'package:spendwise/ui/stats/stats_root_view_model.dart';
import 'package:spendwise/ui/stats/stats_window.dart';

const _tabTitles = ['Income', 'Expense', 'Budgets'];

class StatsRootScreen extends ConsumerWidget {
  const StatsRootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(statsRootViewModelProvider);
    final viewModel = ref.watch(statsRootViewModelProvider.notifier);
    final selectedDate = ref.watch(selectedMonthProvider);

    return asyncState.when(
      data: (viewState) => _StatsRootBody(
        viewState: viewState,
        viewModel: viewModel,
        selectedDate: selectedDate,
        onDateChanged: (value) =>
            ref.read(selectedMonthProvider.notifier).state = value,
      ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('$error'))),
    );
  }
}

class _StatsRootBody extends StatelessWidget {
  const _StatsRootBody({
    required this.viewState,
    required this.viewModel,
    required this.selectedDate,
    required this.onDateChanged,
  });

  final StatsRootViewState viewState;
  final StatsRootViewModel viewModel;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  void _setTab(int tabIndex) {
    viewModel.setTab(switch (tabIndex) {
      0 => StatsTab.income,
      1 => StatsTab.expense,
      _ => StatsTab.budgets,
    });
  }

  @override
  Widget build(BuildContext context) {
    final tab = viewState.tab;
    final range = viewState.range;

    return Scaffold(
      appBar: AppBar(
        title: MonthYearSelector(
          value: selectedDate,
          step: tab == StatsTab.budgets || range == StatsRangeMode.month
              ? MonthYearStep.month
              : MonthYearStep.year,
          onChanged: onDateChanged,
        ),
        actions: [
          if (tab != StatsTab.budgets)
            PopupMenuButton<StatsRangeMode>(
              onSelected: viewModel.setRange,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: StatsRangeMode.month,
                  child: Text('Monthly'),
                ),
                PopupMenuItem(
                  value: StatsRangeMode.year,
                  child: Text('Annually'),
                ),
              ],
            ),
        ],
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            TopTabBar(
              titles: _tabTitles,
              selectedIndex: tab.index,
              onSelected: _setTab,
            ),
            const Divider(height: 1),
            Expanded(
              child: tab == StatsTab.budgets
                  ? const BudgetsFlow()
                  : _AnalysisBody(
                      viewState: viewState,
                      viewModel: viewModel,
                      kind: tab == StatsTab.income
                          ? CategoryKind.income
                          : CategoryKind.expense,
                      window: range == StatsRangeMode.month
                          ? monthWindow(selectedDate)
                          : yearWindow(selectedDate),
                      isYearRange: range == StatsRangeMode.year,
                      selectedDate: selectedDate,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisBody extends StatelessWidget {
  const _AnalysisBody({
    required this.viewState,
    required this.viewModel,
    required this.kind,
    required this.window,
    required this.isYearRange,
    required this.selectedDate,
  });

  final StatsRootViewState viewState;
  final StatsRootViewModel viewModel;
  final CategoryKind kind;
  final DateRange window;
  final bool isYearRange;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AmountColors.of(theme);

    final categorySlices = statsSlices(viewState, kind, window);

    var total = Decimal.zero;
    for (final slice in categorySlices) {
      total += slice.amount;
    }

    final label = kind == CategoryKind.income
        ? 'Total income'
        : 'Total expenses';
    final totalColor = kind == CategoryKind.income ? colors.gain : colors.loss;

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: AmountHeader(
            caption: label,
            amount: total,
            amountColor: totalColor,
          ),
        ),
        if (categorySlices.isEmpty)
          _EmptyState(kind: kind)
        else ...[
          StatsDonut(slices: categorySlices),
          const Divider(height: 1),
          StatsLegend(
            slices: categorySlices,
            onTapCategory: (mainID) => viewModel.requestCategoryDetail(
              kind: kind,
              mainID: mainID,
              isYearRange: isYearRange,
              initialDate: selectedDate,
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.kind});

  final CategoryKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = kind == CategoryKind.income
        ? 'No income in this period'
        : 'No expense in this period';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
