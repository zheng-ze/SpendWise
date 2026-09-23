import 'dart:async';

import 'package:spendwise/ledger/event_bus.dart';

final class MutationFence {
  MutationFence(this._bus);

  final EventBus _bus;

  StreamSubscription<LedgerPublication>? _subscription;

  var _epoch = 0;

  void install() {
    if (_subscription != null) return;
    _subscription = _bus.subscribe().listen((_) {
      _epoch++;
    });
  }

  int snapshot() => _epoch;

  bool checkClean(int snapshot) => _epoch == snapshot;

  Future<void> uninstall() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
