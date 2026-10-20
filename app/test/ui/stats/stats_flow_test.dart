import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/stats/stats_flow.dart';
import 'package:spendwise/ui/stats/stats_root_view_model.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';

import '../../support/ui_test_timeout.dart';

void main() {
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

  Ledger buildLedger() {
    return Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        categories: {food.id: food},
      ),
    );
  }

  Future<ProviderContainer> pumpFlow(WidgetTester tester, Ledger ledger) async {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
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

  testWidgets(
    'CategoryDetailRequested pushes CategoryDetailScreen with matching args',
    (tester) async {
      final container = await pumpFlow(tester, buildLedger());
      final now = DateTime.utc(2026, 3);

      container
          .read(statsRootViewModelProvider.notifier)
          .requestCategoryDetail(
            kind: CategoryKind.expense,
            mainID: food.id,
            isYearRange: false,
            initialDate: now,
          );
      await tester.pumpAndSettle();

      final pushed = tester.widget<CategoryDetailScreen>(
        find.byType(CategoryDetailScreen),
      );
      expect(pushed.args.mainID, food.id);
      expect(pushed.args.kind, CategoryKind.expense);
      expect(pushed.args.isYearRange, isFalse);
      expect(pushed.args.initialDate, now);
      expect(container.read(statsRootViewModelProvider).step, isNull);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'an income request pushes detail scoped to income on the same Flow',
    (tester) async {
      final salary = TransactionCategory(
        id: 'c0000000-0000-0000-0000-000000000002',
        name: 'Salary',
        kind: CategoryKind.income,
        colorHex: '#0000AA',
        includeInAnalysis: true,
        parentID: null,
        symbol: 'payments',
      );
      final ledger = Ledger(
        state: LedgerState(
          moneySources: {account.id: MoneySource.account(account)},
          categories: {food.id: food, salary.id: salary},
        ),
      );
      final container = await pumpFlow(tester, ledger);

      container
          .read(statsRootViewModelProvider.notifier)
          .requestCategoryDetail(
            kind: CategoryKind.income,
            mainID: salary.id,
            isYearRange: false,
            initialDate: DateTime.utc(2026, 3),
          );
      await tester.pumpAndSettle();

      final pushed = tester.widget<CategoryDetailScreen>(
        find.byType(CategoryDetailScreen),
      );
      expect(pushed.args.kind, CategoryKind.income);
      expect(pushed.args.mainID, salary.id);
      expect(container.read(statsRootViewModelProvider).step, isNull);
    },
    timeout: uiTestTimeout,
  );
}
