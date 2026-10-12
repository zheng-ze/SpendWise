part of 'mappers.dart';

// MARK: - Categories

TransactionCategory categoryFromRow(rows.Category row) => TransactionCategory(
  id: row.id,
  name: row.name,
  kind: _categoryKind(row.kind),
  colorHex: row.colorHex,
  includeInAnalysis: row.includeInAnalysis,
  parentID: row.parentId,
  symbol: row.symbol,
  lifecycle: _lifecycle(row.lifecycle),
);

rows.Category categoryToRow(
  TransactionCategory category,
  VersionVector version,
) => rows.Category(
  versionData: _versionToBlob(version),
  lifecycle: category.lifecycle.code,
  id: category.id,
  name: category.name,
  kind: category.kind.code,
  colorHex: category.colorHex,
  includeInAnalysis: category.includeInAnalysis,
  parentId: category.parentID,
  symbol: category.symbol,
);

rows.Category categoryUpsertRow(
  TransactionCategory category,
  VersionVector version, {
  required rows.Category? stored,
}) {
  final row = categoryToRow(category, version);
  return stored == null ? row : row.copyWith(parentId: Value(stored.parentId));
}
