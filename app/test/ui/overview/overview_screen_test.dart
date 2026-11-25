import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/overview/overview_screen.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

import 'overview_fixture.dart';
import '../../support/ui_test_timeout.dart';

const _phoneSize = Size(320, 760);
const _testDevicePixelRatio = 1.0;

Future<ProviderContainer> _pumpBareOverviewScreen(
  WidgetTester tester,
  LedgerState state, {
  DisplayPreferences? preferences,
}) async {
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = _testDevicePixelRatio;
  addTearDown(tester.view.reset);
  final ledger = Ledger(state: state);
  final container = overviewContainer(ledger, preferences: preferences);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildSpendWiseTheme(Brightness.light),
        home: const OverviewScreen(),
      ),
    ),
  );
  await tester.runAsync(() => settleAnalysis(container, ledger));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('Set a monthly cap requests the Budgets section', (tester) async {
    final state = emptyState();
    state.addEntry(
      entry(1, '-5.00', fixtureToday, name: 'Lunch', categoryID: groceriesID),
    );
    final container = await _pumpBareOverviewScreen(tester, state);

    final action = find.text('Set a monthly cap');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pump();

    expect(
      container.read(overviewViewModelProvider).requireValue.step,
      isA<OverviewBudgetsRequested>(),
    );
  }, timeout: uiTestTimeout);

  testWidgets('Add a budget requests the Budgets section', (tester) async {
    final state = emptyState();
    state.addBudget(null, Decimal.parse('1200'));
    final container = await _pumpBareOverviewScreen(
      tester,
      state,
      preferences: DisplayPreferences(
        overviewWidgets: const [OverviewWidgetKind.budgetWatch],
      ),
    );

    expect(find.text('No budgets yet.'), findsOneWidget);
    final action = find.text('Add a budget');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pump();

    expect(
      container.read(overviewViewModelProvider).requireValue.step,
      isA<OverviewBudgetsRequested>(),
    );
  }, timeout: uiTestTimeout);

  testWidgets('View History requests the history page', (tester) async {
    final container = await _pumpBareOverviewScreen(tester, defaultState());

    final action = find.widgetWithText(TextButton, 'View History');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pump();

    expect(
      container.read(overviewViewModelProvider).requireValue.step,
      isA<OverviewHistoryRequested>(),
    );
  }, timeout: uiTestTimeout);
}
