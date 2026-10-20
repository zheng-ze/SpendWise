import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/navigation/top_tab_bar.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/stats/stats_flow.dart';
import 'package:spendwise/ui/stats/stats_root_view_model.dart';
import 'package:spendwise/ui/stats/helpers/stats_window.dart';

import '../../support/ui_test_timeout.dart';

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

  final salary = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000002',
    name: 'Salary',
    kind: CategoryKind.income,
    colorHex: '#00BB00',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'payments',
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    Ledger ledger, {
    DateTime? selectedDate,
  }) async {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
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
    expect(tester.widget<TopTabBar>(find.byType(TopTabBar)).titles, [
      'Income',
      'Expense',
    ]);
    expect(find.byTooltip('Previous month'), findsOneWidget);
    expect(find.byTooltip('Previous year'), findsNothing);
    expect(find.byType(PopupMenuButton<StatsRangeMode>), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('total line sums the window\'s items for the active kind', (
    tester,
  ) async {
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        categories: {food.id: food, salary.id: salary},
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
            expenseEntry(
              'Salary',
              '50',
              DateTime.utc(2026, 3, 15),
              categoryID: salary.id,
            ),
          ])
            e.id: e,
        },
      ),
    );

    await pumpScreen(tester, ledger, selectedDate: DateTime.utc(2026, 3));

    expect(totalAmountText('S\$25.00'), findsOneWidget);
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(totalAmountText('S\$50.00'), findsOneWidget);
    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();
    expect(totalAmountText('S\$25.00'), findsOneWidget);
  }, timeout: uiTestTimeout);

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
    expect(totalAmountText('S\$10.00'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annually'));
    await tester.pumpAndSettle();

    expect(totalAmountText('S\$25.00'), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('an empty window shows the empty state', (tester) async {
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
      ),
    );

    await pumpScreen(tester, ledger, selectedDate: DateTime.utc(2026, 3));

    expect(find.text('No expense in this period'), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('range menu selects yearly and monthly ranges', (tester) async {
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
      ),
    );

    await pumpScreen(tester, ledger, selectedDate: DateTime.utc(2026, 3));
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuButton<StatsRangeMode>), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annually'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Previous year'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Previous month'), findsOneWidget);
  }, timeout: uiTestTimeout);
}
