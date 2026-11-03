import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spendwise/boot/money_navigation_provider.dart';
import 'package:spendwise/ui/accounts/accounts_flow.dart';
import 'package:spendwise/ui/accounts/money_navigation.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_pane.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/common/layout/headered_page.dart';
import 'package:spendwise/ui/money/money_header.dart';
import 'package:spendwise/ui/settings/plan/plan_list_screen.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

enum MoneySegment { budgets, accounts, plans }

final moneySegmentProvider = StateProvider.autoDispose<MoneySegment>(
  (ref) => MoneySegment.accounts,
);

final activeMoneySourceProvider = Provider<String? Function()>((ref) {
  return () => scopedRegisterSourceId(
    ref.read(accountsNavigatorKeyProvider).currentState,
  );
});

class MoneyFlow extends ConsumerStatefulWidget {
  const MoneyFlow({super.key});

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
    final budgetsVisible = active && segment == MoneySegment.budgets;
    final budgetPane = budgetsVisible ? ref.watch(budgetPaneProvider) : null;
    Widget moneyPage(ShellPagePresentation presentation) {
      final children = MoneySegment.values.map((value) {
        final header = MoneyHeader(segment: value, presentation: presentation);
        final child = switch (value) {
          _ when !_visited.contains(value) => const SizedBox.shrink(),
          MoneySegment.budgets => BudgetsFlow(header: header),
          MoneySegment.accounts => AccountsFlow(
            header: header,
            navigatorKey: ref.read(accountsNavigatorKeyProvider),
          ),
          MoneySegment.plans => HeaderedPage(
            header: header,
            body: const PlanListScreen(),
          ),
        };
        return DestinationActivity(
          key: ValueKey(value),
          active: active && segment == value,
          child: child,
        );
      }).toList();
      final stack = IndexedStack(index: segment.index, children: children);
      return SafeArea(
        child: Material(color: context.colors.base, child: stack),
      );
    }

    final page = ShellPaneScope.maybeOf(context) == null
        ? moneyPage(ShellPagePresentation.fullPage)
        : ShellPaneHost(
            pageBuilder: (_, presentation) => moneyPage(presentation),
            detail: budgetPane?.detail,
          );
    return PopScope<Object?>(
      canPop: budgetPane == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) budgetPane?.close();
      },
      child: page,
    );
  }
}
