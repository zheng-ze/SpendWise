import 'package:drift/drift.dart';

/// `store_meta` is device-local and so is the one table that stays out.
mixin SyncedRow on Table {
  BlobColumn get versionData => blob().named('version_data')();

  IntColumn get lifecycle => integer()();
}

class Accounts extends Table with SyncedRow {
  TextColumn get id => text()();

  TextColumn get name => text()();

  IntColumn get type => integer()();

  /// Parentage lives here alone, so a pocket row has no back pointer to read it
  /// from.
  TextColumn get subPocketIds => text().named('sub_pocket_ids')();

  BoolColumn get incomingTransfersAsExpenses =>
      boolean().named('incoming_transfers_as_expenses')();

  BoolColumn get includeInNetWorth => boolean().named('include_in_net_worth')();

  IntColumn get statementDay => integer().named('statement_day').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SubPockets extends Table with SyncedRow {
  TextColumn get id => text()();

  TextColumn get name => text()();

  BoolColumn get incomingTransfersAsExpenses =>
      boolean().named('incoming_transfers_as_expenses')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Categories extends Table with SyncedRow {
  TextColumn get id => text()();

  TextColumn get name => text()();

  IntColumn get kind => integer()();

  TextColumn get colorHex => text().named('color_hex')();

  BoolColumn get includeInAnalysis => boolean().named('include_in_analysis')();

  /// No foreign key: a category may outlive its parent as a reference-only row.
  TextColumn get parentId => text().named('parent_id').nullable()();

  TextColumn get symbol => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Entries extends Table with SyncedRow {
  TextColumn get id => text()();

  IntColumn get date => integer()();

  /// A float column would not round-trip the stored amount.
  TextColumn get amount => text()();

  TextColumn get name => text()();

  TextColumn get categoryId => text().named('category_id').nullable()();

  TextColumn get sourceId => text().named('source_id')();

  TextColumn get destinationId => text().named('destination_id').nullable()();

  BoolColumn get includeInAnalysis => boolean().named('include_in_analysis')();

  /// Reserved and never written by this version. Adding either column later
  /// costs a migration, so they are claimed now while the schema is still v1.
  TextColumn get note => text().nullable()();

  /// Marks a synthetic entry: 0 opening balance, 1 balance adjustment, null for
  /// a user entry.
  IntColumn get systemKind => integer().named('system_kind').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Plans extends Table with SyncedRow {
  TextColumn get id => text()();

  IntColumn get frequency => integer()();

  IntColumn get anchor => integer()();

  IntColumn get endDate => integer().named('end_date').nullable()();

  IntColumn get lastResolvedDate => integer().named('last_resolved_date')();

  TextColumn get templateAmount => text().named('template_amount')();

  TextColumn get templateName => text().named('template_name')();

  TextColumn get templateCategoryId =>
      text().named('template_category_id').nullable()();

  TextColumn get templateSourceId => text().named('template_source_id')();

  TextColumn get templateDestinationId =>
      text().named('template_destination_id').nullable()();

  BoolColumn get templateIncludeInAnalysis =>
      boolean().named('template_include_in_analysis')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Budgets extends Table with SyncedRow {
  TextColumn get id => text()();

  TextColumn get categoryId => text().named('category_id').nullable()();

  /// JSON-encoded array of {effectiveFromMonth, value, kind}.
  TextColumn get limitEvents => text().named('limit_events')();

  TextColumn get createdAtMonth => text().named('created_at_month')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Device-local, so it carries neither a version vector nor a lifecycle. The
/// fixed key holds it to one row.
@DataClassName('StoreMetaRow')
class StoreMeta extends Table {
  IntColumn get id => integer()();

  TextColumn get deviceId => text().named('device_id')();

  BoolColumn get hasSeeded =>
      boolean().named('has_seeded').withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 0)'];
}
