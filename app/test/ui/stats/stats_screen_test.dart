import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/stats/stats_screen.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final today = DateTime.now();
  DateTime day(int d) => DateTime.utc(today.year, today.month, d);

  const groceriesID = 'a0000000-0000-0000-0000-000000000001';

  final account = Account(
    id: 'a0000000-0000-0000-0000-000000000010',
    name: 'Checking',
    type: AccountType.checking,
  );

  const transportID = 'a0000000-0000-0000-0000-000000000002';

  final groceries = TransactionCategory(
    id: groceriesID,
    name: 'Groceries',
    kind: CategoryKind.expense,
    colorHex: '#00AA00',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'shopping_cart',
  );

  final transport = TransactionCategory(
    id: transportID,
    name: 'Transport',
    kind: CategoryKind.expense,
    colorHex: '#0000AA',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'directions_bus',
  );

  Ledger buildLedger({Map<String, Entry> entries = const {}}) {
    return Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        categories: {groceriesID: groceries, transportID: transport},
        entries: entries,
      ),
    );
  }

  Future<void> pumpScreen(WidgetTester tester, Ledger ledger) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          ledgerProvider.overrideWithValue(ledger),
          // This screen refreshes the cache during pump, and a spawned isolate
          // can't see the test zone's fake-async state, so use a synchronous runner.
          analysisCacheProvider.overrideWith(
            (ref) => AnalysisCache(runner: syncComputeRunner),
          ),
        ],
        child: const MaterialApp(home: StatsScreen()),
      ),
    );
  }

  testWidgets(
    'reflects a month set on selectedMonthProvider from outside the screen',
    (tester) async {
      final ledger = buildLedger();
      final container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWithValue(ledger),
          analysisCacheProvider.overrideWith(
            (ref) => AnalysisCache(runner: syncComputeRunner),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: StatsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      container.read(selectedMonthProvider.notifier).state = DateTime.utc(
        2019,
        3,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(formatMonthLabel(DateTime.utc(2019, 3))),
        findsOneWidget,
      );
    },
  );

  testWidgets('defaults to the expense tab', (tester) async {
    final ledger = buildLedger();
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    expect(find.text('Total expenses'), findsOneWidget);
    expect(find.text('Total income'), findsNothing);
  });

  testWidgets('the total line sums the window\'s items for the active kind', (
    tester,
  ) async {
    final first = Entry(
      amount: dec('-25'),
      name: 'Weekly shop',
      sourceID: account.id,
      categoryID: groceriesID,
      date: day(1),
    );
    final second = Entry(
      amount: dec('-15'),
      name: 'Bus fare',
      sourceID: account.id,
      categoryID: transportID,
      date: day(2),
    );
    final ledger = buildLedger(entries: {first.id: first, second.id: second});
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    expect(find.text('\$40.00'), findsOneWidget);
    expect(find.text('\$25.00'), findsOneWidget);
    expect(find.text('\$15.00'), findsOneWidget);
  });

  testWidgets(
    'switching the range menu to Annually widens the window and steps by year',
    (tester) async {
      final lastMonth = shiftMonthThenClampDayUtc(day(1), -2, day: 1);
      final outsideThisMonth = Entry(
        amount: dec('-40'),
        name: 'Old grocery run',
        sourceID: account.id,
        categoryID: groceriesID,
        date: lastMonth,
      );
      final alsoOutsideThisMonth = Entry(
        amount: dec('-10'),
        name: 'Old bus fare',
        sourceID: account.id,
        categoryID: transportID,
        date: lastMonth,
      );
      final ledger = buildLedger(
        entries: {
          outsideThisMonth.id: outsideThisMonth,
          alsoOutsideThisMonth.id: alsoOutsideThisMonth,
        },
      );
      await pumpScreen(tester, ledger);
      await tester.pumpAndSettle();

      expect(find.text('\$0.00'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<StatsRangeMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annually'));
      await tester.pumpAndSettle();

      expect(find.text('\$50.00'), findsOneWidget);
      expect(find.text(formatYearLabel(today)), findsOneWidget);
    },
  );

  testWidgets('empty window shows the empty state with a zero total', (
    tester,
  ) async {
    final ledger = buildLedger();
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    expect(find.text('\$0.00'), findsOneWidget);
    expect(find.text('No expense in this period'), findsOneWidget);
    expect(find.byIcon(Icons.pie_chart_outline), findsOneWidget);
  });

  testWidgets(
    'the Budgets tab groups a subcategory budget next to its parent, indented',
    (tester) async {
      const produceID = 'a0000000-0000-0000-0000-000000000003';
      final produce = TransactionCategory(
        id: produceID,
        name: 'Produce',
        kind: CategoryKind.expense,
        colorHex: '#00AA00',
        includeInAnalysis: true,
        parentID: groceriesID,
        symbol: 'shopping_cart',
      );
      final transportBudget = Budget(
        id: 'b1',
        categoryID: transportID,
        limitEvents: [
          LimitEvent(
            effectiveFromMonth: null,
            value: dec('100'),
            kind: LimitEventKind.defaultLimit,
          ),
        ],
        rolloverMode: RolloverMode.none,
        carryCap: null,
        createdAtMonth: const YearMonth(2026, 1),
      );
      final produceBudget = Budget(
        id: 'b2',
        categoryID: produceID,
        limitEvents: [
          LimitEvent(
            effectiveFromMonth: null,
            value: dec('50'),
            kind: LimitEventKind.defaultLimit,
          ),
        ],
        rolloverMode: RolloverMode.none,
        carryCap: null,
        createdAtMonth: const YearMonth(2026, 1),
      );
      final ledger = Ledger(
        state: LedgerState(
          moneySources: {account.id: MoneySource.account(account)},
          categories: {
            groceriesID: groceries,
            transportID: transport,
            produceID: produce,
          },
          budgets: {
            transportBudget.id: transportBudget,
            produceBudget.id: produceBudget,
          },
        ),
      );

      await pumpScreen(tester, ledger);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Budgets'));
      await tester.pumpAndSettle();

      // Produce (Groceries' child, no budget on Groceries itself) sorts
      // ahead of Transport, since it groups under "Groceries" < "Transport".
      final produceCenter = tester.getCenter(find.text('Produce'));
      final transportCenter = tester.getCenter(find.text('Transport'));
      expect(produceCenter.dy, lessThan(transportCenter.dy));

      // The subcategory card is indented relative to the top-level one.
      final produceLeft = tester.getTopLeft(find.text('Produce')).dx;
      final transportLeft = tester.getTopLeft(find.text('Transport')).dx;
      expect(produceLeft, greaterThan(transportLeft));
    },
  );
}
