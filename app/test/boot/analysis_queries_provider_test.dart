import 'dart:async';

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';

import '../support/in_memory_ledger_store.dart';

const _accountID = '11111111-1111-1111-1111-111111111111';
const _foodID = '33333333-3333-3333-3333-333333333333';

LedgerState _stateWithExpense() {
  final state = LedgerState();
  final account = Account(
    id: _accountID,
    name: 'Checking',
    type: AccountType.checking,
  );
  state.addAccount(account);
  final category = TransactionCategory(
    id: _foodID,
    name: 'Food',
    kind: CategoryKind.expense,
    colorHex: '#000000',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'tag',
  );
  state.addCategory(category);
  state.addEntry(
    Entry(
      id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      amount: Decimal.parse('-10.00'),
      name: 'lunch',
      sourceID: account.id,
      categoryID: category.id,
      date: DateTime.utc(2027, 4, 7),
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

({ProviderContainer container, InMemoryLedgerStore store}) _container({
  required LedgerState? state,
  required ComputeRunner runner,
  required DateTime Function() clock,
}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = InMemoryLedgerStore(state: state, hasSeeded: true);
  final container = ProviderContainer(
    overrides: [
      storeProvider.overrideWithValue(store),
      databaseConnectionProvider.overrideWith(
        (ref) async => NativeDatabase.memory(),
      ),
      analysisComputeRunnerProvider.overrideWithValue(runner),
      clockProvider.overrideWithValue(clock),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, store: store);
}

Future<Ready> _readyPhase(ProviderContainer container) async {
  final boot = container.read(appBootProvider);
  while (boot.phase is! Ready) {
    await Future<void>.delayed(Duration.zero);
  }
  return boot.phase as Ready;
}

Future<void> _accept(ProviderContainer container) async {
  for (var i = 0; i < 100; i++) {
    final queries = container.read(analysisQueriesProvider);
    final session = container.read(ledgerSessionProvider);
    if (queries != null &&
        session != null &&
        session.analysisCache.itemsSourceRevision == session.ledger.revision) {
      return;
    }
    await pumpEventQueue();
  }
}

void main() {
  test('queriesProviderIsNullBeforeReadyAndStartsNoComputation', () async {
    final runner = _ManualRunner();
    final bundle = _container(
      state: _stateWithExpense(),
      runner: runner.call,
      clock: () => DateTime(2027, 4, 7, 12),
    );
    final container = bundle.container;

    final subscription = container.listen<AnalysisQueries?>(
      analysisQueriesProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    expect(container.read(ledgerProvider), isNull);
    expect(container.read(analysisQueriesProvider), isNull);
    expect(runner.pending, isEmpty);

    await _readyPhase(container);

    final queries = container.read(analysisQueriesProvider);
    expect(queries, isNotNull);
    expect(runner.pending, hasLength(1));

    final session = container.read(ledgerSessionProvider)!;
    runner.pending.last.complete(
      Accounting.analysisItems(session.ledger.state),
    );
    await pumpEventQueue();

    final today = queries!.readToday();
    expect(today.state, AnalysisQueryState.ready);
    expect(today.value?.spent, Decimal.parse('10.00'));
  });

  test(
    'pausedSubscriptionResumedAfterRetryReadsTheReplacementLedger',
    () async {
      var now = DateTime(2027, 4, 7, 12);
      final bundle = _container(
        state: _stateWithExpense(),
        runner: syncComputeRunner,
        clock: () => now,
      );
      final container = bundle.container;
      final boot = container.read(appBootProvider);
      await _readyPhase(container);

      final subscription = container.listen<AnalysisQueries?>(
        analysisQueriesProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await _accept(container);

      final oldQueries = container.read(analysisQueriesProvider)!;
      final oldLedger = container.read(ledgerProvider)!;
      expect(oldQueries.readToday().value?.spent, Decimal.parse('10.00'));

      subscription.pause();
      now = DateTime(2027, 4, 8, 12);
      container.invalidate(todayProvider);
      bundle.store.state.addEntry(
        Entry(
          id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
          amount: Decimal.parse('-5.00'),
          name: 'coffee',
          sourceID: _accountID,
          categoryID: _foodID,
          date: DateTime.utc(2027, 4, 8),
        ),
      );

      await boot.retry();
      await _readyPhase(container);
      subscription.resume();

      final queries = container.read(analysisQueriesProvider)!;
      expect(identical(queries, oldQueries), isFalse);
      expect(() => oldQueries.addListener(() {}), throwsFlutterError);
      final ledger = container.read(ledgerProvider)!;
      expect(identical(ledger, oldLedger), isFalse);
      expect(container.read(todayProvider), DateTime.utc(2027, 4, 8));

      await _accept(container);
      expect(queries.readToday().value?.day, DateTime.utc(2027, 4, 8));
      expect(queries.readToday().value?.spent, Decimal.parse('5.00'));
      expect(
        queries
            .readPeriod(
              window: DateRange(
                DateTime.utc(2027, 4, 1),
                DateTime.utc(2027, 5, 1),
              ),
            )
            .value
            ?.spent,
        Decimal.parse('15.00'),
      );
    },
  );

  test('nothingNotifiesAfterDisposal', () async {
    final runner = _ManualRunner();
    final bundle = _container(
      state: _stateWithExpense(),
      runner: runner.call,
      clock: () => DateTime(2027, 4, 7, 12),
    );
    final container = bundle.container;
    await _readyPhase(container);

    final subscription = container.listen<AnalysisQueries?>(
      analysisQueriesProvider,
      (_, _) {},
    );
    final queries = container.read(analysisQueriesProvider)!;
    var notifications = 0;
    queries.addListener(() => notifications++);
    runner.pending.last.complete(const []);
    await pumpEventQueue();
    expect(notifications, 1);

    container
        .read(ledgerProvider)!
        .addEntry(
          Entry(
            id: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
            amount: Decimal.parse('-5.00'),
            name: 'coffee',
            sourceID: _accountID,
            categoryID: _foodID,
            date: DateTime.utc(2027, 4, 7),
          ),
        );

    container.dispose();
    runner.pending.last.complete(const []);
    await pumpEventQueue();

    expect(notifications, 2);
    expect(() => queries.addListener(() {}), throwsFlutterError);
    expect(() => subscription.close(), returnsNormally);
  });
}
