import 'package:drift/drift.dart';

/// Marks tables that sync. StoreMeta omits it to stay device-local.
mixin SyncedRow on Table {
  BlobColumn get versionData => blob().named('version_data')();

  IntColumn get lifecycle => integer()();
}

class Accounts extends Table with SyncedRow {
  TextColumn get id => text()();

  TextColumn get name => text()();

  IntColumn get type => integer()();

  /// Holds parentage here alone. A pocket row holds no parent link.
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

  /// Holds no foreign key. A category can outlive its parent.
  TextColumn get parentId => text().named('parent_id').nullable()();

  TextColumn get symbol => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Entries extends Table with SyncedRow {
  TextColumn get id => text()();

  IntColumn get date => integer()();

  // Text keeps the stored amount exact.
  TextColumn get amount => text()();

  TextColumn get name => text()();

  TextColumn get categoryId => text().named('category_id').nullable()();

  TextColumn get sourceId => text().named('source_id')();

  TextColumn get destinationId => text().named('destination_id').nullable()();

  BoolColumn get includeInAnalysis => boolean().named('include_in_analysis')();

  // Reserves the column. This version never writes it.
  TextColumn get note => text().nullable()();

  /// Marks a synthetic entry. 0 means opening balance, 1 means
  /// balance adjustment, and null means a user entry.
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

  /// Holds limit changes as JSON with month, value, and kind.
  TextColumn get limitEvents => text().named('limit_events')();

  TextColumn get createdAtMonth => text().named('created_at_month')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Holds device-local sync metadata in one row. Backend selection stays
/// null until enrollment.
@DataClassName('SyncMetadataRow')
class SyncMetadata extends Table {
  IntColumn get id => integer()();

  /// Holds the selected backend. Stays null until enrollment.
  TextColumn get backendSelection => text().nullable()();

  /// Holds the enrollment phase as its explicit code. Stays null before
  /// enrollment starts.
  IntColumn get enrollmentPhase => integer().nullable()();

  /// Whether new sync runs start. Defaults off.
  BoolColumn get writeGate => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 0)'];
}

/// Holds one opaque pull cursor per collection. Never holds a version vector.
class SyncWatermark extends Table {
  TextColumn get collection => text()();

  TextColumn get cursor => text()();

  @override
  Set<Column<Object>> get primaryKey => {collection};
}

/// Holds one acknowledged version vector per collection and row.
class SyncAcknowledgedVector extends Table {
  TextColumn get collection => text()();

  TextColumn get rowID => text().named('row_id')();

  BlobColumn get versionData => blob().named('version_data')();

  @override
  Set<Column<Object>> get primaryKey => {collection, rowID};
}

/// Holds one owed pull acknowledgement per collection and checkpoint.
/// Stays durable across failures until cleared.
class SyncPendingAck extends Table {
  TextColumn get collection => text()();

  TextColumn get checkpoint => text()();

  @override
  Set<Column<Object>> get primaryKey => {collection, checkpoint};
}

/// Holds one durable conflict group per collection and row. Reads oldest
/// first by sequence.
class SyncStagingGroup extends Table {
  /// Orders groups oldest first when read ascending.
  IntColumn get sequence => integer().autoIncrement()();

  TextColumn get collection => text()();

  TextColumn get rowID => text().named('row_id')();

  /// Holds the decrypted staged siblings for this group as JSON.
  BlobColumn get siblings => blob().named('sibling_data')();

  @override
  List<String> get customConstraints => ['UNIQUE (collection, row_id)'];
}

/// Holds device-local metadata in one row. Carries neither version nor
/// lifecycle.
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
