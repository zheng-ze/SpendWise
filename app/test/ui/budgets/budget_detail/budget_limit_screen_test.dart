import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_screen.dart';
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
      ProviderScope(
        overrides: [ledgerProvider.overrideWithValue(ledger)],
        child: MaterialApp(home: BudgetLimitScreen(budgetID: id)),
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
