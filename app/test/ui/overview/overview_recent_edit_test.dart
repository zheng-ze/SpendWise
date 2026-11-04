import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/overview/overview_flow.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../support/shell_sheet_harness.dart';
import '../../support/ui_test_timeout.dart';
import 'overview_fixture.dart';

const _entryName = 'Coffee run';

void main() {
  testWidgets(
    'tapping a Recent entries row opens Edit entry and Overview stays selected',
    (tester) async {
      final state = emptyState();
      state.addEntry(
        entry(
          1,
          '-5.00',
          fixtureToday,
          name: _entryName,
          categoryID: groceriesID,
        ),
      );
      final ledger = Ledger(state: state);
      final container = overviewContainer(ledger);
      await pumpShellApp(
        tester,
        container,
        bodies: {
          ShellDestination.overview: (_) =>
              const OverviewFlow(onHistorySelected: _ignoreHistory),
        },
      );
      await tester.runAsync(() => settleAnalysis(container, ledger));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_entryName));
      await tester.pumpAndSettle();

      expect(find.byType(AppSheet), findsOneWidget);
      expect(find.text('Edit entry'), findsWidgets);
      expect(
        container.read(selectedDestinationProvider),
        ShellDestination.overview,
      );
    },
    timeout: uiTestTimeout,
  );
}

void _ignoreHistory() {}
