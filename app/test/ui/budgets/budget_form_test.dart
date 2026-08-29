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
}
