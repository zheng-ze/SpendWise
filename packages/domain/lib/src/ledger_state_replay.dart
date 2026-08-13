part of 'ledger_state.dart';

extension LedgerStateReplay on LedgerState {
  /// Deleting a pocket here does not unlink it from its parent, because the
  /// mutation that emitted the deletion emitted the parent's upsert into the
  /// same stream. Replay trusts the stream to be complete.
  void apply(List<LedgerChange> changes) {
    for (final change in changes) {
      switch (change) {
        case UpsertAccount(:final account):
          _moneySources[account.id] = AccountSource(account);
        case UpsertPocket(:final pocket):
          _moneySources[pocket.id] = PocketSource(pocket);
        case UpsertCategory(:final category):
          _categories[category.id] = category;
        case UpsertEntry(:final entry):
          _entries[entry.id] = entry;
        case UpsertPlan(:final plan):
          _plans[plan.id] = plan;
        case DeleteMoneySource(:final id):
          _moneySources.remove(id);
        case DeleteCategory(:final id):
          _categories.remove(id);
        case DeleteEntry(:final id):
          _entries.remove(id);
        case DeletePlan(:final id):
          _plans.remove(id);
      }
    }
  }
}
