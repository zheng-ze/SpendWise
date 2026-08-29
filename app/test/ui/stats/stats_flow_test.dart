import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail_screen.dart';
import 'package:spendwise/ui/budgets/budgets_list_view_model.dart';
import 'package:spendwise/ui/common/top_tab_bar.dart';
import 'package:spendwise/ui/stats/analysis_view_model.dart';
import 'package:spendwise/ui/stats/category_detail_screen.dart';
import 'package:spendwise/ui/stats/stats_flow.dart';
import 'package:spendwise/ui/stats/stats_root_screen.dart';
import 'package:spendwise/ui/stats/stats_root_view_model.dart';

void main() {
  final account = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );

  Ledger buildLedger() {
    final category = TransactionCategory(
      id: 'c0000000-0000-0000-0000-000000000001',
      name: 'Food',
      kind: CategoryKind.expense,
      colorHex: '#00AA00',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'restaurant',
    );
    final budget = Budget(
      id: 'b0000000-0000-0000-0000-000000000001',
      categoryID: category.id,
      limitEvents: [
        LimitEvent(
          effectiveFromMonth: null,
          value: Decimal.parse('100'),
          kind: LimitEventKind.defaultLimit,
        ),
      ],
      createdAtMonth: const YearMonth(2026, 1),
    );
    return Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        categories: {category.id: category},
        budgets: {budget.id: budget},
      ),
    );
  }

  Future<ProviderContainer> pumpFlow(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(buildLedger()),
        analysisCacheProvider.overrideWith(
          (ref) => AnalysisCache(runner: syncComputeRunner),
        ),
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
    return container;
  }

  testWidgets('StatsFlow renders StatsRootScreen as its root', (tester) async {
    await pumpFlow(tester);

    expect(find.byType(StatsRootScreen), findsOneWidget);
  });

  testWidgets('budget detail replaces the Stats chrome', (tester) async {
    final container = await pumpFlow(tester);
    const budgetID = 'b0000000-0000-0000-0000-000000000001';

    container
        .read(statsRootViewModelProvider.notifier)
        .setTab(StatsTab.budgets);
    await tester.pumpAndSettle();
    container
        .read(budgetsListViewModelProvider.notifier)
        .requestBudgetDetail(budgetID);
    await tester.pumpAndSettle();

    expect(find.byType(BudgetDetailScreen), findsOneWidget);
    expect(find.byType(StatsRootScreen), findsNothing);
    expect(find.byType(TopTabBar), findsNothing);
  });

  testWidgets('category detail replaces the Stats chrome', (tester) async {
    final container = await pumpFlow(tester);
    const categoryID = 'c0000000-0000-0000-0000-000000000001';
    final selectedDate = DateTime.utc(2026, 3);

    container
        .read(analysisViewModelProvider(CategoryKind.expense).notifier)
        .requestCategoryDetail(
          mainID: categoryID,
          isYearRange: false,
          initialDate: selectedDate,
        );
    await tester.pumpAndSettle();

    expect(find.byType(CategoryDetailScreen), findsOneWidget);
    expect(find.byType(StatsRootScreen), findsNothing);
    expect(find.byType(TopTabBar), findsNothing);
  });
}
