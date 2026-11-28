import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      final container = await _pumpNoCapOverview(
        tester,
        onBudgetsSelected: _ignoreBudgets,
      );

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

  testWidgets(
    'tapping Set a monthly cap with Edit entry open only dismisses the sheet',
    (tester) async {
      var budgetsRequests = 0;
      final container = await _pumpNoCapOverview(
        tester,
        onBudgetsSelected: () => budgetsRequests++,
      );
      await tester.tap(find.text(_entryName));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set a monthly cap'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(AppSheet), findsNothing);
      expect(budgetsRequests, 0);
      expect(
        container.read(selectedDestinationProvider),
        ShellDestination.overview,
      );
    },
    timeout: uiTestTimeout,
  );
}

Future<ProviderContainer> _pumpNoCapOverview(
  WidgetTester tester, {
  required VoidCallback onBudgetsSelected,
}) async {
  final state = emptyState();
  state.addEntry(
    entry(1, '-5.00', fixtureToday, name: _entryName, categoryID: groceriesID),
  );
  final ledger = Ledger(state: state);
  final container = overviewContainer(ledger);
  await pumpShellApp(
    tester,
    container,
    bodies: {
      ShellDestination.overview: (_) => OverviewFlow(
        onHistorySelected: _ignoreHistory,
        onBudgetsSelected: onBudgetsSelected,
        onTrendsSelected: _ignoreBudgets,
        onBudgetSelected: _ignoreBudget,
      ),
    },
  );
  await tester.runAsync(() => settleAnalysis(container, ledger));
  await tester.pumpAndSettle();
  return container;
}

void _ignoreHistory() {}

void _ignoreBudget(String budgetID) {}

void _ignoreBudgets() {}
