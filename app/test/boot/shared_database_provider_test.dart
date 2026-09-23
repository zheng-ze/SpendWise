import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/persistence/drift_ledger_store.dart';

class _CloseCountingExecutor extends QueryExecutor {
  _CloseCountingExecutor(this._inner);

  final QueryExecutor _inner;

  var closeCalls = 0;

  final _closed = Completer<void>();

  Future<void> get closed => _closed.future;

  @override
  SqlDialect get dialect => _inner.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => _inner.ensureOpen(user);

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) => _inner.runSelect(statement, args);

  @override
  Future<int> runInsert(String statement, List<Object?> args) =>
      _inner.runInsert(statement, args);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) =>
      _inner.runUpdate(statement, args);

  @override
  Future<int> runDelete(String statement, List<Object?> args) =>
      _inner.runDelete(statement, args);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) =>
      _inner.runCustom(statement, args);

  @override
  Future<void> runBatched(BatchedStatements statements) =>
      _inner.runBatched(statements);

  @override
  TransactionExecutor beginTransaction() => _inner.beginTransaction();

  @override
  QueryExecutor beginExclusive() => _inner.beginExclusive();

  @override
  Future<void> close() async {
    closeCalls += 1;
    await _inner.close();
    _closed.complete();
  }
}

final class _DatabaseDisposeCounter extends ProviderObserver {
  var ledgerDatabaseDisposes = 0;

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    if (context.provider == ledgerDatabaseProvider) {
      ledgerDatabaseDisposes += 1;
    }
  }
}

class _FlakyOpener {
  var calls = 0;

  Future<QueryExecutor> open() async {
    calls += 1;
    if (calls == 1) throw StateError('connection failed');
    return NativeDatabase.memory();
  }
}

ProviderContainer _containerWith({
  required Future<QueryExecutor> Function(Ref ref) connection,
  List<ProviderObserver>? observers,
}) {
  final container = ProviderContainer(
    overrides: [databaseConnectionProvider.overrideWith(connection)],
    observers: observers,
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ledgerStoreAndSyncMetadataShareTheOneBootDatabase', () async {
    final executor = _CloseCountingExecutor(NativeDatabase.memory());
    final container = _containerWith(connection: (ref) async => executor);

    final database = container.read(ledgerDatabaseProvider);
    final store = container.read(storeProvider) as DriftLedgerStore;
    final syncStore = container.read(syncMetadataStoreProvider);

    expect(identical(store.db, database), isTrue);
    expect(identical(syncStore.database, database), isTrue);
  });

  test('tearingDownTheContainerClosesOneExecutorAndOneDatabase', () async {
    final executor = _CloseCountingExecutor(NativeDatabase.memory());
    final observer = _DatabaseDisposeCounter();
    final container = _containerWith(
      connection: (ref) async => executor,
      observers: [observer],
    );

    final store = container.read(storeProvider) as DriftLedgerStore;
    await store.load();
    await container.read(syncMetadataStoreProvider).snapshot();

    container.dispose();
    await executor.closed;

    expect(executor.closeCalls, 1);
    expect(observer.ledgerDatabaseDisposes, 1);
  });

  test('flakyConnectionStillFailsOnceThenReachesReadyAfterRetry', () async {
    final opener = _FlakyOpener();
    final container = _containerWith(connection: (ref) => opener.open());

    final boot = container.read(appBootProvider);
    while (boot.phase is! Failed) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(opener.calls, 1);

    final staleDatabase = container.read(ledgerDatabaseProvider);

    await boot.retry();

    expect(boot.phase, isA<Ready>());
    expect(opener.calls, 2);
    expect(
      identical(container.read(ledgerDatabaseProvider), staleDatabase),
      isFalse,
    );
  });
}
