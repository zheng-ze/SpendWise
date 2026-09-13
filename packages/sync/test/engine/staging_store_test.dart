import 'package:domain/domain.dart';
import 'package:sync/sync.dart';
import 'package:test/test.dart';

import '../support/entities.dart';

void main() {
  DecodedSibling makeSibling(int counter) => DecodedSibling(
        VersionVector(<String, int>{'dev': counter}),
        UpsertEntry(testEntry(id: 'row-$counter')),
        'sibling-$counter',
      );

  StagedConflict makeConflict() => StagedConflict(
        SyncCollection.entries,
        'row-a',
        [makeSibling(1), makeSibling(2)],
      );

  group('stage', () {
    test('replaces the prior group for the same collection and row', () {
      final store = InMemorySyncStagingStore();
      store.stage(makeConflict());
      store.stage(makeConflict());
      expect(store.pendingConflicts, hasLength(1));
      expect(store.pendingConflicts.first.siblings, hasLength(2));
    });

    test('keeps distinct groups for different rows', () {
      final store = InMemorySyncStagingStore();
      store.stage(StagedConflict(
        SyncCollection.entries,
        'row-a',
        [makeSibling(1)],
      ));
      store.stage(StagedConflict(
        SyncCollection.entries,
        'row-b',
        [makeSibling(1)],
      ));
      expect(store.pendingConflicts, hasLength(2));
    });

    test('keeps distinct groups for different collections', () {
      final store = InMemorySyncStagingStore();
      store.stage(StagedConflict(
        SyncCollection.entries,
        'row-a',
        [makeSibling(1)],
      ));
      store.stage(StagedConflict(
        SyncCollection.categories,
        'row-a',
        [makeSibling(1)],
      ));
      expect(store.pendingConflicts, hasLength(2));
    });

    test('siblings expose decoded LedgerChange content', () {
      final store = InMemorySyncStagingStore();
      store.stage(makeConflict());
      final conflict = store.pendingConflicts.first;
      expect(
        conflict.siblings.map((sibling) => sibling.change).toList(),
        <LedgerChange>[
          UpsertEntry(testEntry(id: 'row-1')),
          UpsertEntry(testEntry(id: 'row-2')),
        ],
      );
    });
  });

  group('pendingConflicts', () {
    test('returns groups oldest first', () {
      final store = InMemorySyncStagingStore();
      final first = StagedConflict(
        SyncCollection.entries,
        'row-a',
        [makeSibling(1)],
      );
      final second = StagedConflict(
        SyncCollection.entries,
        'row-b',
        [makeSibling(1)],
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

  group('rowID normalization', () {
    test('normalizes an upper-case row ID on construction', () {
      final conflict = StagedConflict(
        SyncCollection.entries,
        'ROW-A',
        [makeSibling(1)],
      );
      expect(conflict.rowID, 'row-a');
      expect(conflict.row, SyncRowID.of(SyncCollection.entries, 'row-a'));
    });
  });

  group('sibling list is defensive', () {
    test('mutating the supplied list does not change the conflict', () {
      final siblings = <DecodedSibling>[makeSibling(1), makeSibling(2)];
      final conflict = StagedConflict(
        SyncCollection.entries,
        'row-a',
        siblings,
      );
      siblings.add(makeSibling(3));
      expect(conflict.siblings, hasLength(2));
    });
  });

  group('DecodedSibling equality', () {
    test('equal instances share hashCode and field equality', () {
      final a = makeSibling(1);
      final b = DecodedSibling(
        VersionVector(<String, int>{'dev': 1}),
        UpsertEntry(testEntry(id: 'row-1')),
        'sibling-1',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('a differing siblingID is not equal', () {
      final a = makeSibling(1);
      final b = DecodedSibling(
        VersionVector(<String, int>{'dev': 1}),
        UpsertEntry(testEntry(id: 'row-1')),
        'sibling-different',
      );
      expect(a, isNot(equals(b)));
    });
  });
}
