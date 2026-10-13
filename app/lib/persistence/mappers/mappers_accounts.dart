part of 'mappers.dart';

// MARK: - Accounts

Account accountFromRow(rows.Account row) => Account(
  id: row.id,
  name: row.name,
  type: _accountType(row.type),
  subPocketIDs: {
    for (final id in json.decode(row.subPocketIds) as List<dynamic>)
      id as String,
  },
  incomingTransfersAsExpenses: row.incomingTransfersAsExpenses,
  includeInNetWorth: row.includeInNetWorth,
  statementDay: row.statementDay,
  lifecycle: _lifecycle(row.lifecycle),
);

rows.Account accountToRow(Account account, VersionVector version) =>
    rows.Account(
      versionData: _versionToBlob(version),
      lifecycle: account.lifecycle.code,
      id: account.id,
      name: account.name,
      type: account.type.code,
      subPocketIds: json.encode(account.subPocketIDs.toList()),
      incomingTransfersAsExpenses: account.incomingTransfersAsExpenses,
      includeInNetWorth: account.includeInNetWorth,
      statementDay: account.statementDay,
    );

// MARK: - Pockets

SubPocket pocketFromRow(rows.SubPocket row) => SubPocket(
  id: row.id,
  name: row.name,
  incomingTransfersAsExpenses: row.incomingTransfersAsExpenses,
  lifecycle: _lifecycle(row.lifecycle),
);

rows.SubPocket pocketToRow(SubPocket pocket, VersionVector version) =>
    rows.SubPocket(
      versionData: _versionToBlob(version),
      lifecycle: pocket.lifecycle.code,
      id: pocket.id,
      name: pocket.name,
      incomingTransfersAsExpenses: pocket.incomingTransfersAsExpenses,
    );
