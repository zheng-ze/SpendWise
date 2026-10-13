import 'dart:async';
import 'dart:collection';

import 'package:domain/domain.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:spendwise/persistence/store/device_identity.dart';
import 'package:spendwise/persistence/database/ledger_database.dart' as rows;
import 'package:spendwise/persistence/store/ledger_store.dart';
import 'package:spendwise/persistence/mappers/mappers.dart';
import 'package:sync/sync.dart';

// MARK: - Parts

part 'store_timer.dart';
part 'store_failures.dart';
part 'drift_store_loading.dart';
part 'drift_store_scheduling.dart';
part 'drift_store_writes.dart';

// MARK: - Configuration

const _debounce = Duration(milliseconds: 250);
const _maxRetries = 2;
const _retryBackoff = Duration(milliseconds: 200);

// MARK: - Store

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
}
