import 'dart:async';

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';

import '../support/in_memory_ledger_store.dart';

const _readyTimeout = Duration(seconds: 5);
const _maxReadyPumps = 100;

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
        analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<Ready> readyPhase(ProviderContainer container) async {
    final boot = container.read(appBootProvider);
    for (var attempt = 0; attempt < _maxReadyPumps; attempt++) {
      if (boot.phase case final Ready ready) return ready;
      await Future<void>.delayed(Duration.zero);
    }
    throw TimeoutException('Boot did not become ready', _readyTimeout);
  }

  test('categoryDetailRefreshesTotalsFromTheReplacementCache', () async {
    final holder = StoreHolder(
      InMemoryLedgerStore(state: stateWithSpending('-10'), hasSeeded: true),
    );
    final container = containerFor(holder);
    final boot = container.read(appBootProvider);
    await readyPhase(container).timeout(_readyTimeout);
    final args = CategoryDetailArgs(
      mainID: foodID,
      kind: CategoryKind.expense,
      isYearRange: false,
      initialDate: DateTime.utc(2026, 4, 15),
    );

    final subscription = container.listen(
      categoryDetailViewModelProvider(args),
      (_, _) {},
    );
    addTearDown(subscription.close);

    final before = await readyDetail(container, args).timeout(_readyTimeout);
    expect(before.totals.scopeTotal, dec('10'));
    final previousQueries = container.read(analysisQueriesProvider);
    final previousCache = container.read(ledgerSessionProvider)!.analysisCache;

    holder.current = InMemoryLedgerStore(
      state: stateWithSpending('-25'),
      hasSeeded: true,
    );

    await boot.retry();
    await readyPhase(container).timeout(_readyTimeout);

    final after = await readyDetail(container, args).timeout(_readyTimeout);
    expect(after.totals.scopeTotal, dec('25'));
    expect(
      container.read(analysisQueriesProvider),
      isNot(same(previousQueries)),
    );
    final currentSession = container.read(ledgerSessionProvider)!;
    expect(currentSession.analysisCache, isNot(same(previousCache)));
    expect(after.sourceRevision, currentSession.ledger.revision);
  });
}

Future<CategoryDetailReadyBody> readyDetail(
  ProviderContainer container,
  CategoryDetailArgs args,
) async {
  for (var attempt = 0; attempt < _maxReadyPumps; attempt++) {
    final state = container.read(categoryDetailViewModelProvider(args)).value;
    final session = container.read(ledgerSessionProvider);
    final body = state?.body;
    if (body is CategoryDetailReadyBody &&
        body.sourceRevision == session?.ledger.revision) {
      return body;
    }
    await Future<void>.delayed(Duration.zero);
  }
  throw TimeoutException(
    'Detail did not reach the current revision',
    _readyTimeout,
  );
}
