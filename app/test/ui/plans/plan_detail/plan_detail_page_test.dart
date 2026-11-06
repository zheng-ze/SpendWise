import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/plans/plan_detail/plan_detail_screen.dart';
import 'package:spendwise/ui/plans/plan_list/plan_selection.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../../support/ui_test_timeout.dart';
import '../plans_shell_test_support.dart';

Future<ProviderContainer> _pumpPhone(
  WidgetTester tester,
  Brightness brightness,
) => pumpPlansShell(
  tester,
  mode: ShellLayoutMode.phone,
  ledger: buildPlansShellLedger(),
  brightness: brightness,
);

void main() {
  for (final brightness in Brightness.values) {
    final suffix = brightness.name;

    testWidgets(
      'mo-plan-detail phone shows the expense plan fields ($suffix)',
      (tester) async {
        final container = await _pumpPhone(tester, brightness);

        await tapPlan(tester, plansShellExpensePlan.id);

        expect(container.read(selectedPlanProvider), plansShellExpensePlan.id);
        expect(find.byType(PlanDetailScreen), findsOneWidget);
        expect(find.text('Rent'), findsOneWidget);
        expect(find.byKey(shellDetailPaneKey), findsNothing);
        expect(find.text('-S\$1,200.00'), findsOneWidget);
        expect(find.text('Edit plan'), findsOneWidget);
        expect(find.text('Delete plan'), findsOneWidget);
      },
      timeout: uiTestTimeout,
    );

    testWidgets(
      'mo-plan-detail Back pops the page and clears the selection ($suffix)',
      (tester) async {
        final container = await _pumpPhone(tester, brightness);
        await tapPlan(tester, plansShellExpensePlan.id);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(PlanDetailScreen), findsNothing);
        expect(container.read(selectedPlanProvider), isNull);
      },
      timeout: uiTestTimeout,
    );

    testWidgets(
      'mo-plan-detail closes when the plan is deleted from the ledger ($suffix)',
      (tester) async {
        final container = await _pumpPhone(tester, brightness);
        await tapPlan(tester, plansShellExpensePlan.id);

        container
            .read(plansShellLedgerFixture)!
            .deletePlan(plansShellExpensePlan.id);
        await tester.pumpAndSettle();

        expect(find.byType(PlanDetailScreen), findsNothing);
        expect(container.read(selectedPlanProvider), isNull);
      },
      timeout: uiTestTimeout,
    );

    testWidgets(
      'mo-plan-detail keeps the selection across fold and unfold ($suffix)',
      (tester) async {
        final container = await _pumpPhone(tester, brightness);
        await tapPlan(tester, plansShellExpensePlan.id);

        container.read(plansShellModeFixture.notifier).state =
            ShellLayoutMode.open;
        await tester.pumpAndSettle();
        expect(find.byType(PlanDetailScreen), findsNothing);
        expect(container.read(selectedPlanProvider), plansShellExpensePlan.id);

        container.read(plansShellModeFixture.notifier).state =
            ShellLayoutMode.phone;
        await tester.pumpAndSettle();
        expect(find.byType(PlanDetailScreen), findsOneWidget);
        expect(container.read(selectedPlanProvider), plansShellExpensePlan.id);
      },
      timeout: uiTestTimeout,
    );
  }
}
