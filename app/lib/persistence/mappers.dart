import 'dart:convert';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:spendwise/persistence/ledger_database.dart' as rows;
import 'package:spendwise/persistence/version_vector.dart';

// An unrecognized code came from a newer writer, so the row loads as the
// documented default rather than failing the whole load.
AccountType _accountType(int code) => switch (code) {
  0 => AccountType.cash,
  1 => AccountType.checking,
  2 => AccountType.savings,
  3 => AccountType.card,
  4 => AccountType.prepaid,
  5 => AccountType.investment,
  6 => AccountType.insurance,
  8 => AccountType.loan,
  9 => AccountType.overdraft,
  _ => AccountType.other,
};

CategoryKind _categoryKind(int code) => code == CategoryKind.income.code
    ? CategoryKind.income
    : CategoryKind.expense;

LifecycleState _lifecycle(int code) => switch (code) {
  1 => LifecycleState.archived,
  2 => LifecycleState.referenceOnly,
  3 => LifecycleState.tombstoned,
  _ => LifecycleState.active,
};

RecurrenceFrequency _frequency(int code) => switch (code) {
  0 => RecurrenceFrequency.weekly,
  1 => RecurrenceFrequency.biweekly,
  3 => RecurrenceFrequency.quarterly,
  4 => RecurrenceFrequency.yearly,
  _ => RecurrenceFrequency.monthly,
};

VersionVector versionFromRow(Uint8List blob) => VersionVector.decode(blob);

Uint8List _versionToBlob(VersionVector version) =>
    Uint8List.fromList(version.encode());

/// Reads the calendar day and rebuilds midnight from it, since reading a
/// stored instant off midnight would move it a day for anyone east of Greenwich.
DateTime dayFromMillis(int millis) =>
    startOfDayUtc(DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true));

int millisFromDay(DateTime date) => date.millisecondsSinceEpoch;

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

/// Parentage is fixed at creation, so an upsert keeps the stored parent even
/// when the incoming category names a different one.
rows.Category categoryUpsertRow(
  TransactionCategory category,
  VersionVector version, {
  required rows.Category? stored,
}) {
  final row = categoryToRow(category, version);
  return stored == null ? row : row.copyWith(parentId: Value(stored.parentId));
}

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

RecurringPlan planFromRow(rows.Plan row) => RecurringPlan(
  id: row.id,
  template: EntryTemplate(
    amount: Decimal.parse(row.templateAmount),
    name: row.templateName,
    categoryID: row.templateCategoryId,
    sourceID: row.templateSourceId,
    destinationID: row.templateDestinationId,
    includeInAnalysis: row.templateIncludeInAnalysis,
  ),
  frequency: _frequency(row.frequency),
  anchor: dayFromMillis(row.anchor),
  endDate: row.endDate == null ? null : dayFromMillis(row.endDate!),
  lastResolvedDate: dayFromMillis(row.lastResolvedDate),
);

rows.Plan planToRow(
  RecurringPlan plan,
  VersionVector version, {
  LifecycleState lifecycle = LifecycleState.active,
}) => rows.Plan(
  versionData: _versionToBlob(version),
  lifecycle: lifecycle.code,
  id: plan.id,
  frequency: plan.frequency.code,
  anchor: millisFromDay(plan.anchor),
  endDate: plan.endDate == null ? null : millisFromDay(plan.endDate!),
  lastResolvedDate: millisFromDay(plan.lastResolvedDate),
  templateAmount: plan.template.amount.toString(),
  templateName: plan.template.name,
  templateCategoryId: plan.template.categoryID,
  templateSourceId: plan.template.sourceID,
  templateDestinationId: plan.template.destinationID,
  templateIncludeInAnalysis: plan.template.includeInAnalysis,
);
