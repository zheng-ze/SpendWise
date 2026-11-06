import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../../support/ui_test_timeout.dart';
import '../plans_shell_test_support.dart';

const _helperCopy =
    'To add a plan, add an entry and choose how often it repeats.';

const _planNames = ['Rent', 'To savings', 'Salary'];

List<String> _shownPlanNames(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    if (_planNames.contains(text.data)) text.data!,
];

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
        expect(_shownPlanNames(tester), ['Rent', 'To savings', 'Salary']);
        expect(find.text('Edit'), findsNothing);
        expect(find.text('Done'), findsNothing);
        expect(find.text('Add plan'), findsNothing);
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
  }
}
