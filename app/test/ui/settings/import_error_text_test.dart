import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/import/money_manager/money_manager_importer.dart';
import 'package:spendwise/import/money_manager/money_manager_records.dart';
import 'package:spendwise/ui/settings/import_error_text.dart';

List<String> rejected(List<MoneyManagerImportError> errors) {
  return importErrorMessages(ImportRejected(errors));
}

void main() {
  test('success has no message', () {
    expect(importErrorMessages(const ImportSucceeded()), isEmpty);
  });

  test('save failure keeps the plan wording', () {
    expect(importErrorMessages(const ImportSaveFailed()), [
      "Couldn't save the import. Your data was not changed.",
    ]);
  });

  test('unexpected failure keeps the plan wording', () {
    expect(importErrorMessages(const ImportFailedUnexpectedly()), [
      "Couldn't import this file. Your data was not changed.",
    ]);
  });

  test('file-level errors have no row prefix', () {
    final messages = rejected(const [
      UnreadableFile(),
      MissingColumns(['A', 'B']),
      UnexpectedColumns(),
      NoRows(),
    ]);

    expect(messages, [
      "Couldn't read this file as an Excel workbook.",
      'Missing columns: A, B',
      "The columns don't match the Money Manager export.",
      'The file has no rows to import.',
    ]);
  });

  test('each row error kind has its own message', () {
    final messages = [
      for (final error in const <MoneyManagerRowError>[
        InvalidDate(1),
        MissingAccount(2),
        MissingCategory(3),
        MissingDestination(4),
        UnsupportedType(5, 'Card'),
        InvalidAmount(12, 'abc'),
        UnsupportedCurrency(7, 'USD'),
      ])
        ...rejected([error]),
    ];

    expect(messages, [
      "Row 1: Date isn't valid",
      'Row 2: Account is missing',
      'Row 3: Category is missing',
      'Row 4: Destination account is missing',
      'Row 5: Type "Card" isn\'t supported',
      'Row 12: Amount "abc" isn\'t a valid amount',
      'Row 7: Currency "USD" isn\'t supported (only SGD)',
    ]);
  });

  test('file messages come first, rows sorted, same row keeps input order', () {
    final messages = rejected(const [
      MissingAccount(9),
      InvalidDate(3),
      NoRows(),
      MissingCategory(3),
      UnreadableFile(),
    ]);

    expect(messages, [
      'The file has no rows to import.',
      "Couldn't read this file as an Excel workbook.",
      "Row 3: Date isn't valid",
      'Row 3: Category is missing',
      'Row 9: Account is missing',
    ]);
  });
}
