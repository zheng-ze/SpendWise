import 'package:domain/domain.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_limit_screen.dart';
import 'package:spendwise/ui/common/day_sectioned_entry_list.dart';
import 'package:spendwise/ui/common/month_year_selector.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/budget_spend.dart';
import 'package:spendwise/ui/stats/chart_helpers.dart';
import 'package:spendwise/ui/stats/stats_window.dart';
import 'package:spendwise/ui/stats/trend.dart';

class BudgetDetailScreen extends ConsumerWidget {
  const BudgetDetailScreen({super.key, required this.budget});

  final Budget budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    final cache = ref.watch(analysisCacheProvider);
    if (ledger == null) return const SizedBox.shrink();

    cache.refresh(ledger.state);

    return ListenableBuilder(
      listenable: ledger,
      builder: (context, _) => ListenableBuilder(
        listenable: cache,
        builder: (context, _) => _BudgetDetailBody(
          budgetID: budget.id,
          ledger: ledger,
          cache: cache,
        ),
      ),
    );
  }
}

class _BudgetDetailBody extends StatefulWidget {
  const _BudgetDetailBody({
    required this.budgetID,
    required this.ledger,
    required this.cache,
  });

  final String budgetID;
  final Ledger ledger;
  final AnalysisCache cache;

  @override
  State<_BudgetDetailBody> createState() => _BudgetDetailBodyState();
}

class _BudgetDetailBodyState extends State<_BudgetDetailBody> {
  late DateTime _displayedYear = DateTime.utc(DateTime.now().toUtc().year);
  late DateTime _selectedMonth = DateTime.utc(
    DateTime.now().toUtc().year,
    DateTime.now().toUtc().month,
  );

  void _selectMonth(DateTime month) => setState(() => _selectedMonth = month);

  void _changeYear(DateTime year) => setState(() {
    _displayedYear = DateTime.utc(year.year);
    _selectedMonth = DateTime.utc(year.year, _selectedMonth.month);
  });

  @override
  Widget build(BuildContext context) {
    final state = widget.ledger.state;

    final budget = state.budgets[widget.budgetID];
    if (budget == null) {
      return const Scaffold(body: Center(child: Text('Budget deleted')));
    }

    final months = trendMonths(_displayedYear, isYearRange: true);
    final selectedYearMonth = YearMonth(
      _selectedMonth.year,
      _selectedMonth.month,
    );

    final header = _BudgetDetailHeader(
      budget: budget,
      state: state,
      items: widget.cache.items,
      selectedMonth: selectedYearMonth,
    );
    final yearSelector = Center(
      child: MonthYearSelector(
        value: _displayedYear,
        step: MonthYearStep.year,
        onChanged: _changeYear,
      ),
    );
    final chart = _MonthChart(
      budget: budget,
      state: state,
      items: widget.cache.items,
      months: months,
      selectedMonth: _selectedMonth,
      onSelectMonth: _selectMonth,
    );
    final entriesLabel = _BudgetDetailEntriesLabel(
      selectedMonth: _selectedMonth,
    );
    final bucketIDs = budgetBucketIDs(budget, state);
    final entryList = DaySectionedEntryList(
      ledger: widget.ledger,
      state: state,
      window: monthWindow(_selectedMonth),
      // budgetSpend (budget_spend.dart) also counts synthetic
      // transfer-expense items for an overall budget; this list can't, since
      // those items have no backing Entry to show as a row.
      matching: () => state.entries.values.where((entry) {
        if (entry.isTransfer) return false;
        if (entry.expectedCategoryKind != CategoryKind.expense) return false;
        if (!Accounting.includedInAnalysis(entry, state)) return false;
        if (bucketIDs == null) return true;
        return entry.categoryID != null && bucketIDs.contains(entry.categoryID);
      }),
    );

    return Scaffold(
      appBar: _BudgetDetailAppBar(ledger: widget.ledger, budget: budget),
      body: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          children: [header, yearSelector, chart, entriesLabel, entryList],
        ),
      ),
    );
  }
}

List<T> _monthSeries<T>(
  List<DateTime> months,
  T Function(YearMonth month) forMonth,
) => [for (final month in months) forMonth(YearMonth(month.year, month.month))];

class _MonthChart extends StatelessWidget {
  const _MonthChart({
    required this.budget,
    required this.state,
    required this.items,
    required this.months,
    required this.selectedMonth,
    required this.onSelectMonth,
  });

  final Budget budget;
  final LedgerState state;
  final List<AnalysisItem> items;
  final List<DateTime> months;
  final DateTime selectedMonth;
  final void Function(DateTime month) onSelectMonth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: _BudgetChart(
        months: months,
        spend: _monthSeries(
          months,
          (month) => budgetSpend(budget, month, items, state),
        ),
        limit: _monthSeries(months, (month) => effectiveLimit(budget, month)),
        selectedMonth: selectedMonth,
        onSelectMonth: onSelectMonth,
        barColor: AmountColors.of(Theme.of(context)).loss,
      ),
    );
  }
}

class _BudgetDetailAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _BudgetDetailAppBar({required this.ledger, required this.budget});

  final Ledger ledger;
  final Budget budget;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final state = ledger.state;
    final title = budget.categoryID == null
        ? 'Overall'
        : state.categories[budget.categoryID]?.name ?? '(category deleted)';

    return AppBar(
      title: Text(title),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit limit history',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  BudgetLimitScreen(ledger: ledger, budgetID: budget.id),
            ),
          ),
        ),
      ],
    );
  }
}

class _BudgetDetailHeader extends StatelessWidget {
  const _BudgetDetailHeader({
    required this.budget,
    required this.state,
    required this.items,
    required this.selectedMonth,
  });

  final Budget budget;
  final LedgerState state;
  final List<AnalysisItem> items;
  final YearMonth selectedMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AmountColors.of(theme);

    final limit = effectiveLimit(budget, selectedMonth);
    final spend = budgetSpend(budget, selectedMonth, items, state);
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
    required this.selectedMonth,
    required this.onSelectMonth,
    required this.barColor,
  });

  final List<DateTime> months;
  final List<Decimal> spend;
  final List<Decimal> limit;
  final DateTime selectedMonth;
  final void Function(DateTime month) onSelectMonth;
  final Color barColor;

  double get _maxY {
    final maxAmount = [
      ...spend,
      ...limit,
    ].fold(Decimal.zero, (max, amount) => amount > max ? amount : max);
    return maxAmount > Decimal.one ? maxAmount.toDouble() * 1.15 : 1.0;
  }

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
        maxY: _maxY,
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
          maxY: _maxY,
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
