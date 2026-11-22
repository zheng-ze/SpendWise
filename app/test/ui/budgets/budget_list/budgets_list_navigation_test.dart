import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view.dart';
import 'package:spendwise/ui/common/lists/swipe_row.dart';

import '../../../support/pump_app.dart';
import '../../../support/ui_test_timeout.dart';

Budget _overall() =>
    Budget(id: 'b1', categoryID: null, limit: Decimal.fromInt(100));

void main() {
  for (final size in [
    ParitySize.phone,
    ParitySize.compact,
    ParitySize.desktop,
  ]) {
    testWidgets('mo-budgets/mo-desk-budgets cap navigation ${size.name}', (
      tester,
    ) async {
      final budget = _overall();
      final ledger = Ledger(state: LedgerState(budgets: {budget.id: budget}));
      await pumpApp(
        tester,
        const BudgetsFlow(header: SizedBox.shrink()),
        ledger: ledger,
        size: size,
      );
      final amount = find.text('S\$100.00');
      await tester.drag(amount, const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(ledger.state.budgets.containsKey(budget.id), isTrue);
      final inList = find.descendant(
        of: find.byType(BudgetsRoot),
        matching: find.byWidgetPredicate(
          (widget) => widget is SwipeRow || widget is Dismissible,
        ),
      );
      expect(inList, findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BudgetsFlow)),
      );
      await tester.tap(amount);
      await tester.pumpAndSettle();
      expect(
        container.read(budgetDetailViewModelProvider(budget.id).exists),
        isTrue,
      );
    }, timeout: uiTestTimeout);
  }
}
