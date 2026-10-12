part of 'drift_ledger_store.dart';

// MARK: - Timer

abstract class StoreTimer {
  void cancel();
}

typedef ArmTimer = StoreTimer Function(Duration delay, void Function() onFire);

StoreTimer _armRealTimer(Duration delay, void Function() onFire) =>
    _RealTimer(delay, onFire);

class _RealTimer implements StoreTimer {
  _RealTimer(Duration delay, void Function() onFire)
    : _timer = Timer(delay, onFire);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}
