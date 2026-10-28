import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spendwise/boot/money_navigation_provider.dart';
import 'package:spendwise/ui/accounts/accounts_flow.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/accounts/money_navigation.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_content.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_selection.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/common/inputs/month_year_selector.dart';
import 'package:spendwise/ui/common/inputs/segmented_control.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/settings/plan/plan_list_screen.dart';
import 'package:spendwise/ui/settings/plan/plan_list_view_model.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

enum MoneySegment { budgets, accounts, plans }

final moneySegmentProvider = StateProvider<MoneySegment>(
  (ref) => MoneySegment.accounts,
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
const _budgetEditLabel = 'Edit';
const _budgetPaneScrollPhysics = ClampingScrollPhysics();
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
  bool _routeRebuildScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.moneyObserver.addListener(_onMoneyRouteChanged);
  }

  @override
  void didUpdateWidget(covariant MoneyFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moneyObserver == widget.moneyObserver) return;
    oldWidget.moneyObserver.removeListener(_onMoneyRouteChanged);
    widget.moneyObserver.addListener(_onMoneyRouteChanged);
  }

  @override
  void dispose() {
    widget.moneyObserver.removeListener(_onMoneyRouteChanged);
    super.dispose();
  }

  void _onMoneyRouteChanged() {
    if (_routeRebuildScheduled) return;
    _routeRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeRebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final segment = ref.watch(moneySegmentProvider);
    _visited.add(segment);
    final active = DestinationActivity.of(context);
    final mode = ref.watch(shellLayoutModeProvider);
    final selection = ref.watch(selectedBudgetProvider);
    final budgetPaneActive =
        active &&
        segment == MoneySegment.budgets &&
        mode == ShellLayoutMode.open &&
        selection != null;
    final budgetDetail = budgetPaneActive ? _budgetDetail(selection) : null;
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
    Widget moneyPage(ShellPagePresentation presentation) {
      final header = widget.moneyObserver.hasScopedTransactionsRoute
          ? null
          : _MoneyHeader(segment: segment, presentation: presentation);
      final content = Column(
        children: [
          ?header,
          Expanded(child: stack),
        ],
      );
      return SafeArea(child: Material(child: content));
    }

    final page = ShellPaneScope.maybeOf(context) == null
        ? moneyPage(ShellPagePresentation.fullPage)
        : ShellPaneHost(
            pageBuilder: (_, presentation) => moneyPage(presentation),
            detail: budgetDetail,
          );
    return PopScope<Object?>(
      canPop: !budgetPaneActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && budgetPaneActive) {
          ref.read(selectedBudgetProvider.notifier).clear();
        }
      },
      child: page,
    );
  }

  ShellDetail? _budgetDetail(BudgetSelection selection) {
    final viewState = ref
        .watch(budgetDetailViewModelProvider(selection.budgetID))
        .value;
    if (viewState == null) return null;
    final viewModel = ref.read(
      budgetDetailViewModelProvider(selection.budgetID).notifier,
    );
    final content = BudgetDetailContent(
      viewState: viewState,
      viewModel: viewModel,
    );
    final body = ListView(
      physics: _budgetPaneScrollPhysics,
      children: [content],
    );
    return ShellDetail(
      id: selection.budgetID,
      title: viewState.title,
      subtitle: formatMonthLabel(viewState.selectedMonth),
      bodyBuilder: (_) => body,
      headerActions: [
        TextButton.icon(
          onPressed: viewModel.requestLimitEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text(_budgetEditLabel),
        ),
      ],
    );
  }
}

class _MoneyHeader extends ConsumerWidget {
  const _MoneyHeader({required this.segment, required this.presentation});

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
