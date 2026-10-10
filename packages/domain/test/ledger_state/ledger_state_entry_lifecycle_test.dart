import 'package:domain/domain.dart';
import 'package:test/test.dart';

import '../support/builders.dart';

LedgerState _stateWithEntry({String? categoryID}) {
  final state = LedgerState();
  state.addAccount(account(uuid(1)));
  state.addCategory(category(uuid(2)));
  state.addEntry(entry(id: uuid(3), sourceID: uuid(1), categoryID: categoryID));
  return state;
}

void main() {
  test('archiveEntry bins an active entry and returns its archived upsert', () {
    final state = _stateWithEntry();

    final changes = state.archiveEntry(uuid(3));

    expect(state.entries, isEmpty);
    expect(state.binnedEntries.keys, [uuid(3)]);
    expect(changes, [UpsertEntry(state.binnedEntries[uuid(3)]!)]);
    expect(state.binnedEntries[uuid(3)]!.lifecycle, LifecycleState.archived);
  });

  test('archiveEntry ignores system, missing and already binned ids', () {
    final state = _stateWithEntry();
    state.setOpeningBalance(Decimal.fromInt(5), uuid(1));
    final system = state.entries.values.firstWhere((e) => e.systemKind != null);
    state.archiveEntry(uuid(3));

    expect(state.archiveEntry(system.id), isEmpty);
    expect(state.archiveEntry(uuid(9)), isEmpty);
    expect(state.archiveEntry(uuid(3)), isEmpty);
    expect(state.entries.keys, [system.id]);
  });

  test('restoreEntry returns the entry to the books', () {
    final state = _stateWithEntry();
    final before = Accounting.analysisItems(state);
    final worthBefore = Accounting.netWorth(state);
    state.archiveEntry(uuid(3));
    expect(Accounting.analysisItems(state), isEmpty);

    final changes = state.restoreEntry(uuid(3));

    expect(state.binnedEntries, isEmpty);
    expect(changes, [UpsertEntry(state.entries[uuid(3)]!)]);
    expect(state.entries[uuid(3)]!.lifecycle, LifecycleState.active);
    expect(Accounting.analysisItems(state), before);
    expect(Accounting.netWorth(state), worthBefore);
    expect(state.restoreEntry(uuid(3)), isEmpty);
  });

  test('purgeEntry removes a binned entry and sweeps its references', () {
    final state = _stateWithEntry(categoryID: uuid(2));
    state.archiveEntry(uuid(3));
    state.deleteAccount(uuid(1));
    state.deleteCategory(uuid(2));
    state.purgeAccount(uuid(1));
    state.purgeCategory(uuid(2));
    expect(
      state.moneySources[uuid(1)]!.lifecycle,
      LifecycleState.referenceOnly,
    );
    expect(state.categories[uuid(2)]!.lifecycle, LifecycleState.referenceOnly);

    final changes = state.purgeEntry(uuid(3));

    expect(changes, [
      DeleteEntry(uuid(3)),
      DeleteMoneySource(uuid(1)),
      DeleteCategory(uuid(2)),
    ]);
    expect(state.binnedEntries, isEmpty);
    expect(state.moneySources, isEmpty);
    expect(state.categories, isEmpty);
  });

  test('purgeEntry ignores active and missing ids', () {
    final state = _stateWithEntry();

    expect(state.purgeEntry(uuid(3)), isEmpty);
    expect(state.purgeEntry(uuid(9)), isEmpty);
    expect(state.entries.keys, [uuid(3)]);
  });

  test('binned entries keep their holder and category referenced', () {
    final state = _stateWithEntry(categoryID: uuid(2));
    state.archiveEntry(uuid(3));

    expect(state.entriesReferencing(uuid(1)), 1);
    expect(state.entryCount({uuid(1)}), 1);
    expect(state.entryCountReferencing(uuid(2)), 1);

    state.deleteAccount(uuid(1));
    state.deleteCategory(uuid(2));
    state.purgeAccount(uuid(1));
    state.purgeCategory(uuid(2));

    expect(
      state.moneySources[uuid(1)]!.lifecycle,
      LifecycleState.referenceOnly,
    );
    expect(state.categories[uuid(2)]!.lifecycle, LifecycleState.referenceOnly);
  });

  test('a binned id is taken for addEntry and unknown to updateEntry', () {
    final state = _stateWithEntry();
    final binned = state.entries[uuid(3)]!;
    state.archiveEntry(uuid(3));

    expect(
      () => state.addEntry(entry(id: uuid(3), sourceID: uuid(1))),
      throwsA(isA<IdCollision>()),
    );
    expect(() => state.updateEntry(binned), throwsA(isA<UnknownEntry>()));
  });

  test('deleteEntry hard deletes a binned entry', () {
    final state = _stateWithEntry();
    state.archiveEntry(uuid(3));

    expect(state.deleteEntry(uuid(3)), [DeleteEntry(uuid(3))]);
    expect(state.binnedEntries, isEmpty);
  });

  test('resolvePlans does not re-create a binned occurrence', () {
    final state = LedgerState();
    state.addAccount(account(uuid(1)));
    final recurring = RecurringPlan(
      id: uuid(2),
      template: EntryTemplate(
        amount: Decimal.fromInt(-10),
        name: 'rent',
        sourceID: uuid(1),
      ),
      frequency: RecurrenceFrequency.monthly,
      anchor: DateTime.utc(2026, 1, 10),
      lastResolvedDate: DateTime.utc(2026, 1, 10),
    );
    state.addPlan(recurring);
    final now = DateTime.utc(2026, 3, 15);
    final first = state.resolvePlans(now);
    final created = first.changes.whereType<UpsertEntry>().toList();
    expect(created, isNotEmpty);
    for (final change in created) {
      state.archiveEntry(change.entry.id);
    }
    state.updatePlan(recurring);

    final second = state.resolvePlans(now);

    expect(second.changes.whereType<UpsertEntry>(), isEmpty);
    expect(state.entries, isEmpty);
  });

  group('replay', () {
    final base = [
      UpsertAccount(account(uuid(1))),
      UpsertCategory(category(uuid(2))),
    ];

    test('routes UpsertEntry by lifecycle', () {
      final live = entry(id: uuid(3), sourceID: uuid(1));
      final binned = live.settingLifecycle(LifecycleState.archived);

      final state = LedgerState.replaying([
        ...base,
        UpsertEntry(live),
        UpsertEntry(
          entry(
            id: uuid(4),
            sourceID: uuid(1),
          ).settingLifecycle(LifecycleState.archived),
        ),
      ]);
      expect(state.entries.keys, [uuid(3)]);
      expect(state.binnedEntries.keys, [uuid(4)]);

      state.apply([UpsertEntry(binned)]);
      expect(state.entries, isEmpty);
      expect(state.binnedEntries.keys, unorderedEquals([uuid(3), uuid(4)]));

      state.apply([UpsertEntry(live)]);
      expect(state.entries.keys, [uuid(3)]);

      state.apply([DeleteEntry(uuid(3)), DeleteEntry(uuid(4))]);
      expect(state.entries, isEmpty);
      expect(state.binnedEntries, isEmpty);
    });

    test('an active upsert after an archived one removes the binned copy', () {
      final live = entry(id: uuid(3), sourceID: uuid(1));
      final state = LedgerState.replaying([
        ...base,
        UpsertEntry(live.settingLifecycle(LifecycleState.archived)),
        UpsertEntry(live),
      ]);

      expect(state.binnedEntries, isEmpty);
      expect(state.entries.keys, [uuid(3)]);
    });

    test('rejects a referenceOnly or tombstoned entry with clause 9', () {
      for (final lifecycle in [
        LifecycleState.referenceOnly,
        LifecycleState.tombstoned,
      ]) {
        expect(
          () => LedgerState.replaying([
            ...base,
            UpsertEntry(
              entry(id: uuid(3), sourceID: uuid(1)).settingLifecycle(lifecycle),
            ),
          ]),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('invariant 9'),
            ),
          ),
        );
      }
    });

    test('rejects an id in both tables with clause 18', () {
      final live = entry(id: uuid(3), sourceID: uuid(1));
      final state = LedgerState(
        moneySources: {uuid(1): AccountSource(account(uuid(1)))},
        entries: {uuid(3): live},
        binnedEntries: {
          uuid(3): live.settingLifecycle(LifecycleState.archived),
        },
      );

      expect(
        state.assertInvariants,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('invariant 18'),
          ),
        ),
      );
    });

    test('a binned entry with an unknown holder fails replay', () {
      expect(
        () => LedgerState.replaying([
          UpsertEntry(
            entry(
              id: uuid(3),
              sourceID: uuid(1),
            ).settingLifecycle(LifecycleState.archived),
          ),
        ]),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('invariants over binned entries', () {
    StateError violation(LedgerState state) {
      try {
        state.assertInvariants();
      } on StateError catch (error) {
        return error;
      }
      fail('expected an invariant violation');
    }

    Entry binned({String? categoryID, String? sourceID}) => entry(
      id: uuid(3),
      sourceID: sourceID ?? uuid(1),
      categoryID: categoryID,
    ).settingLifecycle(LifecycleState.archived);

    test('a binned entry with a missing account breaks clause 4', () {
      final state = LedgerState(binnedEntries: {uuid(3): binned()});

      expect(violation(state).message, contains('invariant 4'));
    });

    test('a binned entry with a mismatched category breaks clause 6', () {
      final state = LedgerState(
        moneySources: {uuid(1): AccountSource(account(uuid(1)))},
        categories: {uuid(2): category(uuid(2), kind: CategoryKind.income)},
        binnedEntries: {uuid(3): binned(categoryID: uuid(2))},
      );

      expect(violation(state).message, contains('invariant 6'));
    });

    test('a binned entry that is not archived breaks clause 9', () {
      final state = LedgerState(
        moneySources: {uuid(1): AccountSource(account(uuid(1)))},
        binnedEntries: {uuid(3): entry(id: uuid(3), sourceID: uuid(1))},
      );

      expect(violation(state).message, contains('invariant 9'));
    });

    test('a binned entry stored under another key breaks clause 1', () {
      final state = LedgerState(
        moneySources: {uuid(1): AccountSource(account(uuid(1)))},
        binnedEntries: {uuid(4): binned()},
      );

      expect(violation(state).message, contains('invariant 1'));
    });
  });

  test(
    'a pocket and its account referenced only by a binned entry survive',
    () {
      final state = LedgerState();
      state.addAccount(account(uuid(1)));
      state.addPocket(pocket(uuid(2)), uuid(1));
      state.addEntry(entry(id: uuid(3), sourceID: uuid(2)));
      state.archiveEntry(uuid(3));

      state.deleteAccount(uuid(1));
      state.purgeAccount(uuid(1));

      expect(state.moneySources.keys, unorderedEquals([uuid(1), uuid(2)]));
      expect(
        state.moneySources[uuid(1)]!.lifecycle,
        LifecycleState.referenceOnly,
      );
      expect(
        state.moneySources[uuid(2)]!.lifecycle,
        LifecycleState.referenceOnly,
      );
    },
  );

  test(
    'a parent category referenced only through a binned child entry stays',
    () {
      final state = LedgerState();
      state.addAccount(account(uuid(1)));
      state.addCategory(category(uuid(2)));
      state.addCategory(category(uuid(4), parent: uuid(2)));
      state.addEntry(
        entry(id: uuid(3), sourceID: uuid(1), categoryID: uuid(4)),
      );
      state.archiveEntry(uuid(3));

      state.deleteCategory(uuid(2));
      state.purgeCategory(uuid(2));

      expect(state.categories.keys, unorderedEquals([uuid(2), uuid(4)]));
      expect(
        state.categories[uuid(2)]!.lifecycle,
        LifecycleState.referenceOnly,
      );
    },
  );
}
