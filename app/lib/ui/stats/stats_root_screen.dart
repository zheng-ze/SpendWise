import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/common/month_year_selector.dart';
import 'package:spendwise/ui/common/top_tab_bar.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/stats/analysis/analysis_flow.dart';
import 'package:spendwise/ui/stats/stats_root_view_model.dart';
import 'package:spendwise/ui/stats/helpers/stats_window.dart';

const _tabTitles = ['Income', 'Expense', 'Budgets'];

class StatsRootScreen extends ConsumerWidget {
  const StatsRootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(statsRootViewModelProvider);
    final viewModel = ref.watch(statsRootViewModelProvider.notifier);
    final selectedDate = ref.watch(selectedMonthProvider);

    return _StatsRootBody(
      viewState: viewState,
      viewModel: viewModel,
      selectedDate: selectedDate,
      onDateChanged: (value) =>
          ref.read(selectedMonthProvider.notifier).state = value,
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
            Expanded(child: _buildTabContent(tab, range)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(StatsTab tab, StatsRangeMode range) {
    if (tab == StatsTab.budgets) {
      return const BudgetsFlow();
    }

    final kind = tab == StatsTab.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final isYearRange = range == StatsRangeMode.year;

    return AnalysisFlow(
      key: ValueKey(kind),
      kind: kind,
      window: isYearRange
          ? yearWindow(selectedDate)
          : monthWindow(selectedDate),
      isYearRange: isYearRange,
      selectedDate: selectedDate,
    );
  }
}
