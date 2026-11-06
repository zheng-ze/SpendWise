import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/plans/plan_list/plan_list_view_model.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../../support/ui_test_timeout.dart';
import '../plans_shell_test_support.dart';

const _emptyTitle = 'Make regular entries easier';
const _emptyBody = 'Choose Repeat when adding an entry to create a plan.';
const _helperCopy =
    'To add a plan, add an entry and choose how often it repeats.';
const _loadErrorTitle = "Couldn't load your plans";
const _tryAgainLabel = 'Try again';
const _populatedTrayTitle = 'Next up';

class _FlakyPlanListNotifier extends PlanListNotifier {
  _FlakyPlanListNotifier(this._shouldFail);

  final bool Function() _shouldFail;

  @override
  PlanListViewState build() {
    if (_shouldFail()) throw StateError('Data unavailable');
    return super.build();
  }
}

void main() {
  for (final brightness in Brightness.values) {
    final suffix = brightness.name;

    testWidgets(
      'fr-plans shows the empty state with no add or edit controls ($suffix)',
      (tester) async {
        await pumpPlansShell(
          tester,
          mode: ShellLayoutMode.phone,
          ledger: buildPlansShellLedger(plans: const []),
          brightness: brightness,
        );

        expect(find.text(_emptyTitle), findsOneWidget);
        expect(find.text(_emptyBody), findsOneWidget);
        expect(find.text(_populatedTrayTitle), findsNothing);
        expect(find.text(_helperCopy), findsNothing);
        expect(find.text('Add plan'), findsNothing);
        expect(find.text('Edit'), findsNothing);
        expect(find.text('Done'), findsNothing);
      },
      timeout: uiTestTimeout,
    );

    testWidgets(
      'le-plans-err shows the load error and Try again recovers the list ($suffix)',
      (tester) async {
        var shouldFail = true;
        await pumpPlansShell(
          tester,
          mode: ShellLayoutMode.phone,
          ledger: buildPlansShellLedger(),
          brightness: brightness,
          overrides: [
            planListViewModelProvider.overrideWith(
              () => _FlakyPlanListNotifier(() => shouldFail),
            ),
          ],
        );

        expect(find.text(_loadErrorTitle), findsOneWidget);
        expect(find.text(_tryAgainLabel), findsOneWidget);

        shouldFail = false;
        await tester.tap(find.text(_tryAgainLabel));
        await tester.pumpAndSettle();

        expect(find.text(_loadErrorTitle), findsNothing);
        expect(find.text(_populatedTrayTitle), findsOneWidget);
        expect(find.text('Rent'), findsOneWidget);
      },
      timeout: uiTestTimeout,
    );
  }
}
