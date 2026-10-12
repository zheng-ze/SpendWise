part of 'mappers.dart';

// MARK: - Entries

Entry entryFromRow(rows.Entry row) => Entry(
  id: row.id,
  date: dayFromMillis(row.date),
  amount: Decimal.parse(row.amount),
  name: row.name,
  categoryID: row.categoryId,
  sourceID: row.sourceId,
  destinationID: row.destinationId,
  includeInAnalysis: row.includeInAnalysis,
  lifecycle: _lifecycle(row.lifecycle),
  systemKind: SystemEntryKind.fromCode(row.systemKind),
);

rows.Entry entryToRow(Entry entry, VersionVector version) => rows.Entry(
  versionData: _versionToBlob(version),
  lifecycle: entry.lifecycle.code,
  id: entry.id,
  date: millisFromDay(entry.date),
  amount: entry.amount.toString(),
  name: entry.name,
  categoryId: entry.categoryID,
  sourceId: entry.sourceID,
  destinationId: entry.destinationID,
  includeInAnalysis: entry.includeInAnalysis,
  systemKind: entry.systemKind?.code,
);
