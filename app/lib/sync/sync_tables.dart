import 'package:drift/drift.dart';
import 'package:sync/sync.dart';

class SyncCollectionConverter extends TypeConverter<SyncCollection, String> {
  const SyncCollectionConverter();

  @override
  SyncCollection fromSql(String fromDb) => SyncCollection.fromWireName(fromDb);

  @override
  String toSql(SyncCollection value) => value.wireName;
}

class VersionVectorConverter extends TypeConverter<VersionVector, Uint8List> {
  const VersionVectorConverter();

  @override
  VersionVector fromSql(Uint8List fromDb) => VersionVector.decode(fromDb);

  @override
  Uint8List toSql(VersionVector value) => Uint8List.fromList(value.encode());
}

@DataClassName('SyncMetadataRow')
class SyncMeta extends Table {
  IntColumn get id => integer()();

  TextColumn get backend => text().nullable()();

  TextColumn get endpoint => text().nullable()();

  IntColumn get enrollmentPhase =>
      integer().named('enrollment_phase').withDefault(const Constant(0))();

  BoolColumn get writeEnabled =>
      boolean().named('write_enabled').withDefault(const Constant(false))();

  IntColumn get deviceBindingState =>
      integer().named('device_binding_state').withDefault(const Constant(0))();

  IntColumn get reauthResumePhase =>
      integer().named('reauth_resume_phase').nullable()();

  TextColumn get moneySourcesCursor =>
      text().named('money_sources_cursor').nullable()();

  TextColumn get entriesCursor => text().named('entries_cursor').nullable()();

  TextColumn get categoriesCursor =>
      text().named('categories_cursor').nullable()();

  TextColumn get plansCursor => text().named('plans_cursor').nullable()();

  TextColumn get budgetsCursor => text().named('budgets_cursor').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 0)'];
}

@DataClassName('AcknowledgedVectorRow')
class SyncAcknowledgedVectors extends Table {
  TextColumn get collection => text().map(const SyncCollectionConverter())();

  TextColumn get rowId => text().named('row_id')();

  BlobColumn get versionData =>
      blob().named('version_data').map(const VersionVectorConverter())();

  @override
  Set<Column<Object>> get primaryKey => {collection, rowId};
}

@DataClassName('PendingAcknowledgementRow')
class SyncPendingAcknowledgements extends Table {
  TextColumn get collection => text().map(const SyncCollectionConverter())();

  TextColumn get checkpoint => text()();

  @override
  Set<Column<Object>> get primaryKey => {collection};
}

@DataClassName('OrphanTombstoneRow')
class SyncOrphanTombstones extends Table {
  TextColumn get collection => text().map(const SyncCollectionConverter())();

  TextColumn get rowId => text().named('row_id')();

  BlobColumn get versionData =>
      blob().named('version_data').map(const VersionVectorConverter())();

  @override
  Set<Column<Object>> get primaryKey => {collection, rowId};
}

@DataClassName('StagedConflictRow')
class SyncStagedConflicts extends Table {
  TextColumn get collection => text().map(const SyncCollectionConverter())();

  TextColumn get rowId => text().named('row_id')();

  @override
  Set<Column<Object>> get primaryKey => {collection, rowId};
}

@DataClassName('StagedSiblingRow')
class SyncStagedSiblings extends Table {
  TextColumn get collection => text().map(const SyncCollectionConverter())();

  TextColumn get rowId => text().named('row_id')();

  TextColumn get siblingId => text().named('sibling_id')();

  BlobColumn get versionData =>
      blob().named('version_data').map(const VersionVectorConverter())();

  BlobColumn get payload => blob()();

  IntColumn get lifecycle => integer()();

  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {collection, rowId, siblingId};
}
