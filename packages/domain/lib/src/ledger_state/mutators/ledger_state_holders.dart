part of '../ledger_state.dart';

extension LedgerStateHolders on LedgerState {
  // MARK: - Accounts

  List<LedgerChange> addAccount(Account account) => _addAccount(account);

  List<LedgerChange> updateAccount(Account account) => _updateAccount(account);

  List<LedgerChange> deleteAccount(String rawID) => _deleteAccount(rawID);

  List<LedgerChange> restoreAccount(String rawID) => _restoreAccount(rawID);

  // MARK: - Pockets

  List<LedgerChange> addPocket(SubPocket pocket, String rawAccountID) =>
      _addPocket(pocket, rawAccountID);

  List<LedgerChange> updatePocket(SubPocket pocket) => _updatePocket(pocket);

  List<LedgerChange> deletePocket(String rawID) => _deletePocket(rawID);

  List<LedgerChange> restorePocket(String rawID) => _restorePocket(rawID);
}
