import 'dart:async';
import 'dart:isolate';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:spendwise/ledger/event_bus.dart';

typedef ComputeRunner = Future<List<AnalysisItem>> Function(LedgerState state);

Future<List<AnalysisItem>> syncComputeRunner(LedgerState state) async {
  return Accounting.analysisItems(state);
}

Future<List<AnalysisItem>> isolateComputeRunner(LedgerState state) {
  // Must not capture the calling instance; it would not send.
  return Isolate.run(() => Accounting.analysisItems(state));
}

class AnalysisCacheFailure {
  AnalysisCacheFailure({
    required this.error,
    required this.stackTrace,
    required this.sourceRevision,
  });

  final Object error;

  final StackTrace stackTrace;

  final int sourceRevision;
}

class AnalysisCache extends ChangeNotifier {
  AnalysisCache({ComputeRunner? runner})
    : _runner = runner ?? isolateComputeRunner;

  static const _uncomputedRevision = -1;

  final ComputeRunner _runner;

  StreamSubscription<LedgerPublication>? _subscription;

  EventBus? _bus;

  int Function()? _sourceRevision;

  bool _disposed = false;

  List<AnalysisItem> _items = const [];

  int _revision = 0;

  int _itemsRevision = 0;

  int _itemsSourceRevision = _uncomputedRevision;

  final Map<int, Future<void>> _pending = {};

  AnalysisCacheFailure? _lastFailure;

  List<AnalysisItem> get items => _items;

  int get revision => _revision;

  int get itemsRevision => _itemsRevision;

  int get itemsSourceRevision => _itemsSourceRevision;

  AnalysisCacheFailure? get lastFailure => _lastFailure;

  void start(EventBus bus, {int Function()? sourceRevision}) {
    if (identical(_bus, bus)) return;
    if (_bus != null) {
      throw StateError(
        'AnalysisCache is bound to one Ledger bus; create a new cache.',
      );
    }

    _bus = bus;
    _sourceRevision = sourceRevision;
    _subscription = bus.subscribe().listen((_) {
      if (_disposed) return;
      _revision += 1;
      notifyListeners();
    });
  }

  Future<void> refresh(LedgerState state, {int? sourceRevision}) {
    if (_disposed) return Future.value();
    final request = sourceRevision ?? _sourceRevision?.call() ?? _revision;
    if (request == _itemsSourceRevision) return Future.value();
    final running = _pending[request];
    if (running != null) return running;

    final captured = LedgerState(
      moneySources: state.moneySources,
      entries: state.entries,
      categories: state.categories,
      plans: state.plans,
      budgets: state.budgets,
    );
    final future = _run(request, captured);
    _pending[request] = future;
    return future;
  }

  Future<void> _run(int request, LedgerState captured) async {
    try {
      final computed = await _runner(captured);
      _pending.remove(request);
      if (_disposed || request <= _itemsSourceRevision) return;

      _items = List<AnalysisItem>.unmodifiable(computed);
      _itemsSourceRevision = request;
      _itemsRevision += 1;
      final failure = _lastFailure;
      if (failure != null && failure.sourceRevision <= request) {
        _lastFailure = null;
      }
      notifyListeners();
    } catch (error, stackTrace) {
      _pending.remove(request);
      if (_disposed || request <= _itemsSourceRevision) return;

      _lastFailure = AnalysisCacheFailure(
        error: error,
        stackTrace: stackTrace,
        sourceRevision: request,
      );
      debugPrint(
        'AnalysisCache refresh failed for source revision '
        '$request: $error\n$stackTrace',
      );
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _pending.clear();
    final subscription = _subscription;
    _subscription = null;
    _bus = null;
    _sourceRevision = null;
    super.dispose();
    await subscription?.cancel();
  }
}
