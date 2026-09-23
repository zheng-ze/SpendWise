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

class AnalysisCache extends ChangeNotifier {
  AnalysisCache({ComputeRunner? runner})
    : _runner = runner ?? isolateComputeRunner;

  final ComputeRunner _runner;

  StreamSubscription<LedgerPublication>? _subscription;

  EventBus? _bus;

  List<AnalysisItem> _items = const [];

  int _revision = 0;

  int _itemsRevision = 0;

  int _lastComputed = -1;

  List<AnalysisItem> get items => _items;

  int get revision => _revision;

  int get itemsRevision => _itemsRevision;

  void start(EventBus bus) {
    if (identical(_bus, bus)) return;

    unawaited(_subscription?.cancel());
    _bus = bus;
    _subscription = bus.subscribe().listen((_) {
      _revision += 1;
      notifyListeners();
    });
  }

  Future<void> refresh(LedgerState state) async {
    if (_lastComputed == _revision) return;

    final target = _revision;
    _lastComputed = target;

    try {
      final computed = await _runner(state);
      if (target != _lastComputed) return;

      _items = computed;
      _itemsRevision += 1;
      notifyListeners();
    } catch (error, stackTrace) {
      if (target == _lastComputed) _lastComputed = -1;
      debugPrint('AnalysisCache refresh failed: $error\n$stackTrace');
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _bus = null;
    super.dispose();
  }
}
