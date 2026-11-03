import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/money_navigation_provider.dart';
import 'package:spendwise/ui/accounts/accounts_flow.dart';
import 'package:spendwise/ui/accounts/money_navigation.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_pane.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/common/layout/headered_page.dart';
import 'package:spendwise/ui/money/money_header.dart';
import 'package:spendwise/ui/money/money_segment.dart';
import 'package:spendwise/ui/settings/plan/plan_list_screen.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

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
    final budgetPane = segment == MoneySegment.budgets
        ? ref.watch(budgetPaneProvider)
        : null;
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
      MoneySegment.plans => HeaderedPage(
        header: header,
        body: const PlanListScreen(),
      ),
    };
  }
}
