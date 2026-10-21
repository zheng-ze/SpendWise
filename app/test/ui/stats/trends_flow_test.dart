import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ui/common/inputs/month_year_selector.dart';
import 'package:spendwise/ui/common/navigation/top_tab_bar.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';
import 'package:spendwise/ui/stats/trends_flow.dart';
import 'package:spendwise/ui/stats/trends_screen.dart';
import 'package:spendwise/ui/transactions/daily_list/daily_transactions_screen.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

import '../../support/trends_ledger.dart';
import 'trends_test_support.dart';
import '../../support/ui_test_timeout.dart';

const _actionLabel = 'See more detail';
const _historyLabel = 'History';
const _iosEdgeStart = Offset(2, 300);
const _iosCompletedEdgeDrag = Offset(600, 0);
const _iosCancelledEdgeDrag = Offset(80, 0);

Future<ProviderContainer> _pumpHistory(
  WidgetTester tester, {
  bool withEntry = true,
  TargetPlatform? platform,
}) async {
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWithValue(trendsLedger(withEntry: withEntry)),
      analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        home: const TransactionsFlow(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _openTrends(WidgetTester tester) async {
  await tester.tap(find.text(_actionLabel));
  await tester.pumpAndSettle();
}

void _expectTrendsScreen(WidgetTester tester) {
  expect(find.byType(TrendsScreen), findsOneWidget);
  expect(find.text('Trends'), findsOneWidget);
  expect(find.byType(TopTabBar), findsNothing);
  expect(find.byType(MonthYearSelector), findsNothing);
  expect(find.byType(CategoryDetailScreen), findsNothing);
  expect(find.text('Income'), findsOneWidget);
  expect(find.text('Expense'), findsOneWidget);
}

void _expectHistory(WidgetTester tester) {
  expect(find.byType(TransactionsScreen), findsOneWidget);
  expect(find.byType(TrendsScreen), findsNothing);
}

void main() {
  testWidgets(
    'History opens Trends with a History back control and the fresh-ledger state',
    (tester) async {
      await _pumpHistory(tester, withEntry: false);

      await _openTrends(tester);

      _expectTrendsScreen(tester);
      expect(find.bySemanticsLabel(_historyLabel), findsOneWidget);
      expect(find.text('See where your money goes'), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('header Back returns to History and permits a fresh visit', (
    tester,
  ) async {
    await _pumpHistory(tester);
    await _openTrends(tester);

    await tester.tap(find.bySemanticsLabel(_historyLabel));
    await tester.pumpAndSettle();
    _expectHistory(tester);

    await _openTrends(tester);
    _expectTrendsScreen(tester);
  }, timeout: uiTestTimeout);

  testWidgets('system Back returns to History and permits a fresh visit', (
    tester,
  ) async {
    await _pumpHistory(tester);
    await _openTrends(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    _expectHistory(tester);

    await _openTrends(tester);
    _expectTrendsScreen(tester);
  }, timeout: uiTestTimeout);

  testWidgets('iOS edge swipe returns to History and permits a fresh visit', (
    tester,
  ) async {
    await _pumpHistory(tester, platform: TargetPlatform.iOS);
    await _openTrends(tester);

    await tester.flingFrom(_iosEdgeStart, _iosCompletedEdgeDrag, 1000);
    await tester.pumpAndSettle();
    _expectHistory(tester);

    await _openTrends(tester);
    _expectTrendsScreen(tester);
  }, timeout: uiTestTimeout);

  testWidgets('cancelled iOS edge swipe keeps Trends open', (tester) async {
    await _pumpHistory(tester, platform: TargetPlatform.iOS);
    await _openTrends(tester);

    await tester.dragFrom(_iosEdgeStart, _iosCancelledEdgeDrag);
    await tester.pumpAndSettle();

    _expectTrendsScreen(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    _expectHistory(tester);
  }, timeout: uiTestTimeout);

  testWidgets('duplicate requests install one Trends route', (tester) async {
    final container = await _pumpHistory(tester);
    final viewModel = container.read(
      transactionsViewModelProvider(null).notifier,
    );

    viewModel.requestTrends();
    viewModel.requestTrends();
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(_historyLabel));
    await tester.pumpAndSettle();

    _expectHistory(tester);
  }, timeout: uiTestTimeout);

  testWidgets('TrendsFlow without an ending callback has no back control', (
    tester,
  ) async {
    await pumpTrends(
      tester,
      ledger: trendsLedger(),
      today: DateTime.now(),
      home: const TrendsFlow(),
    );

    expect(find.byType(TrendsScreen), findsOneWidget);
    expect(find.bySemanticsLabel(_historyLabel), findsNothing);
    expect(find.byType(BackButton), findsNothing);
  }, timeout: uiTestTimeout);
}
