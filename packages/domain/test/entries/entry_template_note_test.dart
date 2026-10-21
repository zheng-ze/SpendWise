import 'package:domain/domain.dart';
import 'package:test/test.dart';

import '../support/builders.dart';

EntryTemplate notedTemplate({String? note}) => EntryTemplate(
  amount: Decimal.fromInt(-25),
  name: 'rent',
  sourceID: uuid(1),
  note: note,
);

LedgerState stateWithHolders() {
  final state = LedgerState();
  state.addAccount(account(uuid(1), name: 'a'));
  state.addAccount(account(uuid(2), name: 'b'));
  return state;
}

RecurringPlan notedPlan({String? note, String? id}) => RecurringPlan(
  id: id ?? uuid(6),
  template: notedTemplate(note: note),
  frequency: RecurrenceFrequency.monthly,
  anchor: DateTime.utc(2026, 1, 15),
  lastResolvedDate: DateTime.utc(2026, 1, 15),
);

void main() {
  group('template note normalization', () {
    test('normalizes blank and surrounding whitespace', () {
      for (final raw in <String?>[null, '', '   ', '\n\t ']) {
        expect(notedTemplate(note: raw).note, isNull, reason: '$raw');
      }
      expect(notedTemplate(note: '  memo  ').note, 'memo');
      expect(notedTemplate(note: 'a  b\nc').note, 'a  b\nc');
    });

    test('templates differing only by note compare unequal', () {
      final base = notedTemplate(note: 'one');

      expect(base == notedTemplate(note: 'two'), isFalse);
      expect(base == notedTemplate(), isFalse);
    });
  });

  group('makeEntry', () {
    test('forwards the normalized note into the occurrence', () {
      final made = notedTemplate(
        note: '  memo ',
      ).makeEntry(uuid(7), DateTime.utc(2026, 3, 15));

      expect(made.note, 'memo');
    });

    test('preserves existing fields and the deterministic occurrence id', () {
      final date = DateTime.utc(2026, 3, 15);
      final made = notedTemplate(note: 'memo').makeEntry(uuid(7), date);

      expect(made.id, OccurrenceID.make(uuid(7), date));
      expect(made.date, date);
      expect(made.amount, Decimal.fromInt(-25));
      expect(made.name, 'rent');
      expect(made.sourceID, uuid(1));
    });

    test('an omitted template note stays absent on the occurrence', () {
      final made = notedTemplate().makeEntry(
        uuid(7),
        DateTime.utc(2026, 3, 15),
      );

      expect(made.note, isNull);
    });
  });

  group('plan resolution with a noted template', () {
    test('the first and a later occurrence both carry the note', () {
      final state = stateWithHolders();
      state.addPlan(notedPlan(note: '  memo '));

      state.resolvePlans(DateTime.utc(2026, 4, 20));

      expect(state.entries, hasLength(3));
      for (final entry in state.entries.values) {
        expect(entry.note, 'memo');
      }
    });

    test('existing occurrences are skipped without backfill or overwrite', () {
      final state = stateWithHolders();
      state.addPlan(notedPlan(note: 'memo'));
      state.resolvePlans(DateTime.utc(2026, 2, 20));
      final firstId = OccurrenceID.make(uuid(6), DateTime.utc(2026, 2, 15));
      state.updateEntry(
        state.entries[firstId]!.settingLifecycle(LifecycleState.active),
      );

      final second = state.resolvePlans(DateTime.utc(2026, 4, 20));

      expect(state.entries[firstId]!.note, 'memo');
      expect(
        state
            .entries[OccurrenceID.make(uuid(6), DateTime.utc(2026, 3, 15))]!
            .note,
        'memo',
      );
      expect(
        second.changes.any((change) => change.targetID == firstId),
        isFalse,
      );
    });

    test(
      'changing the template note leaves historical occurrences untouched',
      () {
        final state = stateWithHolders();
        state.addPlan(notedPlan(note: 'original'));
        state.resolvePlans(DateTime.utc(2026, 2, 20));
        final februaryId = OccurrenceID.make(
          uuid(6),
          DateTime.utc(2026, 2, 15),
        );
        state.archiveEntry(februaryId);
        state.resolvePlans(DateTime.utc(2026, 3, 20));
        final marchId = OccurrenceID.make(uuid(6), DateTime.utc(2026, 3, 15));
        final stored = state.plans[uuid(6)]!;
        state.updatePlan(
          RecurringPlan(
            id: stored.id,
            template: EntryTemplate(
              amount: stored.template.amount,
              name: stored.template.name,
              sourceID: stored.template.sourceID,
              note: 'updated',
            ),
            frequency: stored.frequency,
            anchor: stored.anchor,
            lastResolvedDate: DateTime.utc(2026, 1, 15),
          ),
        );

        final result = state.resolvePlans(DateTime.utc(2026, 4, 20));
        final aprilId = OccurrenceID.make(uuid(6), DateTime.utc(2026, 4, 15));

        expect(state.binnedEntries[februaryId]!.note, 'original');
        expect(state.entries[marchId]!.note, 'original');
        expect(state.entries[aprilId]!.note, 'updated');
        expect(
          result.changes.any((change) => change.targetID == februaryId),
          isFalse,
        );
        expect(
          result.changes.any((change) => change.targetID == marchId),
          isFalse,
        );
      },
    );
  });

  group('resolution failure with a noted template', () {
    test(
      'a failed occurrence keeps its failure while a later one resolves',
      () {
        final state = stateWithHolders();
        state.addCategory(category(uuid(3), kind: CategoryKind.expense));
        state.addPlan(notedPlan(note: 'memo', id: uuid(6)));
        final archived = state.plans[uuid(6)]!;
        state.updatePlan(
          RecurringPlan(
            id: archived.id,
            template: EntryTemplate(
              amount: archived.template.amount,
              name: archived.template.name,
              categoryID: uuid(3),
              sourceID: archived.template.sourceID,
              note: 'memo',
            ),
            frequency: archived.frequency,
            anchor: archived.anchor,
            lastResolvedDate: archived.lastResolvedDate,
          ),
        );
        state.deleteCategory(uuid(3));

        final result = state.resolvePlans(DateTime.utc(2026, 4, 20));

        expect(result.failures, isNotEmpty);
        expect(state.plans[uuid(6)]!.template.note, 'memo');
        expect(state.entries, isEmpty);
      },
    );

    test('a noted negative transfer plan stores swapped endpoints', () {
      final state = stateWithHolders();
      final transfer = EntryTemplate(
        amount: Decimal.fromInt(-100),
        name: 'move',
        sourceID: uuid(1),
        destinationID: uuid(2),
        note: '  memo ',
      );
      state.addPlan(
        RecurringPlan(
          id: uuid(6),
          template: transfer,
          frequency: RecurrenceFrequency.monthly,
          anchor: DateTime.utc(2026, 1, 15),
          lastResolvedDate: DateTime.utc(2026, 1, 15),
        ),
      );

      state.resolvePlans(DateTime.utc(2026, 2, 20));

      final stored =
          state.entries[OccurrenceID.make(uuid(6), DateTime.utc(2026, 2, 15))]!;
      expect(stored.note, 'memo');
      expect(stored.amount, Decimal.fromInt(100));
      expect(stored.sourceID, uuid(2));
      expect(stored.destinationID, uuid(1));
    });
  });
}
