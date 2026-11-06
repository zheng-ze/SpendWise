import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/plans/plan_list/plan_selection.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../../support/ui_test_timeout.dart';
import '../plans_shell_test_support.dart';

const _helperCopy =
    'To add a plan, add an entry and choose how often it repeats.';

void main() {
  for (final brightness in Brightness.values) {
    final suffix = brightness.name;

    testWidgets(
      'mo-plans lists Next up rows by next date without edit controls ($suffix)',
      (tester) async {
        await pumpPlansShell(
          tester,
          mode: ShellLayoutMode.phone,
          ledger: buildPlansShellLedger(),
          brightness: brightness,
        );

        expect(find.text('Next up'), findsOneWidget);
        expect(find.text('3 plans'), findsOneWidget);
        expect(find.text(_helperCopy), findsOneWidget);
        expect(find.text('Every month / Checking'), findsNWidgets(3));
        expect(find.text('-1,200.00'), findsOneWidget);
        expect(find.text('+3,000.00'), findsOneWidget);
        expect(find.text('500.00'), findsOneWidget);
        final rent = tester.getTopLeft(find.text('Rent')).dy;
        final savings = tester.getTopLeft(find.text('To savings')).dy;
        final salary = tester.getTopLeft(find.text('Salary')).dy;
        expect(rent, lessThan(savings));
        expect(savings, lessThan(salary));
        expect(find.text('Edit'), findsNothing);
        expect(find.text('Done'), findsNothing);
        expect(find.text('Add plan'), findsNothing);
        expect(find.byIcon(Icons.remove_circle), findsNothing);
        expect(find.byType(Dismissible), findsNothing);
      },
      timeout: uiTestTimeout,
    );

    testWidgets(
      'mo-plans-attention / phone-plans lists a binned-category plan normally ($suffix)',
      (tester) async {
        final ledger = buildPlansShellLedger(
          plans: [plansShellExpensePlan, plansShellBinnedCategoryPlan],
        );
        await pumpPlansShell(
          tester,
          mode: ShellLayoutMode.phone,
          ledger: ledger,
          brightness: brightness,
        );

        expect(find.text('Gym membership'), findsOneWidget);
        expect(find.text('2 plans'), findsOneWidget);
        expect(find.textContaining('recycle bin'), findsNothing);
        expect(find.textContaining('missed'), findsNothing);
        expect(find.text('Restore Fitness'), findsNothing);
      },
      timeout: uiTestTimeout,
    );

    testWidgets('tapping a plan row selects that plan ($suffix)', (
      tester,
    ) async {
      final container = await pumpPlansShell(
        tester,
        mode: ShellLayoutMode.phone,
        ledger: buildPlansShellLedger(),
        brightness: brightness,
      );

      await tapPlan(tester, plansShellIncomePlan.id);

      expect(container.read(selectedPlanProvider), plansShellIncomePlan.id);
    }, timeout: uiTestTimeout);
  }
}
