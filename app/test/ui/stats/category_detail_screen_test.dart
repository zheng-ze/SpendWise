import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/stats/category_detail_screen.dart';
import 'package:spendwise/ui/stats/stats_screen.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final today = DateTime.now();
  DateTime day(int d) => DateTime.utc(today.year, today.month, d);
  final thisMonth = DateTime.utc(today.year, today.month);

  const foodID = 'a0000000-0000-0000-0000-000000000001';
  const hawkerID = 'a0000000-0000-0000-0000-000000000002';
  const cafeID = 'a0000000-0000-0000-0000-000000000003';
  const transportID = 'a0000000-0000-0000-0000-000000000004';

  final account = Account(
    id: 'a0000000-0000-0000-0000-000000000010',
    name: 'Checking',
    type: AccountType.checking,
  );

  final food = TransactionCategory(
    id: foodID,
    name: 'Food',
    kind: CategoryKind.expense,
    colorHex: '#00AA00',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'restaurant',
  );

  final hawker = TransactionCategory(
    id: hawkerID,
    name: 'Hawker',
    kind: CategoryKind.expense,
    colorHex: '#00BB00',
    includeInAnalysis: true,
    parentID: foodID,
    symbol: 'set_meal',
  );

  final cafe = TransactionCategory(
    id: cafeID,
    name: 'Cafe',
    kind: CategoryKind.expense,
    colorHex: '#00CC00',
    includeInAnalysis: true,
    parentID: foodID,
    symbol: 'local_cafe',
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
        categories: {
          foodID: food,
          hawkerID: hawker,
          cafeID: cafe,
          transportID: transport,
        },
        entries: entries,
      ),
    );
  }

  // The isolate runner sends its closure to a spawned isolate, which the
  // test zone's captured state cannot cross. The sync runner is the seam
  // AnalysisCache exposes for this.
  overridesFor(Ledger ledger) => [
    ledgerProvider.overrideWithValue(ledger),
    analysisCacheProvider.overrideWith(
      (ref) => AnalysisCache(runner: syncComputeRunner),
    ),
  ];

  Future<void> pumpDetail(
    WidgetTester tester,
    Ledger ledger, {
    String mainID = foodID,
    DateTime? initialDate,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(ledger),
        child: MaterialApp(
          home: CategoryDetailScreen(
            mainID: mainID,
            kind: CategoryKind.expense,
            isYearRange: false,
            initialDate: initialDate ?? thisMonth,
          ),
        ),
      ),
    );
  }

  testWidgets('title is the main category name', (tester) async {
    final ledger = buildLedger();
    await pumpDetail(tester, ledger);
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsWidgets);
  });

  testWidgets('range is inherited fixed: no range control is rendered', (
    tester,
  ) async {
    final ledger = buildLedger();
    await pumpDetail(tester, ledger);
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuButton<StatsRangeMode>), findsNothing);
  });

  testWidgets('date changes in the detail screen do not affect the parent', (
    tester,
  ) async {
    final ledger = buildLedger();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(ledger),
        child: const MaterialApp(home: StatsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final buildContext = tester.element(find.byType(StatsScreen));
    await tester.runAsync(() async {});
    Navigator.of(buildContext).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryDetailScreen(
          mainID: foodID,
          kind: CategoryKind.expense,
          isYearRange: false,
          initialDate: thisMonth,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(StatsScreen), findsOneWidget);
  });

  group('subcategory table', () {
    testWidgets('the "All Food" row is always first and always 100%', (
      tester,
    ) async {
      final hawkerEntry = Entry(
        amount: dec('-10'),
        name: 'Lunch',
        sourceID: account.id,
        categoryID: hawkerID,
        date: day(1),
      );
      final cafeEntry = Entry(
        amount: dec('-5'),
        name: 'Coffee',
        sourceID: account.id,
        categoryID: cafeID,
        date: day(2),
      );
      final ledger = buildLedger(
        entries: {hawkerEntry.id: hawkerEntry, cafeEntry.id: cafeEntry},
      );
      await pumpDetail(tester, ledger);
      await tester.pumpAndSettle();

      expect(find.text('All Food'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('direct row appears when spending is logged on the parent', (
      tester,
    ) async {
      final directEntry = Entry(
        amount: dec('-20'),
        name: 'Groceries misc',
        sourceID: account.id,
        categoryID: foodID,
        date: day(1),
      );
      final hawkerEntry = Entry(
        amount: dec('-10'),
        name: 'Lunch',
        sourceID: account.id,
        categoryID: hawkerID,
        date: day(2),
      );
      final ledger = buildLedger(
        entries: {directEntry.id: directEntry, hawkerEntry.id: hawkerEntry},
      );
      await pumpDetail(tester, ledger);
      await tester.pumpAndSettle();

      expect(find.text('Direct'), findsOneWidget);
    });

    testWidgets('no direct row when every entry sits on a child', (
      tester,
    ) async {
      final hawkerEntry = Entry(
        amount: dec('-10'),
        name: 'Lunch',
        sourceID: account.id,
        categoryID: hawkerID,
        date: day(1),
      );
      final cafeEntry = Entry(
        amount: dec('-5'),
        name: 'Coffee',
        sourceID: account.id,
        categoryID: cafeID,
        date: day(2),
      );
      final ledger = buildLedger(
        entries: {hawkerEntry.id: hawkerEntry, cafeEntry.id: cafeEntry},
      );
      await pumpDetail(tester, ledger);
      await tester.pumpAndSettle();

      expect(find.text('Direct'), findsNothing);
    });

    testWidgets('direct row ranks by amount among the children', (
      tester,
    ) async {
      final hawkerEntry = Entry(
        amount: dec('-40'),
        name: 'Lunch',
        sourceID: account.id,
        categoryID: hawkerID,
        date: day(1),
      );
      final cafeEntry = Entry(
        amount: dec('-5'),
        name: 'Coffee',
        sourceID: account.id,
        categoryID: cafeID,
        date: day(2),
      );
      final directEntry = Entry(
        amount: dec('-30'),
        name: 'Misc',
        sourceID: account.id,
        categoryID: foodID,
        date: day(3),
      );
      final ledger = buildLedger(
        entries: {
          hawkerEntry.id: hawkerEntry,
          cafeEntry.id: cafeEntry,
          directEntry.id: directEntry,
        },
      );
      await pumpDetail(tester, ledger);
      await tester.pumpAndSettle();

      final hawkerCenter = tester.getCenter(find.text('Hawker'));
      final directCenter = tester.getCenter(find.text('Direct'));
      final cafeCenter = tester.getCenter(find.text('Cafe'));

      expect(hawkerCenter.dy, lessThan(directCenter.dy));
      expect(directCenter.dy, lessThan(cafeCenter.dy));
    });

    testWidgets('tapping a subcategory row changes the scope total', (
      tester,
    ) async {
      final hawkerEntry = Entry(
        amount: dec('-10'),
        name: 'Lunch',
        sourceID: account.id,
        categoryID: hawkerID,
        date: day(1),
      );
      final cafeEntry = Entry(
        amount: dec('-5'),
        name: 'Coffee',
        sourceID: account.id,
        categoryID: cafeID,
        date: day(2),
      );
      final ledger = buildLedger(
        entries: {hawkerEntry.id: hawkerEntry, cafeEntry.id: cafeEntry},
      );
      await pumpDetail(tester, ledger);
      await tester.pumpAndSettle();

      // Whole-category total is $15, shown once for the total and once for
      // the "All Food" row.
      expect(find.text('\$15.00'), findsNWidgets(2));

      await tester.tap(find.text('Hawker'));
      await tester.pumpAndSettle();

      expect(find.text('Food › Hawker'), findsOneWidget);
      expect(find.text('\$10.00'), findsWidgets);
    });
  });

  group('scoped entry list', () {
    testWidgets('rescoping to a subcategory narrows the visible entries', (
      tester,
    ) async {
      final hawkerEntry = Entry(
        amount: dec('-10'),
        name: 'Lunch at hawker',
        sourceID: account.id,
        categoryID: hawkerID,
        date: day(1),
      );
      final cafeEntry = Entry(
        amount: dec('-5'),
        name: 'Coffee run',
        sourceID: account.id,
        categoryID: cafeID,
        date: day(2),
      );
      final ledger = buildLedger(
        entries: {hawkerEntry.id: hawkerEntry, cafeEntry.id: cafeEntry},
      );
      await pumpDetail(tester, ledger);
      await tester.pumpAndSettle();

      // The entry list sits below the trend chart, so it may render offstage
      // in the test surface without the list ever being scrolled.
      Finder entryText(String text) => find.text(text, skipOffstage: false);

      expect(entryText('Lunch at hawker'), findsOneWidget);
      expect(entryText('Coffee run'), findsOneWidget);

      await tester.tap(find.text('Hawker'));
      await tester.pumpAndSettle();

      expect(entryText('Lunch at hawker'), findsOneWidget);
      expect(entryText('Coffee run'), findsNothing);
    });

    testWidgets('direct scope excludes children entries', (tester) async {
      final directEntry = Entry(
        amount: dec('-20'),
        name: 'Misc food buy',
        sourceID: account.id,
        categoryID: foodID,
        date: day(1),
      );
      final hawkerEntry = Entry(
        amount: dec('-10'),
        name: 'Lunch at hawker',
        sourceID: account.id,
        categoryID: hawkerID,
        date: day(2),
      );
      final ledger = buildLedger(
        entries: {directEntry.id: directEntry, hawkerEntry.id: hawkerEntry},
      );
      await pumpDetail(tester, ledger);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Direct'));
      await tester.pumpAndSettle();

      expect(find.text('Misc food buy', skipOffstage: false), findsOneWidget);
      expect(find.text('Lunch at hawker', skipOffstage: false), findsNothing);
    });
  });

  testWidgets('tapping a legend row in StatsScreen pushes the detail screen', (
    tester,
  ) async {
    final hawkerEntry = Entry(
      amount: dec('-10'),
      name: 'Lunch',
      sourceID: account.id,
      categoryID: hawkerID,
      date: day(1),
    );
    final ledger = buildLedger(entries: {hawkerEntry.id: hawkerEntry});
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(ledger),
        child: const MaterialApp(home: StatsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryDetailScreen), findsOneWidget);
  });

  group('trend card', () {
    testWidgets('renders month labels for a January selection', (tester) async {
      final ledger = buildLedger();
      await pumpDetail(
        tester,
        ledger,
        initialDate: DateTime.utc(today.year, 1),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('trend'), findsOneWidget);
      expect(find.textContaining('last 6 months'), findsOneWidget);
    });

    testWidgets('tapping a point shows that month\'s amount in the header', (
      tester,
    ) async {
      final entry = Entry(
        amount: dec('-10'),
        name: 'Lunch',
        sourceID: account.id,
        categoryID: hawkerID,
        date: day(1),
      );
      final ledger = buildLedger(entries: {entry.id: entry});
      await pumpDetail(tester, ledger);
      await tester.pumpAndSettle();

      expect(find.textContaining('last 6 months'), findsOneWidget);

      final chart = find.byKey(const ValueKey('categoryDetailTrendChart'));
      expect(chart, findsOneWidget);

      final center = tester.getCenter(chart);
      final gesture = await tester.startGesture(center);
      await tester.pump();
      await gesture.moveBy(const Offset(1, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.textContaining('last 6 months'), findsNothing);
    });
  });
}
