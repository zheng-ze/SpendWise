part of 'ledger_state.dart';

const _clauseKeysMatchIDs = 1;
const _clausePocketLinks = 2;
const _clauseNoOrphanPocket = 3;
const _clauseEntryReferences = 4;
const _clauseStatementDay = 13;
const _clausePocketLiveness = 15;

extension LedgerStateHolderInvariants on LedgerState {
  // MARK: - Identity

  void _assertKeysMatchIDs() {
    for (final MapEntry(:key, :value) in _moneySources.entries) {
      if (key != value.id) {
        throw _violation(
          _clauseKeysMatchIDs,
          'money source $key holds ${value.id}',
        );
      }
    }
    for (final MapEntry(:key, :value) in _allEntryPairs) {
      if (key != value.id) {
        throw _violation(_clauseKeysMatchIDs, 'entry $key holds ${value.id}');
      }
    }
    for (final MapEntry(:key, :value) in _categories.entries) {
      if (key != value.id) {
        throw _violation(
          _clauseKeysMatchIDs,
          'category $key holds ${value.id}',
        );
      }
    }
  }

  // MARK: - Pocket links

  void _assertPocketLinksResolveAndAreExclusive() {
    final claimedBy = <String, String>{};
    for (final account in _accounts) {
      for (final pocketID in account.subPocketIDs) {
        if (_moneySources[pocketID]?.asPocket == null) {
          throw _violation(
            _clausePocketLinks,
            'account ${account.id} links unresolved $pocketID',
          );
        }

        final other = claimedBy[pocketID];
        if (other != null) {
          throw _violation(
            _clausePocketLinks,
            'pocket $pocketID linked by $other and ${account.id}',
          );
        }
        claimedBy[pocketID] = account.id;
      }
    }
  }

  void _assertNoOrphanPocket() {
    for (final source in _moneySources.values) {
      final pocket = source.asPocket;
      if (pocket == null) continue;

      if (_owningAccount(pocket.id) == null) {
        throw _violation(
          _clauseNoOrphanPocket,
          'pocket ${pocket.id} has no owning account',
        );
      }
    }
  }

  void _assertPocketNotMoreAliveThanAccount() {
    for (final account in _accounts) {
      for (final pocketID in account.subPocketIDs) {
        final pocket = _moneySources[pocketID]?.asPocket;
        if (pocket == null) continue;

        if (!account.lifecycle.isAtLeastAsAliveAs(pocket.lifecycle)) {
          throw _violation(
            _clausePocketLiveness,
            '${account.lifecycle.name} account ${account.id} holds '
            '${pocket.lifecycle.name} pocket $pocketID',
          );
        }
      }
    }
  }

  // MARK: - Entry references

  void _assertNoDanglingEntryReference() {
    for (final entry in _allEntries) {
      for (final holderID in entry.holderIDs) {
        if (!_moneySources.containsKey(holderID)) {
          throw _violation(
            _clauseEntryReferences,
            'entry ${entry.id} references unknown $holderID',
          );
        }
      }
    }
  }

  // MARK: - Statement day

  void _assertStatementDayInRange() {
    for (final account in _accounts) {
      final statementDay = account.statementDay;
      if (account.type != AccountType.card) {
        if (statementDay != null) {
          throw _violation(
            _clauseStatementDay,
            '${account.type.name} account ${account.id} carries a statement day',
          );
        }
        continue;
      }

      if (statementDay != null &&
          (statementDay < Account.minStatementDay ||
              statementDay > Account.maxStatementDay)) {
        throw _violation(
          _clauseStatementDay,
          'card ${account.id} has statement day $statementDay',
        );
      }
    }
  }
}
