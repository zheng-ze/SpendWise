import 'package:sync/sync.dart';
import 'package:test/test.dart';

void main() {
  SyncRowID row(SyncCollection collection, String id) =>
      SyncRowID.of(collection, id);

  group('refresh', () {
    test('is a safe no-op that preserves reads', () async {
      final rowID = row(SyncCollection.entries, 'row-1');
      final version = RowVersion(
        versionVector: VersionVector(<String, int>{'dev': 3}),
        lifecycle: SiblingLifecycle.live,
      );
      final source = InMemorySyncVersionSource(
        <SyncRowID, RowVersion>{rowID: version},
      );

      await source.refresh();

      expect(source.readRowVersion(rowID), version);
    });

    test('is safe to call repeatedly and on an empty source', () async {
      final source = InMemorySyncVersionSource();

      await source.refresh();
      await source.refresh();

      expect(
        source.readRowVersion(row(SyncCollection.entries, 'missing')),
        isNull,
      );
    });
  });
}
