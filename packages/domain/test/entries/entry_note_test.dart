import 'package:domain/domain.dart';
import 'package:test/test.dart';

import '../support/builders.dart';

Entry notedEntry({String? note, String? id, String? sourceID}) => Entry(
  id: id,
  date: DateTime.utc(2026, 3, 14),
  amount: Decimal.fromInt(-10),
  name: 'Coffee',
  sourceID: sourceID ?? uuid(1),
  note: note,
);

LedgerState stateWithHolders() {
  final state = LedgerState();
  state.addAccount(account(uuid(1), name: 'a'));
  state.addAccount(account(uuid(2), name: 'b'));
  state.addCategory(category(uuid(3)));
  return state;
}

void main() {
  group('note normalization', () {
    test('an omitted note loads as no note', () {
      expect(
        Entry(amount: Decimal.one, name: 'e', sourceID: uuid(1)).note,
        isNull,
      );
    });

    test('null, empty and whitespace-only notes load as no note', () {
      final raws = <String?>[null, '', '   ', '\n\t '];
      for (final raw in raws) {
        expect(notedEntry(note: raw).note, isNull, reason: '$raw');
      }
    });

    test('surrounding whitespace is removed', () {
      expect(notedEntry(note: '  Coffee with Sam  ').note, 'Coffee with Sam');
    });

    test('internal whitespace and line breaks remain', () {
      expect(notedEntry(note: 'a  b\nc').note, 'a  b\nc');
    });

    test('normalized-equivalent entries compare equal with equal hashes', () {
      final first = notedEntry(note: '  memo ');
      final second = notedEntry(note: 'memo', id: first.id);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('entries differing only by note compare unequal', () {
      final base = notedEntry(note: 'one');
      final other = notedEntry(note: 'two', id: base.id);

      expect(base == other, isFalse);
      expect(base == notedEntry(id: base.id), isFalse);
    });
  });

  group('note preservation', () {
    test('settingLifecycle retains the note', () {
      final archived = notedEntry(
        note: 'memo',
      ).settingLifecycle(LifecycleState.archived);

      expect(archived.note, 'memo');
    });

    test('archive and restore retain the note', () {
      final state = stateWithHolders();
      state.addEntry(notedEntry(id: uuid(4), note: 'memo', sourceID: uuid(1)));

      state.archiveEntry(uuid(4));

      expect(state.binnedEntries[uuid(4)]!.note, 'memo');

      state.restoreEntry(uuid(4));

      expect(state.entries[uuid(4)]!.note, 'memo');
    });

    test(
      'a negative transfer add preserves the note while swapping holders',
      () {
        final state = stateWithHolders();
        final changes = state.addEntry(
          Entry(
            id: uuid(4),
            date: DateTime.utc(2026, 3, 14),
            amount: Decimal.fromInt(-100),
            name: 'Move',
            sourceID: uuid(1),
            destinationID: uuid(2),
            note: '  memo ',
          ),
        );

        final stored = state.entries[uuid(4)]!;
        expect(stored.note, 'memo');
        expect(stored.amount, Decimal.fromInt(100));
        expect(stored.sourceID, uuid(2));
        expect(stored.destinationID, uuid(1));
        expect(changes, [UpsertEntry(stored)]);
      },
    );

    test('a negative transfer update preserves the note', () {
      final state = stateWithHolders();
      state.addEntry(
        Entry(
          id: uuid(4),
          amount: Decimal.fromInt(100),
          name: 'Move',
          sourceID: uuid(1),
          destinationID: uuid(2),
          note: 'memo',
        ),
      );

      final changes = state.updateEntry(
        Entry(
          id: uuid(4),
          amount: Decimal.fromInt(-100),
          name: 'Move',
          sourceID: uuid(1),
          destinationID: uuid(2),
          note: 'updated',
        ),
      );

      final stored = state.entries[uuid(4)]!;
      expect(stored.note, 'updated');
      expect(stored.amount, Decimal.fromInt(100));
      expect(stored.sourceID, uuid(2));
      expect(changes.first, UpsertEntry(stored));
    });
  });

  group('system entry note edits', () {
    for (final kind in SystemEntryKind.values) {
      test('a note edit on a $kind entry is accepted', () {
        final state = stateWithHolders();
        state.addEntry(
          Entry(
            id: uuid(4),
            amount: Decimal.fromInt(250),
            name: 'Opening balance',
            sourceID: uuid(1),
            includeInAnalysis: false,
            systemKind: kind,
          ),
        );

        final changes = state.updateEntry(
          Entry(
            id: uuid(4),
            amount: Decimal.fromInt(250),
            name: 'Opening balance',
            sourceID: uuid(1),
            includeInAnalysis: false,
            systemKind: kind,
            note: 'audited',
          ),
        );

        expect(state.entries[uuid(4)]!.note, 'audited');
        expect(changes.first, UpsertEntry(state.entries[uuid(4)]!));
      });

      test('a note replacement and clearing on a $kind entry is accepted', () {
        final state = stateWithHolders();
        state.addEntry(
          Entry(
            id: uuid(4),
            amount: Decimal.fromInt(250),
            name: 'Opening balance',
            sourceID: uuid(1),
            includeInAnalysis: false,
            systemKind: kind,
            note: 'first',
          ),
        );

        state.updateEntry(
          Entry(
            id: uuid(4),
            amount: Decimal.fromInt(250),
            name: 'Opening balance',
            sourceID: uuid(1),
            includeInAnalysis: false,
            systemKind: kind,
            note: 'second',
          ),
        );
        expect(state.entries[uuid(4)]!.note, 'second');

        state.updateEntry(
          Entry(
            id: uuid(4),
            amount: Decimal.fromInt(250),
            name: 'Opening balance',
            sourceID: uuid(1),
            includeInAnalysis: false,
            systemKind: kind,
          ),
        );
        expect(state.entries[uuid(4)]!.note, isNull);
      });

      test('a protected-field edit on a $kind entry still locks', () {
        final state = stateWithHolders();
        state.addEntry(
          Entry(
            id: uuid(4),
            amount: Decimal.fromInt(250),
            name: 'Opening balance',
            sourceID: uuid(1),
            includeInAnalysis: false,
            systemKind: kind,
            note: 'memo',
          ),
        );

        expect(
          () => state.updateEntry(
            Entry(
              id: uuid(4),
              amount: Decimal.fromInt(250),
              name: 'Renamed',
              sourceID: uuid(1),
              includeInAnalysis: false,
              systemKind: kind,
              note: 'memo',
            ),
          ),
          throwsA(SystemEntryLocked(uuid(4))),
        );
        expect(state.entries[uuid(4)]!.note, 'memo');
      });
    }
  });
}
