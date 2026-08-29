import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/stats/analysis_view_model.dart';

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

  ProviderContainer buildContainer(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        analysisCacheProvider.overrideWith(
          (ref) => AnalysisCache(runner: syncComputeRunner),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('build carries the kind it was requested for', () async {
    final container = buildContainer(buildLedger());

    final state = await container.read(
      analysisViewModelProvider(CategoryKind.expense).future,
    );

    expect(state.kind, CategoryKind.expense);
    expect(state.step, isNull);
  });

  test(
    'requestCategoryDetail emits CategoryDetailRequested with the given args',
    () async {
      final container = buildContainer(buildLedger());
      await container.read(
        analysisViewModelProvider(CategoryKind.expense).future,
      );
      final viewModel = container.read(
        analysisViewModelProvider(CategoryKind.expense).notifier,
      );
      final now = DateTime.utc(2026, 3);

      viewModel.requestCategoryDetail(
        mainID: food.id,
        isYearRange: false,
        initialDate: now,
      );

      final step = container
          .read(analysisViewModelProvider(CategoryKind.expense))
          .value
          ?.step;
      expect(step, isA<CategoryDetailRequested>());
      final requested = step as CategoryDetailRequested;
      expect(requested.mainID, food.id);
      expect(requested.isYearRange, isFalse);
      expect(requested.initialDate, now);
    },
  );

  test('clearStep resets the step to null', () async {
    final container = buildContainer(buildLedger());
    await container.read(
      analysisViewModelProvider(CategoryKind.expense).future,
    );
    final viewModel = container.read(
      analysisViewModelProvider(CategoryKind.expense).notifier,
    );
    final now = DateTime.utc(2026, 3);

    viewModel.requestCategoryDetail(
      mainID: food.id,
      isYearRange: false,
      initialDate: now,
    );
    expect(
      container
          .read(analysisViewModelProvider(CategoryKind.expense))
          .value
          ?.step,
      isNotNull,
    );

    viewModel.clearStep();
    expect(
      container
          .read(analysisViewModelProvider(CategoryKind.expense))
          .value
          ?.step,
      isNull,
    );
  });

  test(
    'income and expense kinds get independent ViewModel instances',
    () async {
      final container = buildContainer(buildLedger());
      final incomeState = await container.read(
        analysisViewModelProvider(CategoryKind.income).future,
      );
      final expenseState = await container.read(
        analysisViewModelProvider(CategoryKind.expense).future,
      );

      expect(incomeState.kind, CategoryKind.income);
      expect(expenseState.kind, CategoryKind.expense);

      container
          .read(analysisViewModelProvider(CategoryKind.expense).notifier)
          .requestCategoryDetail(
            mainID: food.id,
            isYearRange: false,
            initialDate: DateTime.utc(2026, 3),
          );

      expect(
        container
            .read(analysisViewModelProvider(CategoryKind.income))
            .value
            ?.step,
        isNull,
      );
      expect(
        container
            .read(analysisViewModelProvider(CategoryKind.expense))
            .value
            ?.step,
        isNotNull,
      );
    },
  );
}
