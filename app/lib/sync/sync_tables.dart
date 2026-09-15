import 'package:drift/drift.dart';
import 'package:sync/sync.dart';

/// Reads and writes a `collection` column as a typed [SyncCollection].
class SyncCollectionConverter extends TypeConverter<SyncCollection, String> {
  const SyncCollectionConverter();

  @override
  SyncCollection fromSql(String fromDb) => SyncCollection.fromWireName(fromDb);

  @override
  String toSql(SyncCollection value) => value.wireName;
}

/// Reads and writes a version-data column as a typed [VersionVector].
class VersionVectorConverter extends TypeConverter<VersionVector, Uint8List> {
  const VersionVectorConverter();

  @override
  VersionVector fromSql(Uint8List fromDb) => VersionVector.decode(fromDb);

  @override
  Uint8List toSql(VersionVector value) => Uint8List.fromList(value.encode());
}

/// Singleton sync-coordination row, sibling to the device-local `store_meta`.
///
/// Holds the nullable backend selection, the durable enrollment phase, the
/// write-enabled gate, and the five per-collection pull watermarks. Bearer
/// tokens, the E2E key, and the opaque credential payload never enter this
/// table; `SecretStore` owns them separately.
@DataClassName('SyncMetadataRow')
class SyncMeta extends Table {
  IntColumn get id => integer()();

  /// Selected backend profile (`supabase` or `custom`). Null until enrollment.
  TextColumn get backend => text().nullable()();

  /// Endpoint configuration for a custom backend. Null until enrollment and
  /// unused by managed backends.
  TextColumn get endpoint => text().nullable()();

  /// Durable enrollment phase as an explicit [SyncEnrollmentPhase] code.
  IntColumn get enrollmentPhase =>
      integer().named('enrollment_phase').withDefault(const Constant(0))();

  /// Write-enabled gate. Only a durable reconciliation-complete phase permits
  /// flipping this on; credential presence alone never enables writes.
  BoolColumn get writeEnabled =>
      boolean().named('write_enabled').withDefault(const Constant(false))();

  /// Durable per-collection pull cursors. Each is the last staged and
  /// acknowledged checkpoint for its collection, null before the first pull.
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

/// Composite acknowledged version vectors, keyed by [SyncRowID].
///
/// One row per synced collection and row records the exact submitted vector
/// the server applied or already held, so push-candidate selection can tell a
/// synced row from a locally edited one.
@DataClassName('AcknowledgedVectorRow')
class SyncAcknowledgedVectors extends Table {
  TextColumn get collection => text().map(const SyncCollectionConverter())();

  TextColumn get rowId => text().named('row_id')();

  BlobColumn get versionData =>
      blob().named('version_data').map(const VersionVectorConverter())();

  @override
  Set<Column<Object>> get primaryKey => {collection, rowId};
}

/// Durable pending pull acknowledgements, keyed by collection.
///
/// One row per collection records the staged-but-unacknowledged checkpoint.
/// The row is removed only after the backend confirms the acknowledgement, so
/// startup can retry it before any new pull or push work.
@DataClassName('PendingAcknowledgementRow')
class SyncPendingAcknowledgements extends Table {
  TextColumn get collection => text().map(const SyncCollectionConverter())();

  TextColumn get checkpoint => text()();

  @override
  Set<Column<Object>> get primaryKey => {collection};
}

/// Durable staged-conflict groups, keyed by [SyncRowID].
///
/// Insertion order carries oldest-first ordering: groups are read back with
/// `ORDER BY rowid`, and re-staging a group deletes and re-inserts its row so
/// a replacement moves to the newest position, matching the in-memory store.
@DataClassName('StagedConflictRow')
class SyncStagedConflicts extends Table {
  TextColumn get collection => text().map(const SyncCollectionConverter())();

  TextColumn get rowId => text().named('row_id')();

  @override
  Set<Column<Object>> get primaryKey => {collection, rowId};
}

/// Decrypted staged siblings belonging to one conflict group.
///
/// Each sibling keeps its stable sibling ID, its version vector in the
/// existing integer-counter persistence codec, and its payload in the
/// versioned package-codec bytes (empty for tombstones, whose delete the
/// lifecycle column identifies). `position` preserves the decoded sibling
/// order the engine produced.
@DataClassName('StagedSiblingRow')
class SyncStagedSiblings extends Table {
  TextColumn get collection => text().map(const SyncCollectionConverter())();

  TextColumn get rowId => text().named('row_id')();

  TextColumn get siblingId => text().named('sibling_id')();

  BlobColumn get versionData =>
      blob().named('version_data').map(const VersionVectorConverter())();

  BlobColumn get payload => blob()();

  /// Explicit sibling-lifecycle code: 0 is live, 1 is tombstone.
  IntColumn get lifecycle => integer()();

  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {collection, rowId, siblingId};
}
