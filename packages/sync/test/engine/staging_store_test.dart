import 'package:sync/sync.dart';
import 'package:test/test.dart';

void main() {
  SyncEnvelope makeEnvelope(int counter) => SyncEnvelope(
        protocolVersion: syncProtocolVersion,
        userID: 'user',
        collection: SyncCollection.entries,
        rowID: 'row-a',
        siblingID: 'sibling-$counter',
        versionVector: VersionVector(<String, int>{'dev': counter}),
        lifecycle: SiblingLifecycle.live,
        ciphertext: '',
      );

  StagedConflict makeConflict() => StagedConflict(
        SyncCollection.entries,
        'row-a',
        [makeEnvelope(1), makeEnvelope(2)],
      );

  group('stage', () {
    test('replaces the prior group for the same collection and row', () {
      final store = InMemorySyncStagingStore();
      store.stage(makeConflict());
      store.stage(makeConflict());
      expect(store.pendingConflicts, hasLength(1));
      expect(store.pendingConflicts.first.envelopes, hasLength(2));
    });

    test('keeps distinct groups for different rows', () {
      final store = InMemorySyncStagingStore();
      store.stage(StagedConflict(
        SyncCollection.entries,
        'row-a',
        [makeEnvelope(1)],
      ));
      store.stage(StagedConflict(
        SyncCollection.entries,
        'row-b',
        [makeEnvelope(1)],
      ));
      expect(store.pendingConflicts, hasLength(2));
    });

    test('keeps distinct groups for different collections', () {
      final store = InMemorySyncStagingStore();
      store.stage(StagedConflict(
        SyncCollection.entries,
        'row-a',
        [makeEnvelope(1)],
      ));
      store.stage(StagedConflict(
        SyncCollection.categories,
        'row-a',
        [makeEnvelope(1)],
      ));
      expect(store.pendingConflicts, hasLength(2));
    });
  });

  group('pendingConflicts', () {
    test('returns groups oldest first', () {
      final store = InMemorySyncStagingStore();
      final first = StagedConflict(
        SyncCollection.entries,
        'row-a',
        [makeEnvelope(1)],
      );
      final second = StagedConflict(
        SyncCollection.entries,
        'row-b',
        [makeEnvelope(1)],
      );
      store.stage(first);
      store.stage(second);
      expect(store.pendingConflicts.first, first);
      expect(store.pendingConflicts.last, second);
    });
  });

  group('resolve', () {
    test('removes the matching group', () {
      final store = InMemorySyncStagingStore();
      store.stage(makeConflict());
      store.resolve(makeConflict());
      expect(store.pendingConflicts, isEmpty);
    });

    test('is an idempotent no-op when the group is absent', () {
      final store = InMemorySyncStagingStore();
      store.resolve(makeConflict());
      expect(store.pendingConflicts, isEmpty);
      store.stage(makeConflict());
      store.resolve(makeConflict());
      store.resolve(makeConflict());
      expect(store.pendingConflicts, isEmpty);
    });
  });
}
