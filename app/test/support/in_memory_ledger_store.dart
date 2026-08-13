import 'dart:async';

import 'package:domain/domain.dart';
import 'package:spendwise/persistence/ledger_store.dart';

/// Ingest is queued in arrival order and applied only by [flushNow], standing
/// in for the real store's debounce window. That makes a missing flush visible
/// to a test rather than hidden by an eager apply.
class InMemoryLedgerStore implements LedgerStore {
  InMemoryLedgerStore({LedgerState? state, bool hasSeeded = false})
    : _state = state ?? LedgerState(),
      _seeded = hasSeeded;

  final LedgerState _state;

  bool _seeded;

  LedgerState get state => _state;

  bool get hasSeeded => _seeded;

  final List<List<LedgerChange>> _pending = [];

  final List<List<LedgerChange>> _enqueued = [];

  bool _started = false;

  bool get isStarted => _started;

  SaveErrorHandler? errorHandler;

  /// Batch boundaries stay intact, so a test can tell what the processor
  /// forwarded apart from what the store ended up holding.
  List<List<LedgerChange>> get enqueuedBatches =>
      List.unmodifiable(_enqueued.map(List<LedgerChange>.unmodifiable));

  @override
  Future<LedgerState> load() async => _state;

  @override
  Future<void> seedIfFirstLaunch(List<LedgerChange> changes) async {
    if (_seeded) return;

    // Set before enqueueing, so a crash mid-seed leaves a partial seed rather
    // than seeding twice on the next launch.
    _seeded = true;
    enqueue(changes);
    await flushNow();
  }

  @override
  Future<void> start() async {
    _started = true;
  }

  @override
  void enqueue(List<LedgerChange> changes) {
    if (changes.isEmpty) return;
    _enqueued.add(List<LedgerChange>.of(changes));
    _pending.add(List<LedgerChange>.of(changes));
  }

  @override
  Future<void> flushNow() async {
    await start();
    _drain();
  }

  @override
  Future<void> setErrorHandler(SaveErrorHandler handler) async {
    errorHandler = handler;
  }

  void _drain() {
    for (final batch in _pending) {
      _state.apply(batch);
    }
    _pending.clear();
  }
}
