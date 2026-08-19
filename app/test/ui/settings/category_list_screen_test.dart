import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/category_list_screen.dart';

import '../../support/semantics_test_support.dart';

void main() {
  final food = TransactionCategory(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Food',
    kind: CategoryKind.expense,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'restaurant',
  );
  final snacks = TransactionCategory(
    id: 'a0000000-0000-0000-0000-000000000002',
    name: 'Snacks',
    kind: CategoryKind.expense,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: food.id,
    symbol: 'cake',
  );
  final gifts = TransactionCategory(
    id: 'a0000000-0000-0000-0000-000000000003',
    name: 'Gifts',
    kind: CategoryKind.expense,
    colorHex: '#00FF00',
    includeInAnalysis: false,
    parentID: null,
    symbol: 'redeem',
  );
  final salary = TransactionCategory(
    id: 'a0000000-0000-0000-0000-000000000004',
    name: 'Salary',
    kind: CategoryKind.income,
    colorHex: '#0000FF',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'payments',
  );

  Ledger buildLedger({
    List<TransactionCategory> categories = const [],
    Map<String, Entry> entries = const {},
  }) {
    return Ledger(
      state: LedgerState(
        categories: {for (final c in categories) c.id: c},
        entries: entries,
      ),
    );
  }

  Future<void> pumpScreen(WidgetTester tester, Ledger ledger) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [ledgerProvider.overrideWithValue(ledger)],
        child: const MaterialApp(home: CategoryListScreen()),
      ),
    );
  }

  testWidgets('sections show empty text when there are no categories', (
    tester,
  ) async {
    final ledger = buildLedger();
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    expect(find.text('No categories yet'), findsNWidgets(2));
  });

  testWidgets('roots list alphabetically, each followed by its own children', (
    tester,
  ) async {
    final ledger = buildLedger(categories: [snacks, food, gifts]);
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    final foodCenter = tester.getCenter(find.text('Food'));
    final snacksCenter = tester.getCenter(find.text('Snacks'));
    final giftsCenter = tester.getCenter(find.text('Gifts'));

    expect(foodCenter.dy, lessThan(giftsCenter.dy));
    expect(snacksCenter.dy, greaterThan(foodCenter.dy));
    expect(snacksCenter.dy, lessThan(giftsCenter.dy));
    expect(snacksCenter.dx, greaterThan(foodCenter.dx));
  });

  testWidgets('income and expense are separate sections', (tester) async {
    final ledger = buildLedger(categories: [food, salary]);
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
  });

  testWidgets('a category excluded from analysis carries a marker', (
    tester,
  ) async {
    final ledger = buildLedger(categories: [food, gifts]);
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    final foodRow = find.ancestor(
      of: find.text('Food'),
      matching: find.byType(ListTile),
    );
    final giftsRow = find.ancestor(
      of: find.text('Gifts'),
      matching: find.byType(ListTile),
    );

    expect(
      find.descendant(of: giftsRow, matching: find.byIcon(Icons.bar_chart)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: foodRow, matching: find.byIcon(Icons.bar_chart)),
      findsNothing,
    );
  });

  testWidgets('deleting an unreferenced category needs no reference count', (
    tester,
  ) async {
    final ledger = buildLedger(categories: [gifts]);
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Gifts'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Delete Gifts?'), findsOneWidget);
    expect(find.text('This category will be removed.'), findsOneWidget);
  });

  testWidgets('deleting a referenced category states the singular count', (
    tester,
  ) async {
    final entry = Entry(
      amount: Decimal.parse('-10'),
      name: 'x',
      sourceID: 'a0000000-0000-0000-0000-000000000099',
      categoryID: food.id,
    );
    final ledger = buildLedger(categories: [food], entries: {entry.id: entry});
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Food'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Delete Food?'), findsOneWidget);
    expect(
      find.text('1 transaction will become Uncategorized.'),
      findsOneWidget,
    );
  });

  testWidgets('deleting a category referenced by many states the plural', (
    tester,
  ) async {
    final entryA = Entry(
      amount: Decimal.parse('-10'),
      name: 'x',
      sourceID: 'a0000000-0000-0000-0000-000000000099',
      categoryID: food.id,
    );
    final entryB = Entry(
      amount: Decimal.parse('-5'),
      name: 'y',
      sourceID: 'a0000000-0000-0000-0000-000000000099',
      categoryID: food.id,
    );
    final ledger = buildLedger(
      categories: [food],
      entries: {entryA.id: entryA, entryB.id: entryB},
    );
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Food'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(
      find.text('2 transactions will become Uncategorized.'),
      findsOneWidget,
    );
  });

  testWidgets('confirming delete archives the category', (tester) async {
    final ledger = buildLedger(categories: [gifts]);
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Gifts'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      ledger.state.categories[gifts.id]!.lifecycle,
      LifecycleState.archived,
    );
  });

  testWidgets('the delete custom semantic action opens the same confirm '
      'dialog as the swipe', (tester) async {
    final handle = tester.ensureSemantics();
    final ledger = buildLedger(categories: [gifts]);
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await performCustomSemanticsAction(
      tester,
      of: find.text('Gifts'),
      label: 'Delete Gifts',
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete Gifts?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      ledger.state.categories[gifts.id]!.lifecycle,
      LifecycleState.archived,
    );
    handle.dispose();
  });
}
