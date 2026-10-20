import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/stats/analysis/analysis_view_model.dart';

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
        analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
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
    },
  );
}
