import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/month_year_selector.dart';
import 'package:spendwise/ui/common/top_tab_bar.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/stats/category_detail_screen.dart';
import 'package:spendwise/ui/stats/slices.dart';
import 'package:spendwise/ui/stats/stats_donut.dart';
import 'package:spendwise/ui/stats/stats_legend.dart';
import 'package:spendwise/ui/stats/stats_window.dart';

const _tabTitles = ['Income', 'Expense'];

enum StatsRangeMode { month, year }

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

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
        builder: (context, _) => _StatsScreenBody(ledger: ledger, cache: cache),
      ),
    );
  }
}

class _StatsScreenBody extends StatefulWidget {
  const _StatsScreenBody({required this.ledger, required this.cache});

  final Ledger ledger;
  final AnalysisCache cache;

  @override
  State<_StatsScreenBody> createState() => _StatsScreenBodyState();
}

class _StatsScreenBodyState extends State<_StatsScreenBody> {
  CategoryKind _kind = CategoryKind.expense;
  StatsRangeMode _range = StatsRangeMode.month;
  DateTime _selectedDate = DateTime.utc(
    DateTime.now().year,
    DateTime.now().month,
  );

  void _setKind(int tabIndex) {
    setState(() {
      _kind = tabIndex == 0 ? CategoryKind.income : CategoryKind.expense;
    });
  }

  void _setRange(StatsRangeMode range) {
    setState(() => _range = range);
  }

  void _onTapCategory(String mainID) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryDetailScreen(
          mainID: mainID,
          kind: _kind,
          isYearRange: _range == StatsRangeMode.year,
          initialDate: _selectedDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AmountColors.of(theme);
    final step = _range == StatsRangeMode.month
        ? MonthYearStep.month
        : MonthYearStep.year;
    final window = _range == StatsRangeMode.month
        ? monthWindow(_selectedDate)
        : yearWindow(_selectedDate);

    final categorySlices = slices(
      widget.cache.items,
      _kind,
      window,
      widget.ledger.state,
    );

    var total = Decimal.zero;
    for (final slice in categorySlices) {
      total += slice.amount;
    }

    final label = _kind == CategoryKind.income
        ? 'Total income'
        : 'Total expenses';
    final totalColor = _kind == CategoryKind.income ? colors.gain : colors.loss;

    return Scaffold(
      appBar: AppBar(
        title: MonthYearSelector(
          value: _selectedDate,
          step: step,
          onChanged: (value) => setState(() => _selectedDate = value),
        ),
        actions: [
          PopupMenuButton<StatsRangeMode>(
            onSelected: _setRange,
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
      ),
      body: SafeArea(
        child: Column(
          children: [
            TopTabBar(
              titles: _tabTitles,
              selectedIndex: _kind == CategoryKind.income ? 0 : 1,
              onSelected: _setKind,
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
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
                    _EmptyState(kind: _kind)
                  else ...[
                    StatsDonut(slices: categorySlices),
                    const Divider(height: 1),
                    StatsLegend(
                      slices: categorySlices,
                      onTapCategory: _onTapCategory,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
