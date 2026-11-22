import 'dart:async';

import 'package:domain/domain.dart';
import 'package:spendwise/persistence/store/ledger_store.dart';

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

  List<List<LedgerChange>> get enqueuedBatches =>
      List.unmodifiable(_enqueued.map(List<LedgerChange>.unmodifiable));

  @override
  Future<LedgerState> load() async => _state;

  @override
  Future<void> seedIfFirstLaunch(List<LedgerChange> changes) async {
    if (_seeded) return;

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
