import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/stats/stats_root_view_model.dart';

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

  final hawker = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000002',
    name: 'Hawker',
    kind: CategoryKind.expense,
    colorHex: '#00BB00',
    includeInAnalysis: true,
    parentID: food.id,
    symbol: 'set_meal',
  );

  Ledger buildLedger() {
    return Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        categories: {food.id: food, hawker.id: hawker},
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

  test('build defaults to the expense tab and monthly range', () async {
    final container = buildContainer(buildLedger());

    final state = await container.read(statsRootViewModelProvider.future);

    expect(state.tab, StatsTab.expense);
    expect(state.range, StatsRangeMode.month);
    expect(state.step, isNull);
  });

  test(
    'setTab and setRange update the view state without emitting a step',
    () async {
      final container = buildContainer(buildLedger());
      await container.read(statsRootViewModelProvider.future);
      final viewModel = container.read(statsRootViewModelProvider.notifier);

      viewModel.setTab(StatsTab.budgets);
      expect(
        container.read(statsRootViewModelProvider).value?.tab,
        StatsTab.budgets,
      );

      viewModel.setRange(StatsRangeMode.year);
      expect(
        container.read(statsRootViewModelProvider).value?.range,
        StatsRangeMode.year,
      );
      expect(container.read(statsRootViewModelProvider).value?.step, isNull);
    },
  );

  test(
    'requestCategoryDetail emits CategoryDetailRequested with the given args',
    () async {
      final container = buildContainer(buildLedger());
      await container.read(statsRootViewModelProvider.future);
      final viewModel = container.read(statsRootViewModelProvider.notifier);
      final now = DateTime.utc(2026, 3);

      viewModel.requestCategoryDetail(
        kind: CategoryKind.expense,
        mainID: food.id,
        isYearRange: false,
        initialDate: now,
      );

      final step = container.read(statsRootViewModelProvider).value?.step;
      expect(step, isA<CategoryDetailRequested>());
      final requested = step as CategoryDetailRequested;
      expect(requested.mainID, food.id);
      expect(requested.kind, CategoryKind.expense);
      expect(requested.isYearRange, isFalse);
      expect(requested.initialDate, now);
    },
  );

  test('clearStep resets the step to null', () async {
    final container = buildContainer(buildLedger());
    await container.read(statsRootViewModelProvider.future);
    final viewModel = container.read(statsRootViewModelProvider.notifier);
    final now = DateTime.utc(2026, 3);

    viewModel.requestCategoryDetail(
      kind: CategoryKind.expense,
      mainID: food.id,
      isYearRange: false,
      initialDate: now,
    );
    expect(container.read(statsRootViewModelProvider).value?.step, isNotNull);

    viewModel.clearStep();
    expect(container.read(statsRootViewModelProvider).value?.step, isNull);
  });
}
