import 'package:domain/domain.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/common/day_sectioned_entry_list.dart';
import 'package:spendwise/ui/common/month_year_selector.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/budgets/helpers/budget_spend.dart';
import 'package:spendwise/ui/stats/helpers/chart_helpers.dart';
import 'package:spendwise/ui/stats/helpers/stats_window.dart';

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

class _BudgetDetailBody extends StatelessWidget {
  const _BudgetDetailBody({
    required this.viewState,
    required this.viewModel,
    required this.ledger,
  });

  final BudgetDetailViewState viewState;
  final BudgetDetailViewModel viewModel;
  final Ledger ledger;

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
      height: 220,
      child: _BudgetChart(
        months: viewState.months,
        spend: viewState.spendSeries,
        limit: viewState.limitSeries,
        maxY: viewState.chartMaxYValue,
        selectedMonth: viewState.selectedMonth,
        onSelectMonth: viewModel.selectMonth,
        barColor: AmountColors.of(Theme.of(context)).loss,
      ),
    );
    final entriesLabel = _BudgetDetailEntriesLabel(
      selectedMonth: viewState.selectedMonth,
    );
    final bucketIDs = viewState.scopedBucketIDs;
    final entryList = DaySectionedEntryList(
      ledger: ledger,
      state: viewState.ledgerState,
      window: viewState.selectedMonthWindow,
      // budgetSpend (budget_spend.dart) also counts synthetic
      // transfer-expense items for an overall budget; this list can't, since
      // those items have no backing Entry to show as a row.
      matching: () => viewState.ledgerState.entries.values.where((entry) {
        if (entry.isTransfer) return false;
        if (entry.expectedCategoryKind != CategoryKind.expense) return false;
        if (!Accounting.includedInAnalysis(entry, viewState.ledgerState)) {
          return false;
        }
        if (bucketIDs == null) return true;
        return entry.categoryID != null && bucketIDs.contains(entry.categoryID);
      }),
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

class _BudgetDetailAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _BudgetDetailAppBar({required this.title, required this.viewModel});

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
          tooltip: 'Edit limit history',
          onPressed: viewModel.requestLimitEdit,
        ),
      ],
    );
  }
}

class _BudgetDetailHeader extends StatelessWidget {
  const _BudgetDetailHeader({required this.budget, required this.viewState});

  final Budget budget;
  final BudgetDetailViewState viewState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AmountColors.of(theme);

    final selectedMonth = viewState.selectedYearMonth;
    final limit = effectiveLimit(budget, selectedMonth);
    final spend = budgetSpend(
      budget,
      selectedMonth,
      viewState.items,
      viewState.ledgerState,
    );
    final overLimit = spend > limit;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: AmountHeader(
        caption: '${formatCurrency(spend)} of ${formatCurrency(limit)}',
        amount: limit - spend,
        amountColor: overLimit ? colors.loss : theme.colorScheme.onSurface,
      ),
    );
  }
}

class _BudgetDetailEntriesLabel extends StatelessWidget {
  const _BudgetDetailEntriesLabel({required this.selectedMonth});

  final DateTime selectedMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        '${formatMonthLabel(selectedMonth).toUpperCase()} ENTRIES',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _BudgetChart extends StatelessWidget {
  const _BudgetChart({
    required this.months,
    required this.spend,
    required this.limit,
    required this.maxY,
    required this.selectedMonth,
    required this.onSelectMonth,
    required this.barColor,
  });

  final List<DateTime> months;
  final List<Decimal> spend;
  final List<Decimal> limit;
  final double maxY;
  final DateTime selectedMonth;
  final void Function(DateTime month) onSelectMonth;
  final Color barColor;

  int get _selectedIndex => months.indexWhere(
    (month) =>
        month.year == selectedMonth.year && month.month == selectedMonth.month,
  );

  Widget _spendBars(BuildContext context) {
    final selectedIndex = _selectedIndex;

    final titlesData = FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: const AxisTitles(),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          getTitlesWidget: (value, meta) => monthAxisTick(
            Theme.of(context).textTheme.labelSmall,
            months,
            value,
          ),
        ),
      ),
    );

    final barGroups = [
      for (var i = 0; i < months.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: spend[i].toDouble(),
              color: i == selectedIndex
                  ? barColor
                  : barColor.withValues(alpha: 0.5),
              width: 18,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
    ];

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: titlesData,
        barTouchData: BarTouchData(enabled: false),
        barGroups: barGroups,
      ),
    );
  }

  Widget _limitLine(BuildContext context) {
    final theme = Theme.of(context);

    final lineBarsData = [
      LineChartBarData(
        spots: [
          for (var i = 0; i < months.length; i++)
            FlSpot(i.toDouble(), limit[i].toDouble()),
        ],
        isCurved: false,
        color: theme.colorScheme.onSurface,
        barWidth: 2,
        dotData: FlDotData(
          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
            radius: 3,
            color: theme.colorScheme.onSurface,
            strokeWidth: 0,
          ),
        ),
        belowBarData: BarAreaData(show: false),
      ),
    ];

    return IgnorePointer(
      child: LineChart(
        LineChartData(
          minX: -0.5,
          maxX: months.length - 0.5,
          minY: 0,
          maxY: maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: lineBarsData,
        ),
      ),
    );
  }

  Widget _tapOverlay() {
    return Row(
      children: [
        for (var i = 0; i < months.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => onSelectMonth(months[i]),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Stack(
        children: [_spendBars(context), _limitLine(context), _tapOverlay()],
      ),
    );
  }
}
