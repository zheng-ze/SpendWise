import 'package:domain/domain.dart';
import 'package:spendwise/persistence/ledger_store.dart';

import 'in_memory_ledger_store.dart';

enum StoreCall { setErrorHandler, seedIfFirstLaunch, load, start, flushNow }

class RecordingLedgerStore extends InMemoryLedgerStore {
  RecordingLedgerStore({super.state, super.hasSeeded});

  final List<StoreCall> calls = [];

  StoreCall? failOn;

  final Object failure = StateError('store failed');

  void _record(StoreCall call) {
    calls.add(call);
    if (failOn == call) throw failure;
  }

  @override
  Future<void> setErrorHandler(SaveErrorHandler handler) async {
    _record(StoreCall.setErrorHandler);
    return super.setErrorHandler(handler);
  }

  @override
  Future<void> seedIfFirstLaunch(List<LedgerChange> changes) async {
    _record(StoreCall.seedIfFirstLaunch);
    return super.seedIfFirstLaunch(changes);
  }

  @override
  Future<LedgerState> load() async {
    _record(StoreCall.load);
    return super.load();
  }

  @override
  Future<void> start() async {
    _record(StoreCall.start);
    return super.start();
  }

  @override
  Future<void> flushNow() async {
    _record(StoreCall.flushNow);
    return super.flushNow();
  }
}
