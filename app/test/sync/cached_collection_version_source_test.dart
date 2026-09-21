import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/sync/cached_collection_version_source.dart';
import 'package:spendwise/sync/collection_version_reader.dart';
import 'package:sync/sync.dart';

const _deviceA = 'aaaaaaaa-0000-1111-2222-333333333333';
const _deviceB = 'bbbbbbbb-0000-1111-2222-333333333333';

const _moneySourcesRow = '11111111-1111-1111-1111-111111111111';
const _categoriesRow = '22222222-2222-2222-2222-222222222222';
const _entriesRow = '33333333-3333-3333-3333-333333333333';
const _plansRow = '44444444-4444-4444-4444-444444444444';
const _budgetsRow = '55555555-5555-5555-5555-555555555555';
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
  SyncRowID.of(SyncCollection.moneySources, _moneySourcesRow): _version(
    _deviceA,
    1,
  ),
  SyncRowID.of(SyncCollection.categories, _categoriesRow): _version(
    _deviceA,
    2,
  ),
  SyncRowID.of(SyncCollection.entries, _entriesRow): _version(
    _deviceB,
    3,
    SiblingLifecycle.tombstone,
  ),
  SyncRowID.of(SyncCollection.plans, _plansRow): _version(_deviceA, 4),
  SyncRowID.of(SyncCollection.budgets, _budgetsRow): _version(_deviceB, 5),
};

/// Delegates to an in-memory reader but throws [failure] for [failOn].
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

/// Blocks every collection read on [gate] so overlapping refreshes can be
/// observed; counts underlying reads.
final class _GatedReader implements CollectionVersionReader {
  _GatedReader(this._rows, this._gate);

  final Map<SyncRowID, RowVersion> _rows;
  final Completer<void> _gate;
  int calls = 0;

  @override
  Future<Map<SyncRowID, RowVersion>> readRowVersions(
    SyncCollection collection,
  ) async {
    calls++;
    await _gate.future;
    return {
      for (final entry in _rows.entries)
        if (entry.key.collection == collection) entry.key: entry.value,
    };
  }
}

void main() {
  test('readRowVersion returns null before refresh', () {
    final source = CachedCollectionVersionSource(
      InMemoryCollectionVersionReader(_seededRows()),
    );

    for (final entry in _seededRows().entries) {
      expect(source.readRowVersion(entry.key), isNull);
    }
  });

  test('refresh publishes every seeded row with exact versions', () async {
    final seeded = _seededRows();
    final source = CachedCollectionVersionSource(
      InMemoryCollectionVersionReader(seeded),
    );

    await source.refresh();

    for (final entry in seeded.entries) {
      expect(source.readRowVersion(entry.key), entry.value);
    }
    // The tombstone lifecycle survives the round trip.
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
    // A new row added after the first refresh must not leak into the cache
    // when the second refresh fails partway.
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

  test('overlapping refresh calls share one in-flight read', () async {
    final gate = Completer<void>();
    final reader = _GatedReader(_seededRows(), gate);
    final source = CachedCollectionVersionSource(reader);

    final first = source.refresh();
    final second = source.refresh();
    expect(identical(first, second), isTrue);

    gate.complete();
    await first;
    await second;

    expect(reader.calls, SyncCollection.values.length);
    for (final entry in _seededRows().entries) {
      expect(source.readRowVersion(entry.key), entry.value);
    }
  });

  test('refresh after failure recovers with fresh values', () async {
    final inner = InMemoryCollectionVersionReader(_seededRows());
    final reader = _FailingReader(inner)
      ..failOn = SyncCollection.entries
      ..failure = Exception('entries read failed');
    final source = CachedCollectionVersionSource(reader);

    await expectLater(source.refresh(), throwsA(isException));
    expect(
      source.readRowVersion(
        SyncRowID.of(SyncCollection.moneySources, _moneySourcesRow),
      ),
      isNull,
    );

    final updated = _version(_deviceB, 7);
    inner.upsert(
      SyncRowID.of(SyncCollection.moneySources, _moneySourcesRow),
      updated,
    );
    reader
      ..failOn = null
      ..failure = null;
    await source.refresh();

    expect(
      source.readRowVersion(
        SyncRowID.of(SyncCollection.moneySources, _moneySourcesRow),
      ),
      updated,
    );
    for (final entry in _seededRows().entries) {
      if (entry.key ==
          SyncRowID.of(SyncCollection.moneySources, _moneySourcesRow)) {
        continue;
      }
      expect(source.readRowVersion(entry.key), entry.value);
    }
  });

  test('unknown and cross-collection rows read as null', () async {
    final source = CachedCollectionVersionSource(
      InMemoryCollectionVersionReader(_seededRows()),
    );
    await source.refresh();

    expect(
      source.readRowVersion(SyncRowID.of(SyncCollection.entries, _unknownRow)),
      isNull,
    );
    // Same UUID string seeded under moneySources is a distinct SyncRowID.
    expect(
      source.readRowVersion(
        SyncRowID.of(SyncCollection.categories, _moneySourcesRow),
      ),
      isNull,
    );
  });
}
