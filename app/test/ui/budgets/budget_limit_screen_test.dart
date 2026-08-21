import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_limit_screen.dart';
import 'package:spendwise/ui/format/date_format.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  Budget buildBudget() {
    return Budget(
      id: 'b1',
      categoryID: null,
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

  Future<void> pumpScreen(WidgetTester tester, Ledger ledger, String id) {
    return tester.pumpWidget(
      MaterialApp(
        home: BudgetLimitScreen(ledger: ledger, budgetID: id),
      ),
    );
  }

  testWidgets(
    'shows the default budget and the current year\'s twelve months',
    (tester) async {
      final budget = buildBudget();
      final ledger = Ledger(state: LedgerState(budgets: {budget.id: budget}));
      final now = DateTime.now().toUtc();

      await pumpScreen(tester, ledger, budget.id);
      await tester.pumpAndSettle();

      expect(find.text('Default Budget'), findsOneWidget);
      expect(find.text(r'$100.00'), findsWidgets);
      // Latest month first (most relevant to the user), so December is
      // visible without scrolling and January needs a scroll down to reach.
      expect(
        find.text(formatMonthLabel(DateTime.utc(now.year, 12))),
        findsOneWidget,
      );

      await tester.dragUntilVisible(
        find.text(formatMonthLabel(DateTime.utc(now.year, 1))),
        find.byType(ListView),
        const Offset(0, -100),
      );
      expect(
        find.text(formatMonthLabel(DateTime.utc(now.year, 1))),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'editing the default limit applies from next month, not the current one',
    (tester) async {
      final budget = buildBudget();
      final ledger = Ledger(state: LedgerState(budgets: {budget.id: budget}));
      final now = DateTime.now().toUtc();
      final currentMonth = YearMonth(now.year, now.month);

      await pumpScreen(tester, ledger, budget.id);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Default Budget'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '200.00');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        effectiveLimit(ledger.state.budgets[budget.id]!, currentMonth),
        dec('100'),
      );
      expect(find.text(r'$200.00'), findsWidgets);
    },
  );

  testWidgets(
    'setting an override from a month row updates that month and effectiveLimit',
    (tester) async {
      final budget = buildBudget();
      final ledger = Ledger(state: LedgerState(budgets: {budget.id: budget}));
      final now = DateTime.now().toUtc();
      final currentMonth = YearMonth(now.year, now.month);

      expect(
        effectiveLimit(ledger.state.budgets[budget.id]!, currentMonth),
        dec('100'),
      );

      await pumpScreen(tester, ledger, budget.id);
      await tester.pumpAndSettle();

      final monthLabel = find.text(formatMonthLabel(now));
      await tester.dragUntilVisible(
        monthLabel,
        find.byType(ListView),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      final currentMonthTile = find
          .ancestor(of: monthLabel, matching: find.byType(ListTile))
          .first;
      await tester.ensureVisible(currentMonthTile);
      await tester.pumpAndSettle();
      await tester.tap(currentMonthTile);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '150.00');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        effectiveLimit(ledger.state.budgets[budget.id]!, currentMonth),
        dec('150'),
      );
      expect(find.text(r'$150.00'), findsWidgets);
    },
  );

  testWidgets('the year selector moves the shown months to the adjacent year', (
    tester,
  ) async {
    final budget = buildBudget();
    final ledger = Ledger(state: LedgerState(budgets: {budget.id: budget}));
    final now = DateTime.now().toUtc();

    await pumpScreen(tester, ledger, budget.id);
    await tester.pumpAndSettle();

    expect(find.text(now.year.toString()), findsOneWidget);
    expect(
      find.text(formatMonthLabel(DateTime.utc(now.year, 12))),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text((now.year + 1).toString()), findsOneWidget);
    expect(
      find.text(formatMonthLabel(DateTime.utc(now.year + 1, 12))),
      findsOneWidget,
    );
    expect(
      find.text(formatMonthLabel(DateTime.utc(now.year, 12))),
      findsNothing,
    );
  });
}
