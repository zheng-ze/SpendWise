import 'package:domain/domain.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail_screen.dart';
import 'package:spendwise/ui/format/date_format.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final today = DateTime.now();
  DateTime day(int d) => DateTime.utc(today.year, today.month, d);

  const foodID = 'a0000000-0000-0000-0000-000000000001';
  const hawkerID = 'a0000000-0000-0000-0000-000000000002';
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

  final transport = TransactionCategory(
    id: transportID,
    name: 'Transport',
    kind: CategoryKind.expense,
    colorHex: '#0000AA',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'directions_bus',
  );

  Budget budget({String? categoryID, String id = 'b1'}) {
    return Budget(
      id: id,
      categoryID: categoryID,
      limitEvents: [
        LimitEvent(
          effectiveFromMonth: null,
          value: dec('100'),
          kind: LimitEventKind.defaultLimit,
        ),
      ],
      createdAtMonth: const YearMonth(2026, 1),
    );
  }

  Ledger buildLedger({
    Map<String, Entry> entries = const {},
    required Budget forBudget,
  }) {
    return Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        categories: {foodID: food, hawkerID: hawker, transportID: transport},
        entries: entries,
        budgets: {forBudget.id: forBudget},
      ),
    );
  }

  overridesFor(Ledger ledger) => [
    ledgerProvider.overrideWithValue(ledger),
    analysisCacheProvider.overrideWith(
      (ref) => AnalysisCache(runner: syncComputeRunner),
    ),
  ];

  Future<void> pumpDetail(WidgetTester tester, Ledger ledger, Budget b) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(ledger),
        child: MaterialApp(home: BudgetDetailScreen(budget: b)),
      ),
    );
  }

  testWidgets(
    'a category budget scopes entries to that category and its children',
    (tester) async {
      final foodBudget = budget(categoryID: foodID, id: 'b1');
      final hawkerEntry = Entry(
        amount: dec('-10'),
        name: 'Noodles',
        sourceID: account.id,
        categoryID: hawkerID,
        date: day(1),
      );
      final transportEntry = Entry(
        amount: dec('-5'),
        name: 'Bus',
        sourceID: account.id,
        categoryID: transportID,
        date: day(1),
      );
      final ledger = buildLedger(
        entries: {
          hawkerEntry.id: hawkerEntry,
          transportEntry.id: transportEntry,
        },
        forBudget: foodBudget,
      );

      await pumpDetail(tester, ledger, foodBudget);
      await tester.pumpAndSettle();

      expect(find.text('Noodles'), findsOneWidget);
      expect(find.text('Bus'), findsNothing);
    },
  );

  testWidgets(
    'an overall budget scopes entries to every expense, including uncategorized',
    (tester) async {
      final overallBudget = budget(categoryID: null, id: 'b2');
      final uncategorized = Entry(
        amount: dec('-7'),
        name: 'Misc',
        sourceID: account.id,
        date: day(1),
      );
      final ledger = buildLedger(
        entries: {uncategorized.id: uncategorized},
        forBudget: overallBudget,
      );

      await pumpDetail(tester, ledger, overallBudget);
      await tester.pumpAndSettle();

      expect(find.text('Misc'), findsOneWidget);
    },
  );

  testWidgets(
    'the header reflects the current month\'s effective limit, override included',
    (tester) async {
      final now = DateTime.now().toUtc();
      final overridden = budget(categoryID: null, id: 'b4');
      final withOverride = Budget(
        id: overridden.id,
        categoryID: overridden.categoryID,
        limitEvents: [
          ...overridden.limitEvents,
          LimitEvent(
            effectiveFromMonth: YearMonth(now.year, now.month),
            value: dec('250'),
            kind: LimitEventKind.override,
          ),
        ],
        createdAtMonth: overridden.createdAtMonth,
      );
      final ledger = buildLedger(forBudget: withOverride);

      await pumpDetail(tester, ledger, withOverride);
      await tester.pumpAndSettle();

      expect(find.textContaining('of \$250.00'), findsOneWidget);
    },
  );

  testWidgets('income entries never appear in a budget\'s entry list', (
    tester,
  ) async {
    final overallBudget = budget(categoryID: null, id: 'b3');
    final salary = Entry(
      amount: dec('1000'),
      name: 'Salary',
      sourceID: account.id,
      date: day(1),
    );
    final ledger = buildLedger(
      entries: {salary.id: salary},
      forBudget: overallBudget,
    );

    await pumpDetail(tester, ledger, overallBudget);
    await tester.pumpAndSettle();

    expect(find.text('Salary'), findsNothing);
    expect(find.text('No entries in this period'), findsOneWidget);
  });

  testWidgets(
    'the chart shows all twelve months of the current year, not a six-month window',
    (tester) async {
      final overallBudget = budget(categoryID: null, id: 'b5');
      final ledger = buildLedger(forBudget: overallBudget);

      await pumpDetail(tester, ledger, overallBudget);
      await tester.pumpAndSettle();

      final now = DateTime.now().toUtc();
      expect(find.text(now.year.toString()), findsOneWidget);
    },
  );

  testWidgets(
    'selecting a month filters the entry list without changing the displayed year',
    (tester) async {
      final overallBudget = budget(categoryID: null, id: 'b6');
      final ledger = buildLedger(forBudget: overallBudget);

      await pumpDetail(tester, ledger, overallBudget);
      await tester.pumpAndSettle();

      final now = DateTime.now().toUtc();
      final yearBefore = now.year.toString();
      expect(find.text(yearBefore), findsOneWidget);

      await tester.tap(find.byType(BarChart));
      await tester.pumpAndSettle();

      expect(find.text(yearBefore), findsOneWidget);
    },
  );

  testWidgets('a month with no spend is still tappable and becomes selected', (
    tester,
  ) async {
    final overallBudget = budget(categoryID: null, id: 'b7');
    final ledger = buildLedger(forBudget: overallBudget);

    await pumpDetail(tester, ledger, overallBudget);
    await tester.pumpAndSettle();

    final now = DateTime.now().toUtc();
    // Must differ from the already-selected month, or the tap is a no-op.
    final targetMonth = now.month == 1 ? 12 : 1;
    final chart = tester.getRect(find.byType(BarChart));
    final targetX = chart.left + chart.width * (targetMonth - 0.5) / 12;
    await tester.tapAt(Offset(targetX, chart.center.dy));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        formatMonthLabel(DateTime.utc(now.year, targetMonth)).toUpperCase(),
      ),
      findsOneWidget,
    );
  });

  testWidgets('changing the year keeps the same selected month', (
    tester,
  ) async {
    final overallBudget = budget(categoryID: null, id: 'b8');
    final ledger = buildLedger(forBudget: overallBudget);

    await pumpDetail(tester, ledger, overallBudget);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    final now = DateTime.now().toUtc();
    expect(
      find.textContaining(
        formatMonthLabel(DateTime.utc(now.year + 1, now.month)).toUpperCase(),
      ),
      findsOneWidget,
    );
  });
}
