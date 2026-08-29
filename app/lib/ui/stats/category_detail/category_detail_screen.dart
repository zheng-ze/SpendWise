import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/day_sectioned_entry_list.dart';
import 'package:spendwise/ui/common/month_year_selector.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/category_detail/category_trend_card.dart';
import 'package:spendwise/ui/stats/helpers/stats_window.dart';
import 'package:spendwise/ui/stats/category_detail/subcategory_table.dart';

class CategoryDetailScreen extends ConsumerWidget {
  const CategoryDetailScreen({super.key, required this.args});

  final CategoryDetailArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(categoryDetailViewModelProvider(args));
    final viewModel = ref.watch(categoryDetailViewModelProvider(args).notifier);
    final ledger = ref.watch(ledgerProvider);

    return asyncState.when(
      data: (viewState) => ledger == null
          ? const SizedBox.shrink()
          : _CategoryDetailBody(
              viewState: viewState,
              viewModel: viewModel,
              ledger: ledger,
            ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('$error'))),
    );
  }
}

class _CategoryDetailBody extends StatelessWidget {
  const _CategoryDetailBody({
    required this.viewState,
    required this.viewModel,
    required this.ledger,
  });

  final CategoryDetailViewState viewState;
  final CategoryDetailViewModel viewModel;
  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AmountColors.of(theme);

    final mainCategory = viewState.mainCategory;
    final title = mainCategory?.name ?? '';
    final totals = viewState.totals;

    final step = viewState.isYearRange
        ? MonthYearStep.year
        : MonthYearStep.month;

    final scopeColor = viewState.kind == CategoryKind.income
        ? colors.gain
        : colors.loss;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          MonthYearSelector(
            value: viewState.detailDate,
            step: step,
            onChanged: viewModel.setDate,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: AmountHeader(
                caption: scopeCaption(
                  title,
                  viewState.scope,
                  viewState.ledgerState,
                ),
                amount: totals.scopeTotal,
                amountColor: scopeColor,
              ),
            ),
            if (viewState.children.isNotEmpty)
              SubcategoryTable(
                mainCategory: mainCategory,
                mainTotal: totals.mainTotal,
                children: viewState.children,
                childTotals: totals.childTotals,
                directTotal: totals.directTotal,
                scope: viewState.scope,
                onSelectScope: viewModel.setScope,
              ),
            TrendCard(
              scope: viewState.scope,
              mainCategory: mainCategory,
              state: viewState.ledgerState,
              detailDate: viewState.detailDate,
              isYearRange: viewState.isYearRange,
              months: viewState.trendMonths,
              amounts: viewState.trendAmounts,
              color: scopeColor,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'ENTRIES',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            DaySectionedEntryList(
              ledger: ledger,
              state: viewState.ledgerState,
              window: viewState.window,
              matching: () => viewState.ledgerState.entries.values.where(
                (entry) =>
                    !entry.isTransfer &&
                    viewState.scopedBuckets.contains(entry.categoryID) &&
                    Accounting.includedInAnalysis(entry, viewState.ledgerState),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
