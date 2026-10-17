import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);
  const sourceId = 's0000000-0000-0000-0000-000000000001';
  const categoryId = 'c0000000-0000-0000-0000-000000000001';
  const otherId = 's0000000-0000-0000-0000-000000000002';

  group('canSaveEntryForm', () {
    bool save({
      Decimal? amount,
      String name = 'Coffee',
      String? sourceId = sourceId,
      EntryFormKind kind = EntryFormKind.expense,
      String? destinationId,
      String? categoryId = categoryId,
      bool isSystemEntry = false,
    }) {
      return canSaveEntryForm(
        amount: amount,
        name: name,
        sourceId: sourceId,
        kind: kind,
        destinationId: destinationId,
        categoryId: categoryId,
        isSystemEntry: isSystemEntry,
      );
    }

    test('rejects a null amount', () {
      expect(save(amount: null), isFalse);
    });

    test('rejects a zero amount', () {
      expect(save(amount: Decimal.zero), isFalse);
    });

    test('rejects an empty name', () {
      expect(save(amount: dec('5'), name: ''), isFalse);
    });

    test('rejects a name that is only whitespace', () {
      expect(save(amount: dec('5'), name: '   '), isFalse);
    });

    test('rejects no source selected', () {
      expect(save(amount: dec('5'), sourceId: null), isFalse);
    });

    test('rejects an expense without a category', () {
      expect(save(amount: dec('5'), categoryId: null), isFalse);
    });

    test('rejects an income without a category', () {
      expect(
        save(amount: dec('5'), kind: EntryFormKind.income, categoryId: null),
        isFalse,
      );
    });

    test('accepts a transfer without a category', () {
      expect(
        save(
          amount: dec('5'),
          kind: EntryFormKind.transfer,
          destinationId: otherId,
          categoryId: null,
        ),
        isTrue,
      );
    });

    test('accepts a system entry without a category', () {
      expect(
        save(amount: dec('5'), categoryId: null, isSystemEntry: true),
        isTrue,
      );
    });

    test('still rejects a system entry with a zero amount', () {
      expect(
        save(amount: Decimal.zero, categoryId: null, isSystemEntry: true),
        isFalse,
      );
    });

    test('accepts a valid expense', () {
      expect(save(amount: dec('5')), isTrue);
    });

    test('accepts a valid income', () {
      expect(save(amount: dec('5'), kind: EntryFormKind.income), isTrue);
    });

    test('rejects a transfer with no destination', () {
      expect(save(amount: dec('5'), kind: EntryFormKind.transfer), isFalse);
    });

    test('rejects a transfer whose destination equals its source', () {
      expect(
        save(
          amount: dec('5'),
          kind: EntryFormKind.transfer,
          destinationId: sourceId,
        ),
        isFalse,
      );
    });

    test('accepts a transfer with a differing destination', () {
      expect(
        save(
          amount: dec('5'),
          kind: EntryFormKind.transfer,
          destinationId: otherId,
        ),
        isTrue,
      );
    });
  });

  group('signedEntryForSave', () {
    Entry build(
      EntryFormKind kind, {
      String? destinationId,
      String? categoryId,
    }) {
      return signedEntryForSave(
        kind: kind,
        magnitude: dec('5'),
        name: 'Coffee',
        categoryId: categoryId,
        sourceId: sourceId,
        destinationId: destinationId,
        includeInAnalysis: true,
      );
    }

    test('income is stored positive', () {
      final entry = build(EntryFormKind.income, categoryId: 'c1');
      expect(entry.amount, dec('5'));
    });

    test('expense is stored negative', () {
      final entry = build(EntryFormKind.expense, categoryId: 'c1');
      expect(entry.amount, dec('-5'));
    });

    test('transfer is stored positive with a destination and no category', () {
      final entry = build(EntryFormKind.transfer, destinationId: otherId);
      expect(entry.amount, dec('5'));
      expect(entry.destinationID, otherId);
      expect(entry.categoryID, isNull);
    });

    test('transfer drops a category even if one was passed in', () {
      final entry = build(
        EntryFormKind.transfer,
        destinationId: otherId,
        categoryId: 'c1',
      );
      expect(entry.categoryID, isNull);
    });

    test('forwards a note trimmed', () {
      final entry = signedEntryForSave(
        kind: EntryFormKind.expense,
        magnitude: dec('5'),
        name: 'Coffee',
        sourceId: sourceId,
        includeInAnalysis: true,
        note: '  Receipt kept ',
      );
      expect(entry.note, 'Receipt kept');
    });

    test('defaults to no note', () {
      expect(build(EntryFormKind.expense).note, isNull);
    });

    test('a whitespace-only note saves as no note', () {
      final entry = signedEntryForSave(
        kind: EntryFormKind.expense,
        magnitude: dec('5'),
        name: 'Coffee',
        sourceId: sourceId,
        includeInAnalysis: true,
        note: '   ',
      );
      expect(entry.note, isNull);
    });
  });
}
