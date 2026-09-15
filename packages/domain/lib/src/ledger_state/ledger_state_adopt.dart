part of 'ledger_state.dart';

extension LedgerStateAdopt on LedgerState {
  /// Replaces every live table with [other]'s contents, keeping this object.
  ///
  /// The sync apply boundary validates [other] structurally before calling
  /// this, so the refill itself never throws. The lifecycle baseline refresh
  /// lives only inside the debug-only assert closure, which release builds
  /// skip entirely: no snapshot map is allocated there, and the next debug
  /// local mutation evaluates clause 12 against the post-sync baseline.
  void adopt(LedgerState other) {
    // A self-adoption would clear the tables it then reads back, so it is a
    // no-op up front.
    if (identical(this, other)) return;

    _moneySources
      ..clear()
      ..addAll(other._moneySources);
    _entries
      ..clear()
      ..addAll(other._entries);
    _categories
      ..clear()
      ..addAll(other._categories);
    _plans
      ..clear()
      ..addAll(other._plans);
    _budgets
      ..clear()
      ..addAll(other._budgets);
    assert(() {
      _lifecycleAtLastCheck = _lifecycleSnapshot();
      return true;
    }());
  }
}
