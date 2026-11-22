part of 'drift_ledger_store.dart';

// MARK: - Loading

Future<List<LedgerChange>> loadChanges(rows.LedgerDatabase db) async {
  Future<List<D>> every<T extends Table, D extends DataClass>(
    TableInfo<T, D> table,
  ) async {
    final found = await db
        .customSelect(
          'SELECT * FROM ${table.actualTableName}',
          readsFrom: {table},
        )
        .get();
    return [for (final row in found) await table.map(row.data)];
  }

  final accounts = await every(db.accounts);
  final pockets = await every(db.subPockets);
  final categories = await every(db.categories);
  final entries = await every(db.entries);
  final plans = await every(db.plans);
  final budgets = await every(db.budgets);

  return [
    for (final row in accounts) UpsertAccount(accountFromRow(row)),
    for (final row in pockets) UpsertPocket(pocketFromRow(row)),
    for (final row in categories) UpsertCategory(categoryFromRow(row)),
    for (final row in entries) UpsertEntry(entryFromRow(row)),
    for (final row in plans) UpsertPlan(planFromRow(row)),
    for (final row in budgets) UpsertBudget(budgetFromRow(row)),
  ];
}
