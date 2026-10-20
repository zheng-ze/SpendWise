import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ui/common/navigation/top_tab_bar.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';
import 'package:spendwise/ui/stats/stats_root_screen.dart';
import 'package:spendwise/ui/stats/stats_root_view_model.dart';
import 'package:spendwise/ui/transactions/daily_list/daily_transactions_screen.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';
import 'package:spendwise/ui/transactions/trends_detail_action.dart';

import '../../support/trends_ledger.dart';
import '../../support/ui_test_timeout.dart';

const _actionFinderLabel = 'See more detail';
const _historyBackLabel = 'History';
const _edgeSwipeStart = Offset(2, 300);
const _edgeSwipeDelta = Offset(600, 0);
const _hitInsideEdge = 2.0;
Future<ProviderContainer> _pumpHistory(
  WidgetTester tester, {
  bool withEntry = true,
  Widget Function(Widget flow)? wrap,
  TargetPlatform? platform,
  TransactionsScope? scope,
}) async {
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWithValue(trendsLedger(withEntry: withEntry)),
      analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
    ],
  );
  addTearDown(container.dispose);
  final flow = wrap == null
      ? TransactionsFlow(initialScope: scope)
      : wrap(TransactionsFlow(initialScope: scope));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        home: flow,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _openTrends(WidgetTester tester) async {
  await tester.tap(find.text(_actionFinderLabel));
  await tester.pumpAndSettle();
}

Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

Future<void> _switchToIncome(WidgetTester tester) async {
  await tester.tap(find.text('Income'));
  await tester.pumpAndSettle();
}

void _expectHistoryRoot() {
  expect(find.byType(TransactionsScreen), findsOneWidget);
  expect(find.byType(StatsRootScreen), findsNothing);
}

void main() {
  group('action', () {
    testWidgets('unscoped History shows it with button semantics', (
      tester,
    ) async {
      await _pumpHistory(tester);

      final semantics = tester.getSemantics(find.byType(TrendsDetailAction));
      expect(find.text(_actionFinderLabel), findsOneWidget);
      expect(semantics.label, _actionFinderLabel);
      expect(semantics.flagsCollection.isButton, isTrue);
    }, timeout: uiTestTimeout);

    testWidgets('a month with no entries still shows it', (tester) async {
      await _pumpHistory(tester, withEntry: false);

      expect(find.text(_actionFinderLabel), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('scoped lists show no action', (tester) async {
      const scope = TransactionsScope(
        title: 'Checking',
        scopeIDs: {trendsSourceID},
      );
      await _pumpHistory(tester, scope: scope);

      expect(find.text(_actionFinderLabel), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('its invisible hit region is 48 px tall and tappable', (
      tester,
    ) async {
      await _pumpHistory(tester);
      final rect = tester.getRect(find.byType(TrendsDetailAction));

      expect(rect.height, trendsDetailActionHitHeight);
      await tester.tapAt(rect.topCenter + const Offset(0, _hitInsideEdge));
      await tester.pumpAndSettle();

      expect(find.byType(StatsRootScreen), findsOneWidget);
    }, timeout: uiTestTimeout);
  });

  group('Trends route', () {
    testWidgets('opens with a back control labelled History', (tester) async {
      await _pumpHistory(tester);

      await _openTrends(tester);

      expect(find.byType(StatsRootScreen), findsOneWidget);
      expect(find.bySemanticsLabel(_historyBackLabel), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('the back control returns to History', (tester) async {
      await _pumpHistory(tester);
      await _openTrends(tester);

      await tester.tap(find.bySemanticsLabel(_historyBackLabel));
      await tester.pumpAndSettle();

      _expectHistoryRoot();
    }, timeout: uiTestTimeout);

    testWidgets('system Back returns to History', (tester) async {
      await _pumpHistory(tester);
      await _openTrends(tester);

      await _systemBack(tester);

      _expectHistoryRoot();
    }, timeout: uiTestTimeout);

    testWidgets('system Back still works after the Income switch', (
      tester,
    ) async {
      await _pumpHistory(tester);
      await _openTrends(tester);
      await _switchToIncome(tester);

      await _systemBack(tester);

      _expectHistoryRoot();
    }, timeout: uiTestTimeout);

    testWidgets('an iOS edge swipe returns to History, also after Income', (
      tester,
    ) async {
      await _pumpHistory(tester, platform: TargetPlatform.iOS);
      await _openTrends(tester);
      await _switchToIncome(tester);

      await tester.flingFrom(_edgeSwipeStart, _edgeSwipeDelta, 1000);
      await tester.pumpAndSettle();

      _expectHistoryRoot();
    }, timeout: uiTestTimeout);

    testWidgets('a duplicate request installs one route', (tester) async {
      final container = await _pumpHistory(tester);
      final viewModel = container.read(
        transactionsViewModelProvider(null).notifier,
      );

      viewModel.requestTrends();
      viewModel.requestTrends();
      await tester.pumpAndSettle();
      await _systemBack(tester);

      _expectHistoryRoot();
    }, timeout: uiTestTimeout);

    testWidgets('each fresh visit starts on Expense and Monthly', (
      tester,
    ) async {
      final container = await _pumpHistory(tester);
      await _openTrends(tester);
      await _switchToIncome(tester);
      container
          .read(statsRootViewModelProvider.notifier)
          .setRange(StatsRangeMode.year);
      await _systemBack(tester);

      await _openTrends(tester);

      final state = container.read(statsRootViewModelProvider);
      expect(state.tab, StatsTab.expense);
      expect(state.range, StatsRangeMode.month);
    }, timeout: uiTestTimeout);

    testWidgets('a fresh visit seeds the month from History date', (
      tester,
    ) async {
      final container = await _pumpHistory(tester);
      final march = DateTime.utc(2025, 3, 17);
      container
          .read(transactionsViewModelProvider(null).notifier)
          .setDate(march);
      await tester.pumpAndSettle();

      await _openTrends(tester);

      expect(container.read(effectiveMonthProvider), DateTime.utc(2025, 3));
    }, timeout: uiTestTimeout);

    testWidgets('category detail Back returns to Trends, then History', (
      tester,
    ) async {
      await _pumpHistory(tester);
      await _openTrends(tester);

      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryDetailScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(StatsRootScreen), findsOneWidget);
      expect(find.byType(TopTabBar), findsOneWidget);

      await _systemBack(tester);
      _expectHistoryRoot();
    }, timeout: uiTestTimeout);

    testWidgets('system Back and an iOS swipe step category detail, Trends, '
        'History', (tester) async {
      await _pumpHistory(tester, platform: TargetPlatform.iOS);
      await _openTrends(tester);
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      await _systemBack(tester);
      expect(find.byType(CategoryDetailScreen), findsNothing);
      expect(find.byType(StatsRootScreen), findsOneWidget);

      await tester.dragFrom(_edgeSwipeStart, _edgeSwipeDelta);
      await tester.pumpAndSettle();
      _expectHistoryRoot();
    }, timeout: uiTestTimeout);

    testWidgets('iOS swipes step category detail, Trends, History', (
      tester,
    ) async {
      await _pumpHistory(tester, platform: TargetPlatform.iOS);
      await _openTrends(tester);
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryDetailScreen), findsOneWidget);

      await tester.dragFrom(_edgeSwipeStart, _edgeSwipeDelta);
      await tester.pumpAndSettle();
      expect(find.byType(CategoryDetailScreen), findsNothing);
      expect(find.byType(StatsRootScreen), findsOneWidget);

      await tester.dragFrom(_edgeSwipeStart, _edgeSwipeDelta);
      await tester.pumpAndSettle();
      _expectHistoryRoot();
    }, timeout: uiTestTimeout);

    testWidgets('survives the flow being hidden behind another page', (
      tester,
    ) async {
      final hidden = ValueNotifier<bool>(false);
      addTearDown(hidden.dispose);
      await _pumpHistory(
        tester,
        wrap: (flow) => _Hideable(hidden: hidden, flow: flow),
      );
      await _openTrends(tester);
      await _switchToIncome(tester);

      hidden.value = true;
      await tester.pumpAndSettle();
      hidden.value = false;
      await tester.pumpAndSettle();

      expect(find.byType(StatsRootScreen), findsOneWidget);
      expect(tester.widget<TopTabBar>(find.byType(TopTabBar)).selectedIndex, 0);
    }, timeout: uiTestTimeout);
  });
}

class _Hideable extends StatelessWidget {
  const _Hideable({required this.hidden, required this.flow});

  final ValueNotifier<bool> hidden;
  final Widget flow;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: hidden,
      builder: (_, isHidden, _) => IndexedStack(
        index: isHidden ? 1 : 0,
        children: [flow, const SizedBox()],
      ),
    );
  }
}
