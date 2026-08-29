import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/stats/stats_flow.dart';
import 'package:spendwise/ui/stats/stats_window.dart';

// A single-category window can show the same figure in the legend row, so
// this scopes the match to the AmountHeader that renders the total line.
Finder totalAmountText(String text) =>
    find.descendant(of: find.byType(AmountHeader), matching: find.text(text));

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final account = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );

  final food = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000001',
    name: 'Food',
    kind: CategoryKind.expense,
    colorHex: '#00AA00',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'restaurant',
  );

  final hawker = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000002',
    name: 'Hawker',
    kind: CategoryKind.expense,
    colorHex: '#00BB00',
    includeInAnalysis: true,
    parentID: food.id,
    symbol: 'set_meal',
  );

  Budget budget({String? categoryID, required String id}) {
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

  Future<void> pumpScreen(
    WidgetTester tester,
    Ledger ledger, {
    DateTime? selectedDate,
  }) async {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        analysisCacheProvider.overrideWith(
          (ref) => AnalysisCache(runner: syncComputeRunner),
        ),
        if (selectedDate != null)
          selectedMonthProvider.overrideWith((ref) => selectedDate),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StatsFlow()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Entry expenseEntry(
    String name,
    String amount,
    DateTime date, {
    String? categoryID,
  }) {
    return Entry(
      amount: dec(amount),
      name: name,
      sourceID: account.id,
      categoryID: categoryID,
      date: date,
    );
  }

  testWidgets('defaults to the Expense tab', (tester) async {
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
      ),
    );

    await pumpScreen(tester, ledger, selectedDate: DateTime.utc(2026, 3));

    expect(find.text('No expense in this period'), findsOneWidget);
  });

  testWidgets('total line sums the window\'s items for the active kind', (
    tester,
  ) async {
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        categories: {food.id: food},
        entries: {
          for (final e in [
            expenseEntry(
              'Lunch',
              '-10',
              DateTime.utc(2026, 3, 5),
              categoryID: food.id,
            ),
            expenseEntry(
              'Dinner',
              '-15',
              DateTime.utc(2026, 3, 10),
              categoryID: food.id,
            ),
          ])
            e.id: e,
        },
      ),
    );

    await pumpScreen(tester, ledger, selectedDate: DateTime.utc(2026, 3));

    expect(totalAmountText('\$25.00'), findsOneWidget);
  });

  testWidgets('switching to Annually widens the window to the whole year', (
    tester,
  ) async {
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        categories: {food.id: food},
        entries: {
          for (final e in [
            expenseEntry(
              'March',
              '-10',
              DateTime.utc(2026, 3, 5),
              categoryID: food.id,
            ),
            expenseEntry(
              'July',
              '-15',
              DateTime.utc(2026, 7, 5),
              categoryID: food.id,
            ),
          ])
            e.id: e,
        },
      ),
    );

    await pumpScreen(tester, ledger, selectedDate: DateTime.utc(2026, 3));
    expect(totalAmountText('\$10.00'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annually'));
    await tester.pumpAndSettle();

    expect(totalAmountText('\$25.00'), findsOneWidget);
  });

  testWidgets('an empty window shows the empty state', (tester) async {
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
      ),
    );

    await pumpScreen(tester, ledger, selectedDate: DateTime.utc(2026, 3));

    expect(find.text('No expense in this period'), findsOneWidget);
  });

  testWidgets('the Budgets tab groups a subcategory budget next to its '
      'parent, indented and sorted', (tester) async {
    final parentBudget = budget(categoryID: food.id, id: 'b1');
    final childBudget = budget(categoryID: hawker.id, id: 'b2');
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        categories: {food.id: food, hawker.id: hawker},
        budgets: {parentBudget.id: parentBudget, childBudget.id: childBudget},
      ),
    );

    await pumpScreen(tester, ledger, selectedDate: DateTime.utc(2026, 3));
    await tester.tap(find.text('Budgets'));
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Hawker'), findsOneWidget);

    final foodCenter = tester.getCenter(find.text('Food'));
    final hawkerCenter = tester.getCenter(find.text('Hawker'));
    expect(foodCenter.dy, lessThan(hawkerCenter.dy));
    expect(hawkerCenter.dx, greaterThan(foodCenter.dx));
  });
}
