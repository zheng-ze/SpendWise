import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_card.dart';
import 'package:spendwise/ui/budgets/budget_detail_screen.dart';
import 'package:spendwise/ui/budgets/budget_form.dart';
import 'package:spendwise/ui/common/expanding_fab.dart';
import 'package:spendwise/ui/common/month_year_selector.dart';
import 'package:spendwise/ui/common/top_tab_bar.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/stats/category_detail_screen.dart';
import 'package:spendwise/ui/stats/slices.dart';
import 'package:spendwise/ui/stats/stats_donut.dart';
import 'package:spendwise/ui/stats/stats_legend.dart';
import 'package:spendwise/ui/stats/stats_window.dart';

const _tabTitles = ['Income', 'Expense', 'Budgets'];

enum StatsRangeMode { month, year }

enum _StatsTab { income, expense, budgets }

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

class _StatsScreenBody extends ConsumerStatefulWidget {
  const _StatsScreenBody({required this.ledger, required this.cache});

  final Ledger ledger;
  final AnalysisCache cache;

  @override
  ConsumerState<_StatsScreenBody> createState() => _StatsScreenBodyState();
}

class _StatsScreenBodyState extends ConsumerState<_StatsScreenBody> {
  _StatsTab _tab = _StatsTab.expense;
  StatsRangeMode _range = StatsRangeMode.month;

  void _setTab(int tabIndex) {
    setState(() {
      _tab = switch (tabIndex) {
        0 => _StatsTab.income,
        1 => _StatsTab.expense,
        _ => _StatsTab.budgets,
      };
    });
  }

  void _setRange(StatsRangeMode range) {
    setState(() => _range = range);
  }

  void _onTapCategory(CategoryKind kind, String mainID) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryDetailScreen(
          mainID: mainID,
          kind: kind,
          isYearRange: _range == StatsRangeMode.year,
          initialDate: ref.read(selectedMonthProvider),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedMonthProvider);

    return Scaffold(
      appBar: AppBar(
        title: MonthYearSelector(
          value: selectedDate,
          step: _tab == _StatsTab.budgets || _range == StatsRangeMode.month
              ? MonthYearStep.month
              : MonthYearStep.year,
          onChanged: (value) =>
              ref.read(selectedMonthProvider.notifier).state = value,
        ),
        actions: [
          if (_tab != _StatsTab.budgets)
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
        centerTitle: false,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                TopTabBar(
                  titles: _tabTitles,
                  selectedIndex: _tab.index,
                  onSelected: _setTab,
                ),
                const Divider(height: 1),
                Expanded(
                  child: _tab == _StatsTab.budgets
                      ? _BudgetsBody(
                          ledger: widget.ledger,
                          items: widget.cache.items,
                          month: YearMonth.fromUtc(selectedDate),
                        )
                      : _AnalysisBody(
                          ledger: widget.ledger,
                          items: widget.cache.items,
                          kind: _tab == _StatsTab.income
                              ? CategoryKind.income
                              : CategoryKind.expense,
                          window: _range == StatsRangeMode.month
                              ? monthWindow(selectedDate)
                              : yearWindow(selectedDate),
                          onTapCategory: _onTapCategory,
                        ),
                ),
              ],
            ),
            if (_tab == _StatsTab.budgets)
              ExpandingFab(
                primary: FabAction(
                  label: 'Add Budget',
                  icon: Icons.add,
                  onTap: () => showBudgetFormSheet(
                    context: context,
                    ledger: widget.ledger,
                  ),
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
    required this.ledger,
    required this.items,
    required this.kind,
    required this.window,
    required this.onTapCategory,
  });

  final Ledger ledger;
  final List<AnalysisItem> items;
  final CategoryKind kind;
  final DateRange window;
  final void Function(CategoryKind kind, String mainID) onTapCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AmountColors.of(theme);

    final categorySlices = slices(items, kind, window, ledger.state);

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
            onTapCategory: (mainID) => onTapCategory(kind, mainID),
          ),
        ],
      ],
    );
  }
}

class _BudgetsBody extends StatelessWidget {
  const _BudgetsBody({
    required this.ledger,
    required this.items,
    required this.month,
  });

  final Ledger ledger;
  final List<AnalysisItem> items;
  final YearMonth month;

  @override
  Widget build(BuildContext context) {
    /// Groups a subcategory's budget under its parent's name, so the two
    /// sort next to each other even when only the child carries a budget.
    (String groupName, bool isSubcategory, String ownName) sortKey(
      Budget budget,
    ) {
      final categoryID = budget.categoryID;
      if (categoryID == null) return ('', false, '');
      final category = ledger.state.categories[categoryID];
      if (category == null) {
        return ('(category deleted)', false, '(category deleted)');
      }
      final parentID = category.parentID;
      if (parentID == null) return (category.name, false, category.name);
      final parentName =
          ledger.state.categories[parentID]?.name ?? category.name;
      return (parentName, true, category.name);
    }

    final budgets = ledger.state.budgets.values.toList()
      ..sort((a, b) {
        final aKey = sortKey(a);
        final bKey = sortKey(b);
        final groupCompare = aKey.$1.compareTo(bKey.$1);
        if (groupCompare != 0) return groupCompare;
        if (aKey.$2 != bKey.$2) return aKey.$2 ? 1 : -1;
        return aKey.$3.compareTo(bKey.$3);
      });

    if (budgets.isEmpty) return const BudgetsEmptyState();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: budgets.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => BudgetCard(
        budget: budgets[index],
        month: month,
        items: items,
        state: ledger.state,
        isSubcategory: sortKey(budgets[index]).$2,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BudgetDetailScreen(budget: budgets[index]),
          ),
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
