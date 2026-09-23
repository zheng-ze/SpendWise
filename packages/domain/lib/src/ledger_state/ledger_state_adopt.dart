part of 'ledger_state.dart';

extension LedgerStateAdopt on LedgerState {
  void adopt(LedgerState other) {
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
