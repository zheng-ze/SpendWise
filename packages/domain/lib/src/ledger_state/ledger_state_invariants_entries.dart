part of 'ledger_state.dart';

const _clauseEntriesActive = 9;
const _clauseNoStoredTombstone = 10;
const _clauseEntryInOneTable = 18;

extension LedgerStateEntryInvariants on LedgerState {
  // MARK: - Liveness

  void _assertEntriesActive() {
    for (final entry in _entries.values) {
      if (!entry.lifecycle.isActive) {
        throw _violation(
          _clauseEntriesActive,
          'entry ${entry.id} is ${entry.lifecycle.name}',
        );
      }
    }
    for (final entry in _binnedEntries.values) {
      if (entry.lifecycle != LifecycleState.archived) {
        throw _violation(
          _clauseEntriesActive,
          'binned entry ${entry.id} is ${entry.lifecycle.name}',
        );
      }
      if (entry.systemKind != null) {
        throw _violation(
          _clauseEntriesActive,
          'binned entry ${entry.id} is a system entry',
        );
      }
    }
  }

  void _assertEntryInOneTable() {
    for (final id in _entries.keys) {
      if (_binnedEntries.containsKey(id)) {
        throw _violation(
          _clauseEntryInOneTable,
          'entry $id is live and binned',
        );
      }
    }
  }

  // MARK: - Tombstones

  void _assertNoStoredTombstone() {
    for (final source in _moneySources.values) {
      if (source.lifecycle == LifecycleState.tombstoned) {
        throw _violation(
          _clauseNoStoredTombstone,
          'money source ${source.id} is stored tombstoned',
        );
      }
    }
    for (final category in _categories.values) {
      if (category.lifecycle == LifecycleState.tombstoned) {
        throw _violation(
          _clauseNoStoredTombstone,
          'category ${category.id} is stored tombstoned',
        );
      }
    }
  }
}
