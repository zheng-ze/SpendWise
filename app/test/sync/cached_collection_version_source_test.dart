import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/sync/cached_collection_version_source.dart';
import 'package:spendwise/sync/collection_version_reader.dart';
import 'package:sync/sync.dart';

const _deviceA = 'aaaaaaaa-0000-1111-2222-333333333333';
const _deviceB = 'bbbbbbbb-0000-1111-2222-333333333333';

const _categoriesRow = '22222222-2222-2222-2222-222222222222';
const _entriesRow = '33333333-3333-3333-3333-333333333333';
const _unknownRow = '66666666-6666-6666-6666-666666666666';

RowVersion _version(
  String deviceID,
  int counter, [
  SiblingLifecycle lifecycle = SiblingLifecycle.live,
]) => RowVersion(
  versionVector: VersionVector({deviceID: counter}),
  lifecycle: lifecycle,
);

Map<SyncRowID, RowVersion> _seededRows() => {
  SyncRowID.of(SyncCollection.categories, _categoriesRow): _version(
    _deviceA,
    2,
  ),
  SyncRowID.of(SyncCollection.entries, _entriesRow): _version(
    _deviceB,
    3,
    SiblingLifecycle.tombstone,
  ),
};

final class _FailingReader implements CollectionVersionReader {
  _FailingReader(this._inner);

  final InMemoryCollectionVersionReader _inner;
  SyncCollection? failOn;
  Object? failure;

  @override
  Future<Map<SyncRowID, RowVersion>> readRowVersions(
    SyncCollection collection,
  ) async {
    final failure = this.failure;
    if (collection == failOn && failure != null) throw failure;
    return _inner.readRowVersions(collection);
  }
}

void main() {
  test('refresh publishes every seeded row with exact versions', () async {
    final seeded = _seededRows();
    final source = CachedCollectionVersionSource(
      InMemoryCollectionVersionReader(seeded),
    );

    await source.refresh();

    for (final entry in seeded.entries) {
      expect(source.readRowVersion(entry.key), entry.value);
    }
    expect(
      source
          .readRowVersion(SyncRowID.of(SyncCollection.entries, _entriesRow))
          ?.lifecycle,
      SiblingLifecycle.tombstone,
    );
  });

  test('failed refresh retains previous cache and rethrows', () async {
    final inner = InMemoryCollectionVersionReader(_seededRows());
    final reader = _FailingReader(inner);
    final source = CachedCollectionVersionSource(reader);
    await source.refresh();

    final failure = Exception('plans read failed');
    reader
      ..failOn = SyncCollection.plans
      ..failure = failure;
    inner.upsert(
      SyncRowID.of(SyncCollection.categories, _unknownRow),
      _version(_deviceA, 9),
    );

    await expectLater(source.refresh(), throwsA(same(failure)));

    for (final entry in _seededRows().entries) {
      expect(source.readRowVersion(entry.key), entry.value);
    }
    expect(
      source.readRowVersion(
        SyncRowID.of(SyncCollection.categories, _unknownRow),
      ),
      isNull,
    );
  });
}
