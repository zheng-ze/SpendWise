import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/settings/display_preferences_providers.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_card.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_list_cards.dart';
import 'package:spendwise/ui/common/feedback/loading_skeleton.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_rows.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';

// MARK: - Tray

class BudgetWatchTray extends ConsumerWidget {
  const BudgetWatchTray({
    super.key,
    required this.rows,
    required this.failed,
    required this.viewModel,
  });

  final List<BudgetListCard>? rows;
  final bool failed;
  final OverviewViewModel viewModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = this.rows;
    final chartColours = ref.watch(
      displayPreferencesProvider.select((value) => value.chartColours),
    );
    final Widget content;
    if (failed) {
      content = OverviewLoadError(
        message: overviewBudgetWatchErrorTitle,
        onRetry: viewModel.retryReads,
      );
    } else if (rows == null) {
      content = const LoadingSkeleton();
    } else if (rows.isEmpty) {
      content = BudgetWatchEmpty(onAdd: viewModel.requestBudgets);
    } else {
      content = BudgetWatchRows(
        rows: rows,
        chartColours: chartColours,
        viewModel: viewModel,
      );
    }
    return SizedBox(
      width: overviewFullWidth,
      child: Tray(title: overviewBudgetWatchTitle, child: content),
    );
  }
}

// MARK: - Empty

class BudgetWatchEmpty extends StatelessWidget {
  const BudgetWatchEmpty({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OverviewEmptyCopy(overviewBudgetWatchEmpty),
        OverviewLinkAction(label: overviewBudgetWatchAddLink, onPressed: onAdd),
      ],
    );
  }
}

// MARK: - Rows

class BudgetWatchRows extends StatelessWidget {
  const BudgetWatchRows({
    super.key,
    required this.rows,
    required this.chartColours,
    required this.viewModel,
  });

  final List<BudgetListCard> rows;
  final ChartColours chartColours;
  final OverviewViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final (index, row) in rows.indexed)
        OverviewRowFrame(
          isLast: index == rows.length - 1,
          child: BudgetCard(
            key: ValueKey('budget-${row.id}'),
            savedHex: row.savedHex,
            rank: index,
            chartColours: chartColours,
            name: row.name,
            amounts: row.amounts,
            status: row.status,
            progress: row.progress,
            overLimit: row.overLimit,
            onTap: () => viewModel.openBudget(row.id),
          ),
        ),
    ];
    final link = OverviewLinkAction(
      label: overviewBudgetWatchViewLink,
      onPressed: viewModel.requestBudgets,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [...cards, link],
    );
  }
}
