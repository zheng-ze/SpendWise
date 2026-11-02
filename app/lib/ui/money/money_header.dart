import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/common/inputs/month_year_selector.dart';
import 'package:spendwise/ui/common/inputs/segmented_control.dart';
import 'package:spendwise/ui/money/money_flow.dart';
import 'package:spendwise/ui/settings/plan/plan_list_view_model.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

// MARK: - Constants
const _headerRowMinHeight = 48.0;
const _headerPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
const _segmentPadding = EdgeInsets.symmetric(horizontal: 16);
const _options = [
  SegmentedOption(value: MoneySegment.budgets, label: 'Budgets'),
  SegmentedOption(value: MoneySegment.accounts, label: 'Accounts'),
  SegmentedOption(value: MoneySegment.plans, label: 'Plans'),
];

// MARK: - MoneyHeader
class MoneyHeader extends ConsumerWidget {
  const MoneyHeader({
    super.key,
    required this.segment,
    required this.presentation,
  });

  final MoneySegment segment;
  final ShellPagePresentation presentation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = Expanded(
      child: Text('Money', style: Theme.of(context).textTheme.headlineSmall),
    );
    final row = Row(
      children: [
        title,
        _MoneyAction(segment: segment),
      ],
    );
    final titleRow = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _headerRowMinHeight),
      child: row,
    );
    final header = Padding(padding: _headerPadding, child: titleRow);
    final control = SegmentedControl(
      options: _options,
      value: segment,
      small: presentation == ShellPagePresentation.singleColumn,
      onChanged: (value) =>
          ref.read(moneySegmentProvider.notifier).state = value,
    );
    return Column(
      children: [
        header,
        Padding(padding: _segmentPadding, child: control),
        if (segment == MoneySegment.budgets) const _BudgetsMonthSelector(),
      ],
    );
  }
}

// MARK: - BudgetsMonthSelector
class _BudgetsMonthSelector extends ConsumerWidget {
  const _BudgetsMonthSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MonthYearSelector(
      value: ref.watch(effectiveMonthProvider),
      step: MonthYearStep.month,
      onChanged: (value) =>
          ref.read(selectedMonthProvider.notifier).state = value,
    );
  }
}

// MARK: - MoneyAction
class _MoneyAction extends ConsumerWidget {
  const _MoneyAction({required this.segment});

  final MoneySegment segment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (segment == MoneySegment.accounts) {
      return IconButton(
        tooltip: 'Add account',
        icon: const Icon(Icons.add),
        onPressed: () =>
            ref.read(accountsViewModelProvider.notifier).requestNewAccount(),
      );
    }
    if (segment != MoneySegment.plans) return const SizedBox.shrink();
    final state = ref.watch(planListViewModelProvider).value;
    if (state == null || state.plans.isEmpty) return const SizedBox.shrink();
    return TextButton(
      onPressed: () =>
          ref.read(planListViewModelProvider.notifier).toggleEditing(),
      child: Text(state.editing ? 'Done' : 'Edit'),
    );
  }
}
