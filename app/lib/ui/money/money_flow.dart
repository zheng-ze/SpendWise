import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spendwise/boot/money_navigation_provider.dart';
import 'package:spendwise/ui/accounts/accounts_flow.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/accounts/money_navigation.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/common/inputs/month_year_selector.dart';
import 'package:spendwise/ui/common/inputs/segmented_control.dart';
import 'package:spendwise/ui/settings/plan/plan_list_screen.dart';
import 'package:spendwise/ui/settings/plan/plan_list_view_model.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

enum MoneySegment { budgets, accounts, plans }

final moneySegmentProvider = StateProvider<MoneySegment>(
  (ref) => MoneySegment.budgets,
);

final activeMoneySourceProvider = Provider<String? Function()>((ref) {
  return () {
    if (ref.read(selectedDestinationProvider) != ShellDestination.money) {
      return null;
    }
    if (ref.read(moneySegmentProvider) != MoneySegment.accounts) return null;
    return ref.read(moneyNavigatorObserverProvider).sourceId;
  };
});

const _headerRowMinHeight = 48.0;
const _headerPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
const _segmentPadding = EdgeInsets.symmetric(horizontal: 16);
const _options = [
  SegmentedOption(value: MoneySegment.budgets, label: 'Budgets'),
  SegmentedOption(value: MoneySegment.accounts, label: 'Accounts'),
  SegmentedOption(value: MoneySegment.plans, label: 'Plans'),
];

class MoneyFlow extends ConsumerStatefulWidget {
  const MoneyFlow({super.key, required this.moneyObserver});

  final MoneyNavigatorObserver moneyObserver;

  @override
  ConsumerState<MoneyFlow> createState() => _MoneyFlowState();
}

class _MoneyFlowState extends ConsumerState<MoneyFlow> {
  final _visited = <MoneySegment>{MoneySegment.budgets};

  @override
  Widget build(BuildContext context) {
    final segment = ref.watch(moneySegmentProvider);
    _visited.add(segment);
    final active = DestinationActivity.of(context);
    final children = MoneySegment.values.map((value) {
      final child = switch (value) {
        _ when !_visited.contains(value) => const SizedBox.shrink(),
        MoneySegment.budgets => const BudgetsFlow(),
        MoneySegment.accounts => AccountsFlow(
          moneyObserver: widget.moneyObserver,
        ),
        MoneySegment.plans => const PlanListScreen(),
      };
      return DestinationActivity(
        key: ValueKey(value),
        active: active && segment == value,
        child: child,
      );
    }).toList();
    final stack = IndexedStack(index: segment.index, children: children);
    final body = Column(
      children: [
        _MoneyHeader(segment: segment),
        Expanded(child: stack),
      ],
    );
    return SafeArea(child: Material(child: body));
  }
}

class _MoneyHeader extends ConsumerWidget {
  const _MoneyHeader({required this.segment});

  final MoneySegment segment;

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
      onChanged: (value) =>
          ref.read(moneySegmentProvider.notifier).state = value,
    );
    final month = MonthYearSelector(
      value: ref.watch(effectiveMonthProvider),
      step: MonthYearStep.month,
      onChanged: (value) =>
          ref.read(selectedMonthProvider.notifier).state = value,
    );
    return Column(
      children: [
        header,
        Padding(padding: _segmentPadding, child: control),
        if (segment == MoneySegment.budgets) month,
      ],
    );
  }
}

class _MoneyAction extends ConsumerWidget {
  const _MoneyAction({required this.segment});

  final MoneySegment segment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (segment == MoneySegment.accounts) {
      return IconButton(
        tooltip: 'Add account',
        icon: const Icon(Icons.add),
        onPressed: ref
            .read(accountsViewModelProvider.notifier)
            .requestNewAccount,
      );
    }
    if (segment != MoneySegment.plans) return const SizedBox.shrink();
    final state = ref.watch(planListViewModelProvider).value;
    if (state == null || state.plans.isEmpty) return const SizedBox.shrink();
    return TextButton(
      onPressed: ref.read(planListViewModelProvider.notifier).toggleEditing,
      child: Text(state.editing ? 'Done' : 'Edit'),
    );
  }
}
