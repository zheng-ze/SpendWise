import 'dart:async';
import 'dart:isolate';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:spendwise/ledger/event_bus.dart';

typedef ComputeRunner = Future<List<AnalysisItem>> Function(LedgerState state);

/// Computes on the calling isolate. Tests inject this so a widget pump sees the
/// result without waiting on a real isolate.
Future<List<AnalysisItem>> syncComputeRunner(LedgerState state) async {
  return Accounting.analysisItems(state);
}

/// The isolate send deep-copies the captured state, and that copy is the
/// snapshot a mutation landing mid-compute cannot corrupt.
Future<List<AnalysisItem>> isolateComputeRunner(LedgerState state) {
  // A closure linking back to a calling instance sends the whole captured
  // context and fails as unsendable, so state is passed as a plain argument.
  return Isolate.run(() => Accounting.analysisItems(state));
}

class AnalysisCache extends ChangeNotifier {
  AnalysisCache({ComputeRunner? runner})
    : _runner = runner ?? isolateComputeRunner;

  final ComputeRunner _runner;

  StreamSubscription<List<LedgerChange>>? _subscription;

  EventBus? _bus;

  List<AnalysisItem> _items = const [];

  int _revision = 0;

  int _itemsRevision = 0;

  /// Highest revision a compute has been started for. The initial gap against
  /// [revision] is what makes the first refresh compute with no bus event.
  int _lastComputed = -1;

  List<AnalysisItem> get items => _items;

  int get revision => _revision;

  /// Moves only when [items] is replaced, so downstream memos key off this
  /// rather than [revision], which bumps on every batch.
  int get itemsRevision => _itemsRevision;

  /// A retry hands over a fresh bus, so this follows the new one rather than
  /// staying on a bus nobody publishes to.
  void start(EventBus bus) {
    if (identical(_bus, bus)) return;

    unawaited(_subscription?.cancel());
    _bus = bus;
    _subscription = bus.subscribe().listen((_) {
      _revision += 1;
      notifyListeners();
    });
  }

  /// Refreshes [items] from [state]. Callers may await the result or ignore it.
  Future<void> refresh(LedgerState state) async {
    if (_lastComputed == _revision) return;

    final target = _revision;
    // Claimed before the compute starts, so a reentrant refresh at the same
    // generation cannot start a second pass.
    _lastComputed = target;

    try {
      final computed = await _runner(state);
      if (target != _lastComputed) return;

      _items = computed;
      _itemsRevision += 1;
      notifyListeners();
    } catch (error, stackTrace) {
      // A failed compute must not get stuck reporting stale data forever,
      // so the next refresh() call is allowed to retry.
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
