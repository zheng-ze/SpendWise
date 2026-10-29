import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/budgets/budget_list/budget_card.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_selection.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';
import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/feedback/empty_state.dart';
import 'package:spendwise/ui/common/feedback/loading_skeleton.dart';
import 'package:spendwise/ui/common/navigation/compact_labelled_fab.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

const _contentPadding = EdgeInsets.all(12);
const _sectionGap = 10.0;
const _actionPadding = EdgeInsets.all(12);
const _openActionPadding = EdgeInsets.only(right: 3, bottom: 10);
const _summaryGap = 4.0;
const _summaryBarHeight = 7.0;
const _summaryBarRadius = 4.0;
const _categoryHeaderGap = 4.0;
const _categoryCardGap = 10.0;
const _singleColumn = 1;
const _openColumns = 2;

int budgetListColumnCount({
  required bool openLayout,
  required bool addPresented,
  required bool selectionPresent,
}) {
  if (openLayout && !addPresented && !selectionPresent) return _openColumns;
  return _singleColumn;
}

class BudgetsRoot extends ConsumerWidget {
  const BudgetsRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(budgetsListViewModelProvider);
    final viewModel = ref.watch(budgetsListViewModelProvider.notifier);
    final mode = ref.watch(shellLayoutModeProvider);
    final desktop = mode == ShellLayoutMode.desktop;
    final addPresented = ShellPaneScope.maybeOf(context)?.addPresented ?? false;
    final open = mode == ShellLayoutMode.open;
    final body = state.when(
      data: (value) => BudgetsListView(
        viewState: value,
        viewModel: viewModel,
        desktop: desktop,
        columns: budgetListColumnCount(
          openLayout: open,
          addPresented: addPresented,
          selectionPresent: value.selectedBudgetID != null,
        ),
        showFloatingAction: !addPresented,
        actionPadding: open ? _openActionPadding : _actionPadding,
      ),
      loading: () =>
          const Padding(padding: _contentPadding, child: LoadingTrays()),
      error: (error, _) =>
          BudgetListError(error: error, onRetry: viewModel.retry),
    );
    final dismissSelection = (open || desktop) && !addPresented
        ? ref.read(selectedBudgetProvider.notifier).clear
        : null;
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: dismissSelection,
        child: body,
      ),
    );
  }
}

enum BudgetsSection { allSpending, categoryBudgets }

class BudgetsListView extends StatelessWidget {
  const BudgetsListView({
    super.key,
    required this.viewState,
    required this.viewModel,
    this.desktop = false,
    this.columns = _singleColumn,
    this.showFloatingAction = true,
    this.actionPadding = _actionPadding,
    this.sections = const [
      BudgetsSection.allSpending,
      BudgetsSection.categoryBudgets,
    ],
  });

  final BudgetsListViewState viewState;
  final BudgetsListViewModel viewModel;
  final bool desktop;
  final int columns;
  final bool showFloatingAction;
  final EdgeInsets actionPadding;
  final List<BudgetsSection> sections;

  @override
  Widget build(BuildContext context) {
    final overview = viewState.overview;
    final error = viewState.error;
    final content = <Widget>[];
    if (error != null) {
      content.add(BudgetListError(error: error, onRetry: viewModel.retry));
    }
    if (overview == null) {
      if (error == null) content.add(const LoadingTrays());
    } else if (!overview.hasBudgets) {
      content.add(
        EmptyState(
          icon: Icons.savings_outlined,
          title: 'Give your spending a limit',
          body: 'Add a budget for one category or all your spending.',
          actionLabel: 'Add budget',
          onAction: viewModel.requestNewBudget,
        ),
      );
    } else {
      if (desktop) {
        content.add(
          Align(
            alignment: Alignment.centerRight,
            child: PrimaryButton(
              label: 'Add budget',
              onPressed: viewModel.requestNewBudget,
            ),
          ),
        );
      }
      for (final section in sections) {
        final widget = switch (section) {
          BudgetsSection.allSpending => _AllSpendingSection(
            key: const ValueKey(BudgetsSection.allSpending),
            viewState: viewState,
            viewModel: viewModel,
          ),
          BudgetsSection.categoryBudgets => _CategoryBudgetsSection(
            key: const ValueKey(BudgetsSection.categoryBudgets),
            columns: columns,
            viewState: viewState,
            viewModel: viewModel,
          ),
        };
        content.add(widget);
        content.add(const SizedBox(height: _sectionGap));
      }
      content.add(const FabReserveSpace());
    }
    final list = ListView(padding: _contentPadding, children: content);
    final showAction =
        showFloatingAction &&
        !desktop &&
        overview != null &&
        overview.hasBudgets;
    if (!showAction) return list;
    final action = CompactLabelledFab(
      label: 'Add budget',
      icon: Icons.add,
      onPressed: viewModel.requestNewBudget,
    );
    return Stack(
      children: [
        list,
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(padding: actionPadding, child: action),
        ),
      ],
    );
  }
}

class _AllSpendingSection extends StatelessWidget {
  const _AllSpendingSection({
    super.key,
    required this.viewState,
    required this.viewModel,
  });
  final BudgetsListViewState viewState;
  final BudgetsListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final summary = viewState.summary;
    final colors = context.colors;
    final amountStyle = context.text.headline.copyWith(
      color: summary.overLimit ? colors.expense : colors.text,
    );
    final captionStyle = Theme.of(context).textTheme.bodySmall;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary.remaining, style: amountStyle),
        Text(summary.caption, style: captionStyle),
        const SizedBox(height: _summaryGap),
        LinearProgressIndicator(
          value: summary.progress,
          minHeight: _summaryBarHeight,
          borderRadius: BorderRadius.circular(_summaryBarRadius),
          color: summary.overLimit ? colors.expense : colors.action,
          backgroundColor: colors.tint,
        ),
        const SizedBox(height: _summaryGap),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Spent so far', style: captionStyle),
            Text(summary.spent, style: context.text.small),
          ],
        ),
        if (summary.allowance != null)
          Text(summary.allowance!, style: captionStyle),
      ],
    );
    final id = summary.budgetID;
    final child = id == null
        ? content
        : InkWell(
            onTap: () => viewModel.requestBudgetDetail(id),
            child: content,
          );
    final selected =
        summary.budgetID != null &&
        summary.budgetID == viewState.selectedBudgetID;
    final tray = Tray(title: 'All spending', selected: selected, child: child);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (id != null) viewModel.requestBudgetDetail(id);
      },
      child: tray,
    );
  }
}

class _CategoryBudgetsSection extends StatelessWidget {
  const _CategoryBudgetsSection({
    super.key,
    required this.viewState,
    required this.viewModel,
    required this.columns,
  });
  final BudgetsListViewState viewState;
  final BudgetsListViewModel viewModel;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];
    for (final (index, row) in viewState.cards.indexed) {
      final card = BudgetCard(
        key: ValueKey('budget-${row.id}'),
        savedHex: row.savedHex,
        rank: index,
        chartColours: viewState.chartColours,
        name: row.name,
        amounts: row.amounts,
        status: row.status,
        progress: row.progress,
        overLimit: row.overLimit,
        onTap: () => viewModel.requestBudgetDetail(row.id),
      );
      final tray = Tray(
        key: ValueKey('budget-tray-${row.id}'),
        selected: row.id == viewState.selectedBudgetID,
        child: card,
      );
      cards.add(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => viewModel.requestBudgetDetail(row.id),
          child: tray,
        ),
      );
    }
    final content = _BudgetCardLayout(columns: columns, children: cards);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TrayHeader(
          title: 'Category budgets',
          trailing: Text(
            'Most used first',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: _categoryHeaderGap),
        content,
      ],
    );
  }
}

class _BudgetCardLayout extends StatelessWidget {
  const _BudgetCardLayout({required this.columns, required this.children});
  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (columns == _singleColumn || children.length == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const SizedBox(height: _categoryCardGap),
            child,
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - _sectionGap) / columns;
        final tiles = [
          for (final child in children) SizedBox(width: width, child: child),
        ];
        return Wrap(spacing: _sectionGap, children: tiles);
      },
    );
  }
}

class BudgetListError extends StatelessWidget {
  const BudgetListError({
    super.key,
    required this.error,
    required this.onRetry,
  });
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Couldn't load your budgets"),
        Text('$error'),
        PrimaryButton(label: 'Try again', onPressed: onRetry),
      ],
    );
    return Padding(
      padding: _contentPadding,
      child: Tray(child: content),
    );
  }
}
