import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/accounts/accounts_flow.dart';
import 'package:spendwise/ui/accounts/money_navigation.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_pane.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/money/money_header.dart';
import 'package:spendwise/ui/money/money_segment.dart';
import 'package:spendwise/ui/plans/plan_detail/plan_pane.dart';
import 'package:spendwise/ui/plans/plan_list/plans_flow.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

final accountsNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(),
);

final activeMoneySourceProvider = Provider<String? Function()>((ref) {
  return () => scopedRegisterSourceId(
    ref.read(accountsNavigatorKeyProvider).currentState,
  );
});

class MoneyFlow extends ConsumerWidget {
  const MoneyFlow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = ref.watch(moneySegmentProvider);
    final ShellPane? pane = switch (segment) {
      MoneySegment.budgets => ref.watch(budgetPaneProvider),
      MoneySegment.accounts => null,
      MoneySegment.plans => ref.watch(planPaneProvider),
    };
    Widget moneyPage(ShellPagePresentation presentation) {
      final header = MoneyHeader(segment: segment, presentation: presentation);
      final body = KeyedSubtree(
        key: ValueKey(segment),
        child: _MoneySegmentBody(segment: segment, header: header),
      );
      return SafeArea(
        child: Material(color: context.colors.base, child: body),
      );
    }

    final page = ShellPaneHost(
      pageBuilder: (_, presentation) => moneyPage(presentation),
      detail: pane?.detail,
    );
    return PopScope<Object?>(
      canPop: pane == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) pane?.close();
      },
      child: page,
    );
  }
}

class _MoneySegmentBody extends ConsumerWidget {
  const _MoneySegmentBody({required this.segment, required this.header});

  final MoneySegment segment;
  final Widget header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (segment) {
      MoneySegment.budgets => BudgetsFlow(header: header),
      MoneySegment.accounts => AccountsFlow(
        header: header,
        navigatorKey: ref.read(accountsNavigatorKeyProvider),
      ),
      MoneySegment.plans => PlansFlow(header: header),
    };
  }
}
