import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/settings/display_preferences_providers.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/overview/overview_edit_rows.dart';
import 'package:spendwise/ui/overview/overview_flow.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../support/shell_sheet_harness.dart';
import '../../support/ui_test_timeout.dart';
import 'overview_fixture.dart';

const _phoneWindow = Size(390, 844);

const _outsideSheetTap = Offset(20, 20);

const _reorderDragSteps = 5;

const _hideDragSteps = 10;

const _dragStepDistance = 12.0;

const _seededKinds = [
  OverviewWidgetKind.today,
  OverviewWidgetKind.thisMonth,
  OverviewWidgetKind.recentEntries,
  OverviewWidgetKind.cardStatement,
  OverviewWidgetKind.comingUp,
  OverviewWidgetKind.budgetWatch,
  OverviewWidgetKind.insights,
  OverviewWidgetKind.weekSoFar,
];

final _hiddenHint = find.byType(OverviewEditHiddenHint);

const _hiddenKind = OverviewWidgetKind.weekSoFar;

const _swappedKinds = [
  OverviewWidgetKind.thisMonth,
  OverviewWidgetKind.today,
  OverviewWidgetKind.recentEntries,
  OverviewWidgetKind.cardStatement,
  OverviewWidgetKind.comingUp,
  OverviewWidgetKind.budgetWatch,
  OverviewWidgetKind.insights,
  OverviewWidgetKind.weekSoFar,
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('grip drag reorders without dismissing and Done saves', (
    tester,
  ) async {
    final container = await _pumpOverview(tester);
    await _openSheet(tester);

    await _dragGripDown(
      tester,
      find.byIcon(Icons.drag_indicator).first,
      _reorderDragSteps,
    );

    expect(find.byType(AppSheet), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet), findsNothing);
    expect(_savedKinds(container), _swappedKinds);
  }, timeout: uiTestTimeout);

  testWidgets('dragging a card into Hidden then tapping outside discards', (
    tester,
  ) async {
    final container = await _pumpOverview(tester);
    await _openSheet(tester);
    expect(_hiddenHint, findsOneWidget);

    await tester.ensureVisible(_gripOf(_hiddenKind));
    await tester.pumpAndSettle();
    await _dragGripDown(tester, _gripOf(_hiddenKind), _hideDragSteps);

    expect(_hiddenHint, findsNothing);
    expect(find.byType(AppSheet), findsOneWidget);
    await tester.tapAt(_outsideSheetTap);
    await tester.pumpAndSettle();

    expect(find.byType(AppSheet), findsNothing);
    expect(_savedKinds(container), _seededKinds);
  }, timeout: uiTestTimeout);
}

List<OverviewWidgetKind> _savedKinds(ProviderContainer container) =>
    container.read(displayPreferencesProvider).overviewWidgets;

Future<ProviderContainer> _pumpOverview(WidgetTester tester) async {
  useShellWindow(tester, _phoneWindow);
  final ledger = Ledger(state: defaultState());
  final container = overviewContainer(
    ledger,
    preferences: DisplayPreferences(overviewWidgets: _seededKinds),
  );
  await pumpShellApp(
    tester,
    container,
    bodies: {
      ShellDestination.overview: (_) => OverviewFlow(
        onHistorySelected: _ignore,
        onBudgetsSelected: _ignore,
        onTrendsSelected: _ignore,
        onBudgetSelected: _ignoreBudget,
      ),
    },
  );
  await tester.runAsync(() => settleAnalysis(container, ledger));
  await tester.pumpAndSettle();
  return container;
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Edit Overview'));
  await tester.pumpAndSettle();
}

Finder _gripOf(OverviewWidgetKind kind) => find.descendant(
  of: find.byKey(ValueKey(kind)),
  matching: find.byIcon(Icons.drag_indicator),
);

Future<void> _dragGripDown(WidgetTester tester, Finder grip, int steps) async {
  final gesture = await tester.startGesture(tester.getCenter(grip));
  for (var step = 0; step < steps; step++) {
    await gesture.moveBy(const Offset(0, _dragStepDistance));
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void _ignore() {}

void _ignoreBudget(String budgetID) {}
