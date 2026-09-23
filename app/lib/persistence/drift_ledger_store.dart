import 'dart:async';
import 'dart:collection';

import 'package:domain/domain.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:spendwise/persistence/device_identity.dart';
import 'package:spendwise/persistence/ledger_database.dart' as rows;
import 'package:spendwise/persistence/ledger_store.dart';
import 'package:spendwise/persistence/mappers.dart';
import 'package:sync/sync.dart';

abstract class StoreTimer {
  void cancel();
}

typedef ArmTimer = StoreTimer Function(Duration delay, void Function() onFire);

class PermanentSaveError implements Exception {
  const PermanentSaveError(this.reason);

  final String reason;

  @override
  String toString() => 'PermanentSaveError($reason)';
}

final class PersistenceBarrierFailure implements Exception {
  const PersistenceBarrierFailure(this.message, {this.cause, this.stackTrace});

  final String message;

  final Object? cause;

  final StackTrace? stackTrace;

  @override
  String toString() => 'PersistenceBarrierFailure: $message';
}

class _RealTimer implements StoreTimer {
  _RealTimer(Duration delay, void Function() onFire)
    : _timer = Timer(delay, onFire);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

StoreTimer _armRealTimer(Duration delay, void Function() onFire) =>
    _RealTimer(delay, onFire);

class _Barrier {
  final Completer<void> reached = Completer<void>();
}

final class _StampedChange {
  const _StampedChange(this.change, [this.stamp]);

  final LedgerChange change;

  final VersionVector? stamp;
}

final class _CoalescedWrite {
  const _CoalescedWrite(this.change, this.stamp, this.carried);

  final LedgerChange change;

  final VersionVector? stamp;

  final VersionVector? carried;
}

Future<List<LedgerChange>> loadChanges(rows.LedgerDatabase db) async {
  Future<List<D>> live<T extends Table, D extends DataClass>(
    TableInfo<T, D> table,
  ) async {
    final found = await db
        .customSelect(
          'SELECT * FROM ${table.actualTableName} WHERE lifecycle != ?',
          variables: [Variable<int>(LifecycleState.tombstoned.code)],
          readsFrom: {table},
        )
        .get();
    return [for (final row in found) await table.map(row.data)];
  }

  final accounts = await live(db.accounts);
  final pockets = await live(db.subPockets);
  final categories = await live(db.categories);
  final entries = await live(db.entries);
  final plans = await live(db.plans);
  final budgets = await live(db.budgets);

  return [
    for (final row in accounts) UpsertAccount(accountFromRow(row)),
    for (final row in pockets) UpsertPocket(pocketFromRow(row)),
    for (final row in categories) UpsertCategory(categoryFromRow(row)),
    for (final row in entries) UpsertEntry(entryFromRow(row)),
    for (final row in plans) UpsertPlan(planFromRow(row)),
    for (final row in budgets) UpsertBudget(budgetFromRow(row)),
  ];
}

const _debounce = Duration(milliseconds: 250);
const _maxRetries = 2;
const _retryBackoff = Duration(milliseconds: 200);

class DriftLedgerStore implements LedgerStore {
  DriftLedgerStore(this.db, {this._armTimer = _armRealTimer});

  final rows.LedgerDatabase db;

  final ArmTimer _armTimer;

  final Queue<Object> _ingest = Queue();

  final List<_StampedChange> _pending = [];

  SaveErrorHandler? _handler;

  bool _started = false;

  StoreTimer? _debounceTimer;

  StoreTimer? _retryTimer;

  Future<void>? _inFlightSave;

  bool _reportedNonClear = false;

  bool _inTimedRetry = false;

  bool _lastCycleGaveUp = false;

  Object? _lastFailure;

  StackTrace? _lastFailureStack;

  bool _seedFlagPending = false;

  @visibleForTesting
  int get pendingCount => _pending.length;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _drain();
  }

  @override
  void enqueue(List<LedgerChange> changes) {
    if (changes.isEmpty) return;
    _ingest.add([for (final change in changes) _StampedChange(change)]);
    if (_started) _drain();
  }

  @override
  void enqueueStamped(
    List<LedgerChange> changes,
    Map<SyncRowID, VersionVector> stamps,
  ) {
    if (changes.isEmpty) return;
    _ingest.add([
      for (final change in changes)
        _StampedChange(
          change,
          stamps[SyncRowID.of(collectionFor(change), change.targetID)],
        ),
    ]);
    if (_started) _drain();
  }

  @override
  Future<void> setErrorHandler(SaveErrorHandler handler) async {
    _handler = handler;
  }

  @override
  Future<LedgerState> load() async =>
      LedgerState.replaying(await loadChanges(db));

  @override
  Future<void> seedIfFirstLaunch(List<LedgerChange> changes) async {
    final meta = await db.select(db.storeMeta).getSingleOrNull();
    if (meta?.hasSeeded ?? false) return;

    _seedFlagPending = true;
    enqueue(changes);
    await flushNow();
  }

  @override
  Future<void> flushNow() async {
    await start();

    final barrier = _Barrier();
    _ingest.add(barrier);
    _drain();
    await barrier.reached.future;

    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _inFlightSave;

    while (_pending.isNotEmpty) {
      await _saveCycle();
      if (_lastCycleGaveUp) {
        throw PersistenceBarrierFailure(
          'The persistence barrier gave up with writes still pending.',
          cause: _lastFailure,
          stackTrace: _lastFailureStack,
        );
      }
    }
  }

  void _drain() {
    if (_ingest.isEmpty) return;
    var buffered = false;
    while (_ingest.isNotEmpty) {
      final item = _ingest.removeFirst();
      if (item is _Barrier) {
        item.reached.complete();
        continue;
      }
      _pending.addAll(item as List<_StampedChange>);
      buffered = true;
    }
    if (buffered) _armDebounce();
  }

  void _armDebounce() {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _retryTimer = null;
    _debounceTimer = _armTimer(_debounce, () {
      _debounceTimer = null;
      unawaited(_saveCycle());
    });
  }

  void _report(SaveBannerState state) {
    final isClear = state == SaveBannerState.clear;
    if (isClear && !_reportedNonClear) return;
    _reportedNonClear = !isClear;
    _handler?.call(state);
  }

  Future<void> _saveCycle() {
    final running = _inFlightSave;
    if (running != null) return running;

    final cycle = _runCycle();
    _inFlightSave = cycle;
    return cycle.whenComplete(() => _inFlightSave = null);
  }

  Future<void> _runCycle() async {
    _lastCycleGaveUp = false;
    _lastFailure = null;
    _lastFailureStack = null;
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      if (_pending.isEmpty && !_seedFlagPending) return;

      final taken = _pending.length;
      final coalesced = _coalesce(_pending.sublist(0, taken));

      final seedingThisCycle = _seedFlagPending;

      try {
        await db.transaction(() async {
          for (final write in coalesced) {
            await _apply(write);
          }
          if (seedingThisCycle) await _writeSeedFlag();
        });
      } on PermanentSaveError catch (error, stackTrace) {
        _lastCycleGaveUp = true;
        _lastFailure = error;
        _lastFailureStack = stackTrace;
        _report(SaveBannerState.permanentlyFailed);
        return;
      } on Object catch (error, stackTrace) {
        if (attempt < _maxRetries) {
          if (!_inTimedRetry) _report(SaveBannerState.retrying);
          await _wait(_retryBackoff);
          continue;
        }
        _lastCycleGaveUp = true;
        _lastFailure = error;
        _lastFailureStack = stackTrace;
        _report(SaveBannerState.failedWillRetry);
        _armTimedRetry();
        return;
      }

      _pending.removeRange(0, taken);
      if (seedingThisCycle) _seedFlagPending = false;
      _report(SaveBannerState.clear);
      return;
    }
  }

  Future<void> _writeSeedFlag() async {
    await db
        .into(db.storeMeta)
        .insertOnConflictUpdate(
          rows.StoreMetaRow(id: 0, deviceId: await _device, hasSeeded: true),
        );
  }

  void _armTimedRetry() {
    _retryTimer?.cancel();
    _retryTimer = _armTimer(_retryBackoff, () {
      _retryTimer = null;
      _inTimedRetry = true;
      unawaited(_saveCycle().whenComplete(() => _inTimedRetry = false));
    });
  }

  Future<void> _wait(Duration delay) {
    final completer = Completer<void>();
    _armTimer(delay, completer.complete);
    return completer.future;
  }

  static List<_CoalescedWrite> _coalesce(List<_StampedChange> pending) {
    final lastIndex = <SyncRowID, int>{};
    final carried = <SyncRowID, VersionVector>{};
    for (var i = 0; i < pending.length; i++) {
      final change = pending[i].change;
      final row = SyncRowID.of(collectionFor(change), change.targetID);
      lastIndex[row] = i;
      final stamp = pending[i].stamp;
      if (stamp != null) {
        final soFar = carried[row];
        carried[row] = soFar == null ? stamp : _pointwiseMax(soFar, stamp);
      }
    }
    final kept = lastIndex.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return [
      for (final survivor in kept)
        _CoalescedWrite(
          pending[survivor.value].change,
          pending[survivor.value].stamp,
          carried[survivor.key],
        ),
    ];
  }

  static VersionVector _pointwiseMax(VersionVector a, VersionVector b) {
    final counters = Map<String, int>.of(a.counters);
    for (final entry in b.counters.entries) {
      final current = counters[entry.key];
      if (current == null || entry.value > current) {
        counters[entry.key] = entry.value;
      }
    }
    return VersionVector(counters);
  }

  static VersionVector _withFloor(VersionVector stored, VersionVector? floor) =>
      floor == null ? stored : _pointwiseMax(floor, stored);

  Future<String> get _device => deviceID(db);

  Future<void> _apply(_CoalescedWrite write) async {
    final change = write.change;
    switch (change) {
      case UpsertAccount(:final account):
        await _upsert(
          db.accounts,
          account.id,
          write,
          (v) => accountToRow(account, v),
        );
      case UpsertPocket(:final pocket):
        await _upsert(
          db.subPockets,
          pocket.id,
          write,
          (v) => pocketToRow(pocket, v),
        );
      case UpsertCategory(:final category):
        final stored = await _categoryRow(category.id);
        await _upsert(
          db.categories,
          category.id,
          write,
          (v) => categoryUpsertRow(category, v, stored: stored),
        );
      case UpsertEntry(:final entry):
        await _upsert(db.entries, entry.id, write, (v) => entryToRow(entry, v));
      case UpsertPlan(:final plan):
        await _upsert(db.plans, plan.id, write, (v) => planToRow(plan, v));
      case UpsertBudget(:final budget):
        await _upsert(
          db.budgets,
          budget.id,
          write,
          (v) => budgetToRow(budget, v),
        );
      case DeleteMoneySource(:final id):
        if (!await _tombstone(db.accounts, id, write)) {
          if (!await _tombstone(db.subPockets, id, write)) {
            await _writeOrphanIfStamped(SyncCollection.moneySources, id, write);
          }
        }
      case DeleteCategory(:final id):
        if (!await _tombstone(db.categories, id, write)) {
          await _writeOrphanIfStamped(SyncCollection.categories, id, write);
        }
      case DeleteEntry(:final id):
        if (!await _tombstone(db.entries, id, write)) {
          await _writeOrphanIfStamped(SyncCollection.entries, id, write);
        }
      case DeletePlan(:final id):
        if (!await _tombstone(db.plans, id, write)) {
          await _writeOrphanIfStamped(SyncCollection.plans, id, write);
        }
      case DeleteBudget(:final id):
        if (!await _tombstone(db.budgets, id, write)) {
          await _writeOrphanIfStamped(SyncCollection.budgets, id, write);
        }
    }
  }

  Future<rows.Category?> _categoryRow(String id) => (db.select(
    db.categories,
  )..where((row) => row.id.equals(normalizedID(id)))).getSingleOrNull();

  Future<Uint8List?> _storedVersion(String table, String id) async {
    final row = await db
        .customSelect(
          'SELECT version_data FROM $table WHERE id = ?',
          variables: [Variable<String>(normalizedID(id))],
        )
        .getSingleOrNull();
    return row?.read<Uint8List>('version_data');
  }

  VersionVector _decodeVersion(Uint8List stored) {
    try {
      return versionFromRow(stored);
    } on VersionVectorDecodeError catch (error) {
      throw PermanentSaveError(error.message);
    }
  }

  Future<VersionVector> _bumpedVersion<T extends Table, D extends DataClass>(
    TableInfo<T, D> table,
    String id, [
    VersionVector? floor,
  ]) async {
    final stored = await _storedVersion(table.actualTableName, id);
    final version = stored == null
        ? VersionVector.empty
        : _decodeVersion(stored);
    return _withFloor(version, floor).bump(await _device);
  }

  Future<void> _upsert<T extends Table, D extends DataClass>(
    TableInfo<T, D> table,
    String id,
    _CoalescedWrite write,
    Insertable<D> Function(VersionVector version) toRow,
  ) async {
    final collection = collectionFor(write.change);
    final orphan = await _orphanVersion(collection, id);
    if (orphan == null) {
      final version =
          write.stamp ?? await _bumpedVersion(table, id, write.carried);
      await db.into(table).insertOnConflictUpdate(toRow(version));
      return;
    }
    await _clearOrphan(collection, id);
    final stamp = write.stamp;
    if (stamp != null) {
      final version = _pointwiseMax(orphan, stamp);
      await db.into(table).insertOnConflictUpdate(toRow(version));
      return;
    }
    final floor = _pointwiseMax(orphan, write.carried ?? VersionVector.empty);
    final version = await _bumpedVersion(table, id, floor);
    await db.into(table).insertOnConflictUpdate(toRow(version));
  }

  Future<bool> _tombstone<T extends Table, D extends DataClass>(
    TableInfo<T, D> table,
    String id,
    _CoalescedWrite write,
  ) async {
    final name = table.actualTableName;
    final stored = await _storedVersion(name, id);
    if (stored == null) return false;

    final version =
        write.stamp ??
        _withFloor(_decodeVersion(stored), write.carried).bump(await _device);
    await db.customUpdate(
      'UPDATE $name SET lifecycle = ?, version_data = ? WHERE id = ?',
      variables: [
        Variable<int>(LifecycleState.tombstoned.code),
        Variable<Uint8List>(Uint8List.fromList(version.encode())),
        Variable<String>(normalizedID(id)),
      ],
      updates: {table},
    );
    return true;
  }

  Future<VersionVector?> _orphanVersion(
    SyncCollection collection,
    String id,
  ) async {
    final row = await db
        .customSelect(
          'SELECT version_data FROM sync_orphan_tombstones '
          'WHERE collection = ? AND row_id = ?',
          variables: [
            Variable<String>(collection.wireName),
            Variable<String>(normalizedID(id)),
          ],
          readsFrom: {db.syncOrphanTombstones},
        )
        .getSingleOrNull();
    final stored = row?.read<Uint8List>('version_data');
    return stored == null ? null : _decodeVersion(stored);
  }

  Future<void> _writeOrphanIfStamped(
    SyncCollection collection,
    String id,
    _CoalescedWrite write,
  ) async {
    final stamp = write.stamp;
    if (stamp == null) return;
    await db
        .into(db.syncOrphanTombstones)
        .insertOnConflictUpdate(
          rows.OrphanTombstoneRow(
            collection: collection,
            rowId: normalizedID(id),
            versionData: stamp,
          ),
        );
  }

  Future<void> _clearOrphan(SyncCollection collection, String id) async {
    await db.customUpdate(
      'DELETE FROM sync_orphan_tombstones WHERE collection = ? AND row_id = ?',
      variables: [
        Variable<String>(collection.wireName),
        Variable<String>(normalizedID(id)),
      ],
      updates: {db.syncOrphanTombstones},
    );
  }
}
