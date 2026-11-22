part of 'drift_ledger_store.dart';

// MARK: - Write Model

class _Barrier {
  final Completer<void> reached = Completer<void>();
}

enum _RowKind { moneySources, categories, entries, plans, budgets }

typedef _RowKey = (_RowKind, String);

_RowKey _rowKey(LedgerChange change) {
  final kind = switch (change) {
    UpsertAccount() ||
    UpsertPocket() ||
    DeleteMoneySource() => _RowKind.moneySources,
    UpsertCategory() || DeleteCategory() => _RowKind.categories,
    UpsertEntry() || DeleteEntry() => _RowKind.entries,
    UpsertPlan() || DeletePlan() => _RowKind.plans,
    UpsertBudget() || DeleteBudget() => _RowKind.budgets,
  };
  return (kind, normalizedID(change.targetID));
}

// MARK: - Coalescing

List<LedgerChange> _coalesce(List<LedgerChange> pending) {
  final lastIndex = <_RowKey, int>{};
  for (var i = 0; i < pending.length; i++) {
    lastIndex[_rowKey(pending[i])] = i;
  }
  final kept = lastIndex.values.toList()..sort();
  return [for (final index in kept) pending[index]];
}

// MARK: - Applying

extension _DriftStoreWrites on DriftLedgerStore {
  Future<void> _apply(LedgerChange change) async {
    switch (change) {
      case UpsertAccount(:final account):
        await db
            .into(db.accounts)
            .insertOnConflictUpdate(accountToRow(account));
      case UpsertPocket(:final pocket):
        await db
            .into(db.subPockets)
            .insertOnConflictUpdate(pocketToRow(pocket));
      case UpsertCategory(:final category):
        final stored = await _categoryRow(category.id);
        await db
            .into(db.categories)
            .insertOnConflictUpdate(
              categoryUpsertRow(category, stored: stored),
            );
      case UpsertEntry(:final entry):
        await db
            .into(db.entries)
            .insertOnConflictUpdate(entryToRow(entry).toCompanion(false));
      case UpsertPlan(:final plan):
        final row = planToRow(plan).toCompanion(true);
        await db
            .into(db.plans)
            .insertOnConflictUpdate(
              row.copyWith(templateNote: Value(plan.template.note)),
            );
      case UpsertBudget(:final budget):
        await db.into(db.budgets).insertOnConflictUpdate(budgetToRow(budget));
      case DeleteMoneySource(:final id):
        if (await _delete(db.accounts, id)) return;
        await _delete(db.subPockets, id);
      case DeleteCategory(:final id):
        await _delete(db.categories, id);
      case DeleteEntry(:final id):
        await _delete(db.entries, id);
      case DeletePlan(:final id):
        await _delete(db.plans, id);
      case DeleteBudget(:final id):
        await _delete(db.budgets, id);
    }
  }

  Future<void> _writeSeedFlag() async {
    await db
        .into(db.storeMeta)
        .insertOnConflictUpdate(
          const rows.StoreMetaRow(id: 0, hasSeeded: true),
        );
  }

  Future<rows.Category?> _categoryRow(String id) => (db.select(
    db.categories,
  )..where((row) => row.id.equals(normalizedID(id)))).getSingleOrNull();

  Future<bool> _delete<T extends Table, D extends DataClass>(
    TableInfo<T, D> table,
    String id,
  ) async {
    final affected = await db.customUpdate(
      'DELETE FROM ${table.actualTableName} WHERE id = ?',
      variables: [Variable<String>(normalizedID(id))],
      updates: {table},
    );
    return affected > 0;
  }
}
