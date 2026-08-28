import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_form.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  Budget buildBudget({String? categoryID, String id = 'stale'}) {
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

  Future<void> pumpForm(WidgetTester tester, Ledger ledger) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ledgerProvider.overrideWithValue(ledger)],
        child: const MaterialApp(home: Scaffold(body: BudgetForm())),
      ),
    );
    // Flushes BudgetFormNotifier.build()'s Future so the form's initial
    // AsyncData state is in place before a test interacts with it.
    await tester.pump();
  }

  testWidgets(
    'a rejected save keeps the form field values, showing the error instead',
    (tester) async {
      // Overall is already budgeted, so saving another Overall budget
      // rejects with CategoryAlreadyBudgeted.
      final existingOverall = buildBudget(categoryID: null, id: 'b1');
      final ledger = Ledger(
        state: LedgerState(budgets: {existingOverall.id: existingOverall}),
      );

      await pumpForm(tester, ledger);
      await tester.enterText(find.byType(TextField).first, '250.00');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not save budget'), findsOneWidget);
      expect(find.text('250.00'), findsOneWidget);
    },
  );

  testWidgets(
    'the category picker excludes only already-budgeted categories, not '
    'a whole branch of the tree',
    (tester) async {
      final parent = TransactionCategory(
        id: 'p0000000-0000-0000-0000-000000000001',
        name: 'Food',
        kind: CategoryKind.expense,
        colorHex: '#FF0000',
        includeInAnalysis: true,
        parentID: null,
        symbol: 'restaurant',
      );
      final child = TransactionCategory(
        id: 'c0000000-0000-0000-0000-000000000001',
        name: 'Coffee',
        kind: CategoryKind.expense,
        colorHex: '#FF0000',
        includeInAnalysis: true,
        parentID: parent.id,
        symbol: 'coffee',
      );
      final parentBudget = buildBudget(categoryID: parent.id, id: 'b1');

      final ledger = Ledger(
        state: LedgerState(
          categories: {parent.id: parent, child.id: child},
          budgets: {parentBudget.id: parentBudget},
        ),
      );

      await pumpForm(tester, ledger);
      await tester.tap(find.text('Overall'));
      await tester.pumpAndSettle();

      // The already-budgeted parent still shows as a group header (disabled,
      // not tappable) so the still-budgetable child has somewhere to sit.
      final foodTile = tester.widget<ListTile>(
        find.ancestor(of: find.text('Food'), matching: find.byType(ListTile)),
      );
      expect(foodTile.enabled, isFalse);

      final coffeeTile = tester.widget<ListTile>(
        find.ancestor(of: find.text('Coffee'), matching: find.byType(ListTile)),
      );
      expect(coffeeTile.enabled, isTrue);

      await tester.tap(find.text('Coffee'));
      await tester.pumpAndSettle();
      expect(find.text('Coffee'), findsOneWidget);
    },
  );

  testWidgets('the category picker excludes income categories', (tester) async {
    final expense = TransactionCategory(
      id: 'e0000000-0000-0000-0000-000000000001',
      name: 'Food',
      kind: CategoryKind.expense,
      colorHex: '#FF0000',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'restaurant',
    );
    final income = TransactionCategory(
      id: 'i0000000-0000-0000-0000-000000000001',
      name: 'Salary',
      kind: CategoryKind.income,
      colorHex: '#00FF00',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'attach_money',
    );

    final ledger = Ledger(
      state: LedgerState(categories: {expense.id: expense, income.id: income}),
    );

    await pumpForm(tester, ledger);
    await tester.tap(find.text('Overall'));
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Salary'), findsNothing);
  });

  testWidgets(
    'dismissing the category picker without choosing leaves the selection '
    'unchanged',
    (tester) async {
      final food = TransactionCategory(
        id: 'f0000000-0000-0000-0000-000000000001',
        name: 'Food',
        kind: CategoryKind.expense,
        colorHex: '#FF0000',
        includeInAnalysis: true,
        parentID: null,
        symbol: 'restaurant',
      );

      final ledger = Ledger(state: LedgerState(categories: {food.id: food}));

      await pumpForm(tester, ledger);
      await tester.tap(find.text('Overall'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      expect(find.text('Food'), findsOneWidget);

      await tester.tap(find.text('Category'));
      await tester.pumpAndSettle();
      // Tap the barrier above the sheet to dismiss it without choosing.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Overall'), findsNothing);
    },
  );
}
