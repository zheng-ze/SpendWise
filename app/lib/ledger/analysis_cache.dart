import 'dart:async';
import 'dart:isolate';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:spendwise/ledger/event_bus.dart';

typedef ComputeRunner =
    Future<List<AnalysisItem>> Function(List<AnalysisItem> Function() compute);

Future<List<AnalysisItem>> syncComputeRunner(
  List<AnalysisItem> Function() compute,
) async {
  return compute();
}

/// The isolate send deep-copies the captured state, and that copy is the
/// snapshot a mutation landing mid-compute cannot corrupt.
Future<List<AnalysisItem>> isolateComputeRunner(
  List<AnalysisItem> Function() compute,
) {
  return Isolate.run(compute);
}

class AnalysisCache extends ChangeNotifier {
  AnalysisCache({ComputeRunner? runner})
    : _runner = runner ?? (kIsWeb ? syncComputeRunner : isolateComputeRunner);

  final ComputeRunner _runner;

  StreamSubscription<List<LedgerChange>>? _subscription;

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

  void start(EventBus bus) {
    if (_subscription != null) return;

    _subscription = bus.subscribe().listen((_) {
      _revision += 1;
      notifyListeners();
    });
  }

  /// Fire-and-forget. Callers never await the items.
  void refresh(LedgerState state) {
    if (_lastComputed == _revision) return;

    final target = _revision;
    // Claimed before the compute starts, so a reentrant refresh at the same
    // generation cannot start a second pass.
    _lastComputed = target;

    unawaited(
      _runner(() => Accounting.analysisItems(state)).then((computed) {
        if (target != _lastComputed) return;

        _items = computed;
        _itemsRevision += 1;
        notifyListeners();
      }),
    );
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
