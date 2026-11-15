import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/settings/display_preferences_providers.dart';
import 'package:spendwise/settings/display_preferences_store.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_flow.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

import 'overview_fixture.dart';
import '../../support/phone_shell.dart';
import '../../support/ui_test_timeout.dart';

const _phoneSize = Size(320, 760);
const _testDevicePixelRatio = 1.0;
const _todayTitle = 'Today';
const _storedWidgetCodes = 'comingUp,notAKind,today,comingUp';

void _ignoreHistory() {}

DisplayPreferences _preferencesWith(List<OverviewWidgetKind> kinds) =>
    DisplayPreferences.defaults.copyWith(overviewWidgets: kinds);

Future<ProviderContainer> _pumpOverview(
  WidgetTester tester,
  DisplayPreferences preferences,
) async {
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = _testDevicePixelRatio;
  addTearDown(tester.view.reset);
  final ledger = Ledger(state: defaultState());
  final container = overviewContainer(ledger, preferences: preferences);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildSpendWiseTheme(Brightness.light),
        home: phoneShell(OverviewFlow(onHistorySelected: _ignoreHistory)),
      ),
    ),
  );
  await tester.runAsync(() => settleAnalysis(container, ledger));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Overview widget order', () {
    testWidgets('default preferences render the three cards in order', (
      tester,
    ) async {
      await _pumpOverview(tester, DisplayPreferences.defaults);

      expect(renderedOverviewKinds(tester), [
        OverviewWidgetKind.today,
        OverviewWidgetKind.recentEntries,
        OverviewWidgetKind.comingUp,
      ]);
    }, timeout: uiTestTimeout);

    testWidgets('stored order is rendered and a replaced list re-renders', (
      tester,
    ) async {
      final container = await _pumpOverview(
        tester,
        _preferencesWith([
          OverviewWidgetKind.comingUp,
          OverviewWidgetKind.today,
          OverviewWidgetKind.recentEntries,
        ]),
      );
      final storedOrder = renderedOverviewKinds(tester);
      final notifier = container.read(displayPreferencesProvider.notifier);
      final replacement = _preferencesWith([OverviewWidgetKind.recentEntries]);

      await tester.runAsync(() => notifier.replace(replacement));
      await tester.pumpAndSettle();

      expect(storedOrder, [
        OverviewWidgetKind.comingUp,
        OverviewWidgetKind.today,
        OverviewWidgetKind.recentEntries,
      ]);
      expect(renderedOverviewKinds(tester), [OverviewWidgetKind.recentEntries]);
      expect(find.text(_todayTitle), findsNothing);
      expect(find.text(overviewComingUpTitle), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('a list loaded from storage renders deduplicated', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        DisplayPreferencesStore.overviewWidgetsKey: _storedWidgetCodes,
      });
      final prefs = await tester.runAsync(SharedPreferences.getInstance);
      final loaded = DisplayPreferencesStore(prefs!).load();

      await _pumpOverview(tester, loaded);

      expect(renderedOverviewKinds(tester), [
        OverviewWidgetKind.comingUp,
        OverviewWidgetKind.today,
      ]);
    }, timeout: uiTestTimeout);

    testWidgets('an empty list shows the title and no cards', (tester) async {
      await _pumpOverview(tester, _preferencesWith([]));

      expect(find.text(overviewTitle), findsOneWidget);
      expect(renderedOverviewKinds(tester), isEmpty);
    }, timeout: uiTestTimeout);

    testWidgets('kinds without a card show the header only', (tester) async {
      await _pumpOverview(
        tester,
        _preferencesWith([
          OverviewWidgetKind.thisMonth,
          OverviewWidgetKind.insights,
          OverviewWidgetKind.weekSoFar,
        ]),
      );

      expect(find.text(overviewTitle), findsOneWidget);
      expect(renderedOverviewKinds(tester), isEmpty);
    }, timeout: uiTestTimeout);
  });
}
