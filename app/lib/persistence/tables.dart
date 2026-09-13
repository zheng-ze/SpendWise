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

/// Device-local sync metadata, fixed to one row. Backend selection stays null
/// until enrollment. Enrollment phase and the write gate live here and carry
/// neither a bearer token, E2E key, opaque credential, nor a second device ID.
@DataClassName('SyncMetadataRow')
class SyncMetadata extends Table {
  IntColumn get id => integer()();

  /// Selected backend profile and endpoint configuration. Null until
  /// enrollment, so a pre-enrollment read never infers a backend.
  TextColumn get backendSelection => text().nullable()();

  /// Monotonic durable enrollment phase, stored as its explicit code. Null
  /// before enrollment starts; only a reconciliation-complete phase permits
  /// the idempotent gate flip.
  IntColumn get enrollmentPhase => integer().nullable()();

  /// Whether new sync runs may start. Defaults off so a fresh or migrated
  /// store never enables writes before enrollment.
  BoolColumn get writeGate => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 0)'];
}

/// One per-collection pull watermark, stored as an encoded version vector. Five
/// rows, one for each sync collection.
class SyncWatermark extends Table {
  TextColumn get collection => text()();

  BlobColumn get versionData => blob().named('version_data')();

  @override
  Set<Column<Object>> get primaryKey => {collection};
}

/// A version vector the backend has acknowledged for one normalized collection
/// and row id, so identical UUIDs in different collections stay independent.
class SyncAcknowledgedVector extends Table {
  TextColumn get collection => text()();

  TextColumn get rowID => text().named('row_id')();

  BlobColumn get versionData => blob().named('version_data')();

  @override
  Set<Column<Object>> get primaryKey => {collection, rowID};
}

/// A pull-page acknowledgement still owed to the backend, keyed by collection
/// and checkpoint. Retained across failures until acknowledged succeeds.
class SyncPendingAck extends Table {
  TextColumn get collection => text()();

  TextColumn get checkpoint => text()();

  @override
  Set<Column<Object>> get primaryKey => {collection, checkpoint};
}

/// One durable conflict group: the decrypted staged siblings for one collection
/// and row, ordered oldest first by the auto-increment sequence.
class SyncStagingGroup extends Table {
  /// Insertion order: oldest-first ordering reads this column ascending.
  IntColumn get sequence => integer().autoIncrement()();

  TextColumn get collection => text()();

  TextColumn get rowID => text().named('row_id')();

  /// JSON-serialized, decrypted staged siblings for this group.
  BlobColumn get siblings => blob().named('sibling_data')();

  @override
  List<String> get customConstraints => ['UNIQUE (collection, row_id)'];
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
