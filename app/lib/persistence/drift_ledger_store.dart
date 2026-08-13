import 'dart:async';
import 'dart:collection';

import 'package:domain/domain.dart';
import 'package:drift/drift.dart';
import 'package:spendwise/persistence/ledger_database.dart' as rows;
import 'package:spendwise/persistence/ledger_store.dart';
import 'package:spendwise/persistence/mappers.dart';
import 'package:spendwise/persistence/version_vector.dart';

/// A cancellable pending callback. Tests supply their own so the suite never
/// waits out a real debounce or backoff.
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

const _debounce = Duration(milliseconds: 250);
const _maxRetries = 2;
const _retryBackoff = Duration(milliseconds: 200);

class DriftLedgerStore implements LedgerStore {
  DriftLedgerStore(this.db, {this._armTimer = _armRealTimer});

  final rows.LedgerDatabase db;

  final ArmTimer _armTimer;

  final Queue<List<LedgerChange>> _ingest = Queue();

  final List<LedgerChange> _pending = [];

  SaveErrorHandler? _handler;

  bool _started = false;

  StoreTimer? _debounceTimer;

  StoreTimer? _retryTimer;

  Future<void>? _inFlightSave;

  /// Swift reported `clear` on every success, so a healthy app emitted banner
  /// transitions for a problem it never had.
  bool _reportedNonClear = false;

  /// Set while a timed retry cycle runs, so those attempts do not flip the
  /// banner back to `retrying` and make it flicker.
  bool _inTimedRetry = false;

  int get debugPendingLength => _pending.length;

  Future<void> debugSaveCycle() => _saveCycle();

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
  Future<LedgerState> load() async {
    throw UnimplementedError('load lands with task group 7');
  }

  @override
  Future<void> seedIfFirstLaunch(List<LedgerChange> changes) async {
    throw UnimplementedError('seedIfFirstLaunch lands with task group 7');
  }

  @override
  Future<void> flushNow() async {
    throw UnimplementedError('flushNow lands with task group 6');
  }

  void _drain() {
    if (_ingest.isEmpty) return;
    while (_ingest.isNotEmpty) {
      _pending.addAll(_ingest.removeFirst());
    }
    _armDebounce();
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

  /// Only a transition is reported. Reporting `clear` puts the store back in
  /// the clear state, so the next healthy save is silent again.
  void _report(SaveBannerState state) {
    final isClear = state == SaveBannerState.clear;
    if (isClear && !_reportedNonClear) return;
    _reportedNonClear = !isClear;
    _handler?.call(state);
  }

  /// Serialized behind one future. The save and the backoff are both awaits, so
  /// two overlapping cycles would otherwise apply the same pending prefix twice.
  Future<void> _saveCycle() {
    final running = _inFlightSave;
    if (running != null) return running;

    final cycle = _runCycle();
    _inFlightSave = cycle;
    return cycle.whenComplete(() => _inFlightSave = null);
  }

  Future<void> _runCycle() async {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      if (_pending.isEmpty) return;

      // The applied list is coalesced, the cleared count is raw. Clearing the
      // coalesced count would leave written changes pending, and clearing more
      // would drop batches buffered while the save was in flight.
      final taken = _pending.length;
      final coalesced = _coalesce(_pending.sublist(0, taken));

      try {
        await db.transaction(() async {
          for (final change in coalesced) {
            await _apply(change);
          }
        });
      } on Object {
        if (attempt < _maxRetries) {
          if (!_inTimedRetry) _report(SaveBannerState.retrying);
          await _wait(_retryBackoff);
          continue;
        }
        _report(SaveBannerState.failedWillRetry);
        _armTimedRetry();
        return;
      }

      _pending.removeRange(0, taken);
      _report(SaveBannerState.clear);
      return;
    }
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

  /// Keeps the last change per target, each survivor sitting at the index of
  /// its final occurrence rather than its first. Upserts and deletions share the
  /// keyspace, so an upsert followed by a deletion of the same id applies only
  /// the deletion.
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
        final version = await _bumpedVersion(db.accounts, account.id);
        await db
            .into(db.accounts)
            .insertOnConflictUpdate(accountToRow(account, version));
      case UpsertPocket(:final pocket):
        final version = await _bumpedVersion(db.subPockets, pocket.id);
        await db
            .into(db.subPockets)
            .insertOnConflictUpdate(pocketToRow(pocket, version));
      case UpsertCategory(:final category):
        final stored = await _categoryRow(category.id);
        final version = await _bumpedVersion(db.categories, category.id);
        await db
            .into(db.categories)
            .insertOnConflictUpdate(
              categoryUpsertRow(category, version, stored: stored),
            );
      case UpsertEntry(:final entry):
        final version = await _bumpedVersion(db.entries, entry.id);
        await db
            .into(db.entries)
            .insertOnConflictUpdate(entryToRow(entry, version));
      case UpsertPlan(:final plan):
        final version = await _bumpedVersion(db.plans, plan.id);
        await db
            .into(db.plans)
            .insertOnConflictUpdate(planToRow(plan, version));
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

  /// An absent row starts from the empty vector, so an insert-then-bump lands
  /// with a single counter at one.
  Future<VersionVector> _bumpedVersion(
    TableInfo<Table, dynamic> table,
    String id,
  ) async {
    final stored = await _storedVersion(table.actualTableName, id);
    final version = stored == null
        ? VersionVector.empty
        : versionFromRow(stored);
    return version.bump(await _device);
  }

  Future<bool> _tombstone(TableInfo<Table, dynamic> table, String id) async {
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
