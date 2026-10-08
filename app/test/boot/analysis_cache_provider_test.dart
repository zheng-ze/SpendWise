import 'dart:async';

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ui/stats/analysis/analysis_view_model.dart';

import '../support/in_memory_ledger_store.dart';

Account _account({String name = 'acc'}) =>
    Account(name: name, type: AccountType.savings);

TransactionCategory _category({String name = 'food'}) => TransactionCategory(
  name: name,
  kind: CategoryKind.expense,
  colorHex: '#000000',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'tag',
);

LedgerState _stateWithExpense() {
  final state = LedgerState();
  final account = _account();
  state.addAccount(account);
  final category = _category();
  state.addCategory(category);
  state.addEntry(
    Entry(
      amount: Decimal.fromInt(-10),
      name: 'lunch',
      sourceID: account.id,
      categoryID: category.id,
    ),
  );
  return state;
}

class _ManualRunner {
  final List<Completer<List<AnalysisItem>>> pending = [];

  Future<List<AnalysisItem>> call(LedgerState state) {
    final completer = Completer<List<AnalysisItem>>();
    pending.add(completer);
    return completer.future;
  }
}

AnalysisCache? _boundCache(Ref ref, ComputeRunner runner) {
  final ledger = ref.watch(ledgerProvider);
  if (ledger == null) return null;
  final cache = AnalysisCache(runner: runner);
  cache.start(ledger.bus, sourceRevision: () => ledger.revision);
  return cache;
}

ProviderContainer _containerFor(
  InMemoryLedgerStore store,
  ComputeRunner runner,
) {
  TestWidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(
    overrides: [
      storeProvider.overrideWithValue(store),
      databaseConnectionProvider.overrideWith(
        (ref) async => NativeDatabase.memory(),
      ),
      analysisCacheProvider.overrideWith((ref) => _boundCache(ref, runner)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<Ready> _readyPhase(ProviderContainer container) async {
  final boot = container.read(appBootProvider);
  while (boot.phase is! Ready) {
    await Future<void>.delayed(Duration.zero);
  }
  return boot.phase as Ready;
}

void main() {
  test('cacheProviderIsNullBeforeReady', () async {
    final container = _containerFor(
      InMemoryLedgerStore(hasSeeded: true),
      syncComputeRunner,
    );

    expect(container.read(ledgerProvider), isNull);
    expect(container.read(analysisCacheProvider), isNull);

    await _readyPhase(container);

    expect(container.read(analysisCacheProvider), isNotNull);
  });

  test('cacheSubscribesToItsLedgerBusBeforeConstructionReturns', () async {
    final container = _containerFor(
      InMemoryLedgerStore(hasSeeded: true),
      syncComputeRunner,
    );
    final ready = await _readyPhase(container);

    final cache = container.read(analysisCacheProvider)!;

    ready.ledger.addAccount(_account());

    expect(cache.revision, 1);
  });

  test('sameLedgerIdentityKeepsTheSameCacheInstance', () async {
    final container = _containerFor(
      InMemoryLedgerStore(hasSeeded: true),
      syncComputeRunner,
    );
    await _readyPhase(container);

    final first = container.read(analysisCacheProvider)!;
    final second = container.read(analysisCacheProvider)!;

    expect(identical(first, second), isTrue);
  });

  test('bootRetryYieldsANewCacheAndOldWorkStaysInert', () async {
    final runner = _ManualRunner();
    final container = _containerFor(
      InMemoryLedgerStore(hasSeeded: true),
      runner.call,
    );
    final boot = container.read(appBootProvider);
    final firstReady = await _readyPhase(container);
    final oldCache = container.read(analysisCacheProvider)!;
    var newNotifications = 0;

    oldCache.refresh(firstReady.ledger.state);
    expect(runner.pending, hasLength(1));

    await boot.retry();
    await _readyPhase(container);
    final newCache = container.read(analysisCacheProvider)!;
    newCache.addListener(() => newNotifications++);

    expect(identical(newCache, oldCache), isFalse);
    expect(() => oldCache.addListener(() {}), throwsFlutterError);

    runner.pending.single.complete([
      AnalysisItem(
        bucketID: null,
        amount: Decimal.fromInt(99),
        date: DateTime.utc(2026, 4, 7),
        kind: CategoryKind.expense,
      ),
    ]);
    await pumpEventQueue();

    expect(newCache.items, isEmpty);
    expect(newCache.itemsSourceRevision, -1);
    expect(newNotifications, 0);
  });

  test('legacyViewModelRebuildsAgainstTheReplacementCache', () async {
    final container = _containerFor(
      InMemoryLedgerStore(state: _stateWithExpense(), hasSeeded: true),
      syncComputeRunner,
    );
    final boot = container.read(appBootProvider);
    await _readyPhase(container);

    final before = await container.read(
      analysisViewModelProvider(CategoryKind.expense).future,
    );
    expect(before.items, hasLength(1));
    final oldCache = container.read(analysisCacheProvider)!;

    await boot.retry();
    final secondReady = await _readyPhase(container);
    final newCache = container.read(analysisCacheProvider)!;

    expect(identical(newCache, oldCache), isFalse);
    expect(() => oldCache.addListener(() {}), throwsFlutterError);

    final after = await container.read(
      analysisViewModelProvider(CategoryKind.expense).future,
    );
    expect(after.items, hasLength(1));

    secondReady.ledger.addEntry(
      Entry(
        amount: Decimal.fromInt(-5),
        name: 'coffee',
        sourceID: secondReady.ledger.state.moneySources.keys.single,
        categoryID: secondReady.ledger.state.categories.keys.single,
      ),
    );
    await pumpEventQueue();

    expect(newCache.items, hasLength(2));
    expect(
      container
          .read(analysisViewModelProvider(CategoryKind.expense))
          .value
          ?.items,
      hasLength(2),
    );
  });
}
