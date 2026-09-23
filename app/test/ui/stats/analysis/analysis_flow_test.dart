import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/stats/analysis/analysis_flow.dart';
import 'package:spendwise/ui/stats/analysis/analysis_view_model.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';
import 'package:spendwise/ui/stats/helpers/stats_window.dart';

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

  Future<ProviderContainer> pumpFlow(
    WidgetTester tester,
    Ledger ledger,
    CategoryKind kind,
  ) async {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        analysisCacheProvider.overrideWith(
          (ref) => AnalysisCache(runner: syncComputeRunner),
        ),
      ],
    );
    addTearDown(container.dispose);

    final selectedDate = DateTime.utc(2026, 3);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AnalysisFlow(
            key: ValueKey(kind),
            kind: kind,
            window: monthWindow(selectedDate),
            isYearRange: false,
            selectedDate: selectedDate,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'CategoryDetailRequested pushes CategoryDetailScreen with matching args',
    (tester) async {
      final container = await pumpFlow(
        tester,
        buildLedger(),
        CategoryKind.expense,
      );
      final now = DateTime.utc(2026, 3);

      container
          .read(analysisViewModelProvider(CategoryKind.expense).notifier)
          .requestCategoryDetail(
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
      expect(
        container
            .read(analysisViewModelProvider(CategoryKind.expense))
            .value
            ?.step,
        isNull,
      );
    },
  );

  testWidgets(
    'switching from income to expense pushes detail scoped to the newly '
    'active kind',
    (tester) async {
      final incomeCategory = TransactionCategory(
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
          categories: {food.id: food, incomeCategory.id: incomeCategory},
        ),
      );
      final container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWithValue(ledger),
          analysisCacheProvider.overrideWith(
            (ref) => AnalysisCache(runner: syncComputeRunner),
          ),
        ],
      );
      addTearDown(container.dispose);
      final selectedDate = DateTime.utc(2026, 3);

      Widget buildFor(CategoryKind kind) => MaterialApp(
        home: AnalysisFlow(
          key: ValueKey(kind),
          kind: kind,
          window: monthWindow(selectedDate),
          isYearRange: false,
          selectedDate: selectedDate,
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildFor(CategoryKind.income),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildFor(CategoryKind.expense),
        ),
      );
      await tester.pumpAndSettle();

      container
          .read(analysisViewModelProvider(CategoryKind.expense).notifier)
          .requestCategoryDetail(
            mainID: food.id,
            isYearRange: false,
            initialDate: selectedDate,
          );
      await tester.pumpAndSettle();

      final pushed = tester.widget<CategoryDetailScreen>(
        find.byType(CategoryDetailScreen),
      );
      expect(pushed.args.kind, CategoryKind.expense);
      expect(pushed.args.mainID, food.id);
      expect(
        container
            .read(analysisViewModelProvider(CategoryKind.income))
            .value
            ?.step,
        isNull,
      );
    },
  );
}
