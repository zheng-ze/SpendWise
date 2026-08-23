import 'dart:async';
import 'dart:collection';

import 'package:domain/domain.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:spendwise/persistence/ledger_database.dart' as rows;
import 'package:spendwise/persistence/ledger_store.dart';
import 'package:spendwise/persistence/mappers.dart';
import 'package:spendwise/persistence/version_vector.dart';

// Tests supply their own so the suite never waits out a real debounce or backoff.
abstract class StoreTimer {
  void cancel();
}

typedef ArmTimer = StoreTimer Function(Duration delay, void Function() onFire);

class _RealTimer implements StoreTimer {
  _RealTimer(Duration delay, void Function() onFire)
    : _timer = Timer(delay, onFire);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

StoreTimer _armRealTimer(Duration delay, void Function() onFire) =>
    _RealTimer(delay, onFire);

// Rides the ingest queue alongside the batches. Completing it on the drain
// loop is what proves every batch queued ahead of it is already in `pending`.
class _Barrier {
  final Completer<void> reached = Completer<void>();
}

/// Replay order is fixed: accounts, pockets, categories, entries, plans, budgets.
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

  final List<LedgerChange> _pending = [];

  SaveErrorHandler? _handler;

  bool _started = false;

  StoreTimer? _debounceTimer;

  StoreTimer? _retryTimer;

  Future<void>? _inFlightSave;

  // Reporting `clear` on every success would emit banner transitions for a
  // problem the app never had.
  bool _reportedNonClear = false;

  // Set while a timed retry cycle runs, so those attempts do not flip the
  // banner back to `retrying` and make it flicker.
  bool _inTimedRetry = false;

  bool _lastCycleGaveUp = false;

  // Cleared only once the transaction carrying it has committed, so a rolled
  // back seed stays unseeded.
  bool _seedFlagPending = false;

  /// The number of changes buffered but not yet committed to the database.
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
    _ingest.add(List<LedgerChange>.of(changes));
    if (_started) _drain();
  }

  @override
  Future<void> setErrorHandler(SaveErrorHandler handler) async {
    _handler = handler;
  }

  @override
  Future<LedgerState> load() async =>
      LedgerState.replaying(await loadChanges(db));

  /// The flag rides the save transaction rather than a transaction of its own,
  /// so a crash before that commit leaves it unset with no seed rows and the
  /// next launch seeds cleanly.
  @override
  Future<void> seedIfFirstLaunch(List<LedgerChange> changes) async {
    final meta = await db.select(db.storeMeta).getSingleOrNull();
    if (meta?.hasSeeded ?? false) return;

    _seedFlagPending = true;
    enqueue(changes);
    await flushNow();
  }

  /// Everything enqueued before this call is on disk when it returns.
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

    // One trailing save would return with anything buffered during that save
    // still unwritten.
    while (_pending.isNotEmpty) {
      await _saveCycle();
      // The timed retry owns recovery from a failing disk. Without this exit
      // the loop would spin against it and never return.
      if (_lastCycleGaveUp) return;
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
      _pending.addAll(item as List<LedgerChange>);
      buffered = true;
    }
    // A queue holding only barriers has nothing new to save, so arming the
    // debounce would wake an idle store.
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

  // Reporting `clear` puts the store back in the clear state, so the next
  // healthy save is silent again.
  void _report(SaveBannerState state) {
    final isClear = state == SaveBannerState.clear;
    if (isClear && !_reportedNonClear) return;
    _reportedNonClear = !isClear;
    _handler?.call(state);
  }

  // The save and the backoff are both awaits, so two overlapping cycles would
  // otherwise apply the same pending prefix twice.
  Future<void> _saveCycle() {
    final running = _inFlightSave;
    if (running != null) return running;

    final cycle = _runCycle();
    _inFlightSave = cycle;
    return cycle.whenComplete(() => _inFlightSave = null);
  }

  Future<void> _runCycle() async {
    _lastCycleGaveUp = false;
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      if (_pending.isEmpty && !_seedFlagPending) return;

      // The applied list is coalesced, the cleared count is raw. Clearing the
      // coalesced count would leave written changes pending, and clearing more
      // would drop batches buffered while the save was in flight.
      final taken = _pending.length;
      final coalesced = _coalesce(_pending.sublist(0, taken));

      final seedingThisCycle = _seedFlagPending;

      try {
        await db.transaction(() async {
          for (final change in coalesced) {
            await _apply(change);
          }
          if (seedingThisCycle) await _writeSeedFlag();
        });
      } on Object {
        if (attempt < _maxRetries) {
          if (!_inTimedRetry) _report(SaveBannerState.retrying);
          await _wait(_retryBackoff);
          continue;
        }
        _lastCycleGaveUp = true;
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

  // An upsert rather than an update: the device id is cached on first claim, so a rolled back
  // insert leaves the cache holding an id no row carries and a bare update would match nothing.
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

  // Each survivor sits at its final occurrence's index. Upserts and deletions share the keyspace,
  // so an upsert followed by a deletion of the same id applies only the deletion.
  static List<LedgerChange> _coalesce(List<LedgerChange> changes) {
    final lastIndex = <String, int>{};
    for (var i = 0; i < changes.length; i++) {
      lastIndex[changes[i].targetID] = i;
    }
    final kept = lastIndex.values.toList()..sort();
    return [for (final i in kept) changes[i]];
  }

  Future<String> get _device => deviceID(db);

  Future<void> _apply(LedgerChange change) async {
    switch (change) {
      case UpsertAccount(:final account):
        await _upsert(db.accounts, account.id, (v) => accountToRow(account, v));
      case UpsertPocket(:final pocket):
        await _upsert(db.subPockets, pocket.id, (v) => pocketToRow(pocket, v));
      case UpsertCategory(:final category):
        final stored = await _categoryRow(category.id);
        await _upsert(
          db.categories,
          category.id,
          (v) => categoryUpsertRow(category, v, stored: stored),
        );
      case UpsertEntry(:final entry):
        await _upsert(db.entries, entry.id, (v) => entryToRow(entry, v));
      case UpsertPlan(:final plan):
        await _upsert(db.plans, plan.id, (v) => planToRow(plan, v));
      case UpsertBudget(:final budget):
        await _upsert(db.budgets, budget.id, (v) => budgetToRow(budget, v));
      case DeleteMoneySource(:final id):
        // One id space over two tables, so a miss in accounts falls through.
        if (!await _tombstone(db.accounts, id)) {
          await _tombstone(db.subPockets, id);
        }
      case DeleteCategory(:final id):
        await _tombstone(db.categories, id);
      case DeleteEntry(:final id):
        await _tombstone(db.entries, id);
      case DeletePlan(:final id):
        await _tombstone(db.plans, id);
      case DeleteBudget(:final id):
        await _tombstone(db.budgets, id);
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

  Future<VersionVector> _bumpedVersion<T extends Table, D extends DataClass>(
    TableInfo<T, D> table,
    String id,
  ) async {
    final stored = await _storedVersion(table.actualTableName, id);
    final version = stored == null
        ? VersionVector.empty
        : versionFromRow(stored);
    return version.bump(await _device);
  }

  Future<void> _upsert<T extends Table, D extends DataClass>(
    TableInfo<T, D> table,
    String id,
    Insertable<D> Function(VersionVector version) toRow,
  ) async {
    final version = await _bumpedVersion(table, id);
    await db.into(table).insertOnConflictUpdate(toRow(version));
  }

  Future<bool> _tombstone<T extends Table, D extends DataClass>(
    TableInfo<T, D> table,
    String id,
  ) async {
    final name = table.actualTableName;
    final stored = await _storedVersion(name, id);
    if (stored == null) return false;

    final bumped = versionFromRow(stored).bump(await _device);
    await db.customUpdate(
      'UPDATE $name SET lifecycle = ?, version_data = ? WHERE id = ?',
      variables: [
        Variable<int>(LifecycleState.tombstoned.code),
        Variable<Uint8List>(Uint8List.fromList(bumped.encode())),
        Variable<String>(normalizedID(id)),
      ],
      updates: {table},
    );
    return true;
  }
}
