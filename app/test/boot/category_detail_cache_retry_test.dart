import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';

import '../support/in_memory_ledger_store.dart';

class StoreHolder {
  StoreHolder(this.current);

  InMemoryLedgerStore current;
}

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  const accountID = 'a0000000-0000-0000-0000-000000000001';
  const foodID = 'c0000000-0000-0000-0000-000000000001';

  LedgerState stateWithSpending(String amount) {
    final state = LedgerState();
    state.addAccount(
      Account(id: accountID, name: 'Checking', type: AccountType.checking),
    );
    state.addCategory(
      TransactionCategory(
        id: foodID,
        name: 'Food',
        kind: CategoryKind.expense,
        colorHex: '#00AA00',
        includeInAnalysis: true,
        parentID: null,
        symbol: 'restaurant',
      ),
    );
    state.addEntry(
      Entry(
        amount: Decimal.parse(amount),
        name: 'Noodles',
        sourceID: accountID,
        categoryID: foodID,
        date: DateTime.utc(2026, 4, 7),
      ),
    );
    return state;
  }

  ProviderContainer containerFor(StoreHolder holder) {
    TestWidgetsFlutterBinding.ensureInitialized();
    final container = ProviderContainer(
      overrides: [
        storeProvider.overrideWith((ref) => holder.current),
        databaseConnectionProvider.overrideWith(
          (ref) async => NativeDatabase.memory(),
        ),
        analysisCacheProvider.overrideWith((ref) {
          final ledger = ref.watch(ledgerProvider);
          if (ledger == null) return null;
          return AnalysisCache(runner: syncComputeRunner)
            ..start(ledger.bus, sourceRevision: () => ledger.revision);
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<Ready> readyPhase(ProviderContainer container) async {
    final boot = container.read(appBootProvider);
    while (boot.phase is! Ready) {
      await Future<void>.delayed(Duration.zero);
    }
    return boot.phase as Ready;
  }

  test('categoryDetailRefreshesTotalsFromTheReplacementCache', () async {
    final holder = StoreHolder(
      InMemoryLedgerStore(state: stateWithSpending('-10'), hasSeeded: true),
    );
    final container = containerFor(holder);
    final boot = container.read(appBootProvider);
    await readyPhase(container);
    final args = CategoryDetailArgs(
      mainID: foodID,
      kind: CategoryKind.expense,
      isYearRange: false,
      initialDate: DateTime.utc(2026, 4, 15),
    );

    final before = await container.read(
      categoryDetailViewModelProvider(args).future,
    );
    expect(before.totals.scopeTotal, dec('10'));

    holder.current = InMemoryLedgerStore(
      state: stateWithSpending('-25'),
      hasSeeded: true,
    );

    await boot.retry();
    await readyPhase(container);

    final after = await container.read(
      categoryDetailViewModelProvider(args).future,
    );
    expect(after.totals.scopeTotal, dec('25'));
  });
}
