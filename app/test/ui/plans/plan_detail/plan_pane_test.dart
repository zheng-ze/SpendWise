import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/plans/plan_detail/plan_detail_screen.dart';
import 'package:spendwise/ui/plans/plan_list/plan_selection.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../../support/ui_test_timeout.dart';
import '../plans_shell_test_support.dart';

const _openLayouts = [ShellLayoutMode.open, ShellLayoutMode.desktop];

Future<ProviderContainer> _pump(
  WidgetTester tester,
  ShellLayoutMode mode,
  Brightness brightness,
) => pumpPlansShell(
  tester,
  mode: mode,
  ledger: buildPlansShellLedger(),
  brightness: brightness,
);

Finder _inPane(Finder finder) =>
    find.descendant(of: find.byKey(shellDetailPaneKey), matching: finder);

void _expectExpensePlanFields() {
  expect(_inPane(find.text('Rent')), findsOneWidget);
  expect(_inPane(find.text('-S\$1,200.00')), findsOneWidget);
  expect(_inPane(find.text('Every month')), findsOneWidget);
  expect(_inPane(find.text('Account')), findsOneWidget);
  expect(_inPane(find.text('Checking')), findsOneWidget);
  expect(_inPane(find.text('Category')), findsOneWidget);
  expect(_inPane(find.text('Ends')), findsOneWidget);
}

void main() {
  for (final brightness in Brightness.values) {
    final suffix = brightness.name;

    for (final mode in _openLayouts) {
      testWidgets(
        'mo-desk-plans ${mode.name} tapping a plan shows its pane ($suffix)',
        (tester) async {
          final container = await _pump(tester, mode, brightness);

          await tapPlan(tester, plansShellExpensePlan.id);

          expect(
            container.read(selectedPlanProvider),
            plansShellExpensePlan.id,
          );
          expect(find.byKey(shellDetailPaneKey), findsOneWidget);
          expect(find.byType(PlanDetailScreen), findsNothing);
          _expectExpensePlanFields();
        },
        timeout: uiTestTimeout,
      );

      testWidgets(
        'mo-desk-plans ${mode.name} Close clears the selection ($suffix)',
        (tester) async {
          final container = await _pump(tester, mode, brightness);
          await tapPlan(tester, plansShellExpensePlan.id);

          await tester.tap(find.byKey(shellDetailCloseKey));
          await tester.pumpAndSettle();

          expect(container.read(selectedPlanProvider), isNull);
          expect(find.byKey(shellDetailPaneKey), findsNothing);
        },
        timeout: uiTestTimeout,
      );

      testWidgets(
        'mo-desk-plans ${mode.name} closes when the plan is deleted ($suffix)',
        (tester) async {
          final container = await _pump(tester, mode, brightness);
          await tapPlan(tester, plansShellExpensePlan.id);

          container
              .read(plansShellLedgerFixture)!
              .deletePlan(plansShellExpensePlan.id);
          await tester.pumpAndSettle();

          expect(container.read(selectedPlanProvider), isNull);
          expect(find.byKey(shellDetailPaneKey), findsNothing);
        },
        timeout: uiTestTimeout,
      );

      testWidgets('mo-desk-plans ${mode.name} Back closes the pane ($suffix)', (
        tester,
      ) async {
        final container = await _pump(tester, mode, brightness);
        await tapPlan(tester, plansShellExpensePlan.id);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(container.read(selectedPlanProvider), isNull);
        expect(find.byKey(shellDetailPaneKey), findsNothing);
        final row = find.byKey(ValueKey('plan-${plansShellExpensePlan.id}'));
        expect(row, findsOneWidget);
      }, timeout: uiTestTimeout);
    }

    testWidgets('mo-desk-plans phone builds no pane ($suffix)', (tester) async {
      final container = await _pump(tester, ShellLayoutMode.phone, brightness);

      await tapPlan(tester, plansShellExpensePlan.id);

      expect(container.read(selectedPlanProvider), plansShellExpensePlan.id);
      expect(find.byKey(shellDetailPaneKey), findsNothing);
      expect(find.byType(PlanDetailScreen), findsOneWidget);
    }, timeout: uiTestTimeout);
  }
}
