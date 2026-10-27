import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/budgets/budget_overview.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

void main() {
  testWidgets('one open-layout budget has its own full-width tray', (
    tester,
  ) async {
    await _pumpBudgetList(tester, cardCount: 1);

    final tray = tester.getSize(
      find.byKey(const ValueKey('budget-tray-budget-0')),
    );
    expect(tray.width, closeTo(800 - 24, 2));
    expect(find.byType(Tray), findsOneWidget);
  });

  testWidgets('multiple open-layout category cards remain two columns', (
    tester,
  ) async {
    await _pumpBudgetList(tester, cardCount: 2);

    final first = tester.getRect(
      find.byKey(const ValueKey('budget-tray-budget-0')),
    );
    final second = tester.getRect(
      find.byKey(const ValueKey('budget-tray-budget-1')),
    );
    expect(find.byType(Tray), findsNWidgets(2));
    expect(second.width, first.width);
    expect(second.top, first.top);
    expect(second.left, greaterThan(first.right));
  });

  testWidgets('category budget trays stack in a narrow layout', (tester) async {
    await _pumpBudgetList(tester, cardCount: 2, columns: 1);

    final first = tester.getRect(
      find.byKey(const ValueKey('budget-tray-budget-0')),
    );
    final second = tester.getRect(
      find.byKey(const ValueKey('budget-tray-budget-1')),
    );
    expect(find.byType(Tray), findsNWidgets(2));
    expect(second.top, greaterThan(first.bottom));
    expect(second.width, first.width);
  });
}

Future<void> _pumpBudgetList(
  WidgetTester tester, {
  required int cardCount,
  int columns = 2,
}) async {
  final rows = [
    for (var index = 0; index < cardCount; index++)
      CategoryBudgetRow(
        budgetID: 'budget-$index',
        categoryID: 'category-$index',
        name: 'Category $index',
        parentName: null,
        limit: Decimal.fromInt(100),
        spend: Decimal.fromInt(25),
      ),
  ];
  final cards = [
    for (var index = 0; index < cardCount; index++)
      (
        id: 'budget-$index',
        savedHex: null,
        name: 'Category $index',
        amounts: '\$25 of \$100',
        status: '\$75 left / 25.0% used',
        progress: 0.25,
        overLimit: false,
      ),
  ];
  final viewState = BudgetsListViewState(
    overview: BudgetsOverview(
      month: const YearMonth(2026, 10),
      allSpending: AllSpending(
        cap: null,
        capBudgetID: null,
        spent: Decimal.zero,
        dailyAllowance: null,
      ),
      categoryBudgets: rows,
    ),
    cards: cards,
    today: DateTime.utc(2026, 10, 27),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: buildSpendWiseTheme(Brightness.light),
      home: Material(
        child: SizedBox(
          width: 600,
          child: BudgetsListView(
            viewState: viewState,
            viewModel: _ViewModel(),
            columns: columns,
            showFloatingAction: false,
            sections: const [BudgetsSection.categoryBudgets],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _ViewModel implements BudgetsListViewModel {
  @override
  void clearStep() {}

  @override
  void deleteBudget(String id) {}

  @override
  void requestBudgetDetail(String budgetID) {}

  @override
  void requestNewBudget() {}

  @override
  void retry() {}
}
