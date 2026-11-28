import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/import/money_manager/money_manager_records.dart';
import 'package:spendwise/import/xlsx/xlsx_sheet.dart';

import '../support/xlsx_fixture.dart';

const _fractionalSerial = '46352.970728506945';
const _nearNextDaySerial = '46352.99999999999';
const _exactSerial = '46352';
const _nextExactSerial = '46353';

XlsxSheet sheetWith(List<List<String>> rows, {bool date1904 = false}) {
  return XlsxSheet(rows: rows, date1904: date1904);
}

List<String> row({
  String date = _fractionalSerial,
  String account = 'Cash',
  String category = 'Food',
  String subcategory = 'Lunch',
  String note = 'Note',
  String type = 'Expense',
  String description = 'Description',
  String amount = '2.0',
  String currency = 'SGD',
  String duplicateAccount = 'Shadow',
}) {
  return [
    date,
    account,
    category,
    subcategory,
    note,
    amount,
    type,
    description,
    '',
    amount,
    currency,
    duplicateAccount,
  ];
}

MoneyManagerParseResult parseRows(
  List<List<String>> dataRows, {
  bool date1904 = false,
}) {
  final rows = [moneyManagerHeader, ...dataRows];
  return parseMoneyManagerSheet(sheetWith(rows, date1904: date1904));
}

List<MoneyManagerRow> parsedRows(
  List<List<String>> dataRows, {
  bool date1904 = false,
}) {
  final result = parseRows(dataRows, date1904: date1904);
  return (result as MoneyManagerRecords).rows;
}

List<MoneyManagerImportError> failedErrors(
  List<List<String>> dataRows, {
  bool date1904 = false,
}) {
  final result = parseRows(dataRows, date1904: date1904);
  return (result as MoneyManagerRecordsFailed).errors;
}

DateTime dateOf(String serial, {bool date1904 = false}) {
  return parsedRows([row(date: serial)], date1904: date1904).single.date;
}

void main() {
  group('header and shape', () {
    test('reads columns from the first occurrence of a header', () {
      final parsed = parsedRows([
        row(account: 'Cash', duplicateAccount: 'Shadow'),
      ]);

      expect(parsed.single.account, 'Cash');
    });

    test('lists missing column names in header order', () {
      final header = ['Date', 'Account', 'Category', 'Subcategory'];
      final sheet = sheetWith([header, row()]);

      final result = parseMoneyManagerSheet(sheet);

      final errors = (result as MoneyManagerRecordsFailed).errors;
      final missing = errors.single as MissingColumns;
      expect(missing.names, [
        'Note',
        'Income/Expense',
        'Description',
        'Amount',
        'Currency',
      ]);
    });

    test('rejects a header-only sheet', () {
      final result = parseMoneyManagerSheet(sheetWith([moneyManagerHeader]));

      final errors = (result as MoneyManagerRecordsFailed).errors;
      expect(errors.single, isA<NoRows>());
    });

    test('rejects an empty sheet', () {
      final result = parseMoneyManagerSheet(sheetWith([]));

      final errors = (result as MoneyManagerRecordsFailed).errors;
      expect(errors.single, isA<NoRows>());
    });

    test('parses every data row with its sheet row number', () {
      final parsed = parsedRows([row(), row(type: 'Income')]);

      expect(parsed.map((r) => r.sheetRow), [2, 3]);
      expect(parsed.map((r) => r.type), [
        MoneyManagerRowType.expense,
        MoneyManagerRowType.income,
      ]);
    });

    test('reads cells past the end of a short row as empty', () {
      final shortRow = row().take(11).toList();

      final parsed = parsedRows([shortRow]);

      expect(parsed.single.account, 'Cash');
    });

    test('a row cut before the amount reports the missing cells', () {
      final cutRow = row().take(3).toList();

      final errors = failedErrors([cutRow]);

      expect(errors.map((e) => e.runtimeType), [
        UnsupportedType,
        InvalidAmount,
        UnsupportedCurrency,
      ]);
    });

    test('trims cell text', () {
      final parsed = parsedRows([
        row(account: '  Cash ', category: ' Food ', amount: ' 2.5 '),
      ]);

      expect(parsed.single.account, 'Cash');
      expect(parsed.single.category, 'Food');
      expect(parsed.single.amount, Decimal.parse('2.5'));
    });

    test('keeps a blank description and subcategory as empty text', () {
      final parsed = parsedRows([row(description: '', subcategory: '')]);

      expect(parsed.single.description, '');
      expect(parsed.single.subcategory, '');
    });

    test('keeps note and description text', () {
      final parsed = parsedRows([row(note: 'N', description: 'D')]);

      expect(parsed.single.note, 'N');
      expect(parsed.single.description, 'D');
    });

    test('a Transfer-Out row takes its destination from Category', () {
      final transfer = row(type: 'Transfer-Out', category: 'Savings');

      final parsed = parsedRows([transfer]);

      expect(parsed.single.type, MoneyManagerRowType.transferOut);
      expect(parsed.single.category, 'Savings');
    });
  });

  group('row errors', () {
    test('reports each error with its 1-based sheet row', () {
      final errors = failedErrors([row(), row(account: '')]);

      final error = errors.single as MissingAccount;
      expect(error.sheetRow, 3);
    });

    test('collects errors across rows', () {
      final errors = failedErrors([
        row(account: ''),
        row(),
        row(currency: 'USD'),
        row(date: 'x'),
      ]);

      final rows = errors.cast<MoneyManagerRowError>().map((e) => e.sheetRow);
      expect(rows, [2, 4, 5]);
      expect(errors.map((e) => e.runtimeType), [
        MissingAccount,
        UnsupportedCurrency,
        InvalidDate,
      ]);
    });

    test('collects several errors from one row', () {
      final errors = failedErrors([
        row(date: '', account: '', category: '', amount: '0', currency: ''),
      ]);

      expect(errors.map((e) => e.runtimeType), [
        InvalidDate,
        MissingAccount,
        MissingCategory,
        InvalidAmount,
        UnsupportedCurrency,
      ]);
    });

    test('rejects a missing account', () {
      final errors = failedErrors([row(account: '')]);

      expect(errors.single, isA<MissingAccount>());
    });

    test('rejects a missing category on an expense', () {
      final errors = failedErrors([row(category: '')]);

      expect(errors.single, isA<MissingCategory>());
    });

    test('rejects a missing category on an income', () {
      final errors = failedErrors([row(type: 'Income', category: '')]);

      expect(errors.single, isA<MissingCategory>());
    });

    test('rejects a missing destination on a Transfer-Out', () {
      final errors = failedErrors([row(type: 'Transfer-Out', category: '')]);

      expect(errors.single, isA<MissingDestination>());
    });

    test('rejects an unsupported type and keeps its text', () {
      final errors = failedErrors([row(type: 'Transfer-In')]);

      final error = errors.single as UnsupportedType;
      expect(error.value, 'Transfer-In');
    });

    test('reports only the type error when type and category are bad', () {
      final errors = failedErrors([row(type: 'Loan', category: '')]);

      expect(errors.single, isA<UnsupportedType>());
    });

    test('rejects a non-SGD currency and keeps its text', () {
      final errors = failedErrors([row(currency: 'USD')]);

      final error = errors.single as UnsupportedCurrency;
      expect(error.value, 'USD');
    });

    test('rejects an empty currency', () {
      final errors = failedErrors([row(currency: '')]);

      expect(errors.single, isA<UnsupportedCurrency>());
    });
  });

  group('amount', () {
    test('parses decimal text', () {
      final parsed = parsedRows([row(amount: '2.0'), row(amount: '1046.65')]);

      expect(parsed[0].amount, Decimal.parse('2'));
      expect(parsed[1].amount, Decimal.parse('1046.65'));
    });

    test('rejects three decimals', () {
      final errors = failedErrors([row(amount: '1.005')]);

      final error = errors.single as InvalidAmount;
      expect(error.text, '1.005');
    });

    test('rejects zero', () {
      final errors = failedErrors([row(amount: '0')]);

      expect(errors.single, isA<InvalidAmount>());
    });

    test('rejects a negative amount', () {
      final errors = failedErrors([row(amount: '-2.00')]);

      expect(errors.single, isA<InvalidAmount>());
    });

    test('rejects a non-numeric amount', () {
      final errors = failedErrors([row(amount: 'two')]);

      expect(errors.single, isA<InvalidAmount>());
    });
  });

  group('date', () {
    test('floors a fractional serial to its day', () {
      expect(dateOf(_fractionalSerial), DateTime.utc(2026, 11, 26));
    });

    test('floors a serial just below the next day', () {
      expect(dateOf(_nearNextDaySerial), DateTime.utc(2026, 11, 26));
    });

    test('reads an exact integer serial as that day', () {
      expect(dateOf(_exactSerial), DateTime.utc(2026, 11, 26));
      expect(dateOf(_nextExactSerial), DateTime.utc(2026, 11, 27));
    });

    test('accepts the first serial day', () {
      expect(dateOf('1'), DateTime.utc(1899, 12, 31));
      expect(dateOf('1.9999'), DateTime.utc(1899, 12, 31));
    });

    test('uses the 1904 epoch when date1904 is set', () {
      final expected = DateTime.utc(2030, 11, 27);

      expect(dateOf(_fractionalSerial, date1904: true), expected);
      expect(dateOf(_nearNextDaySerial, date1904: true), expected);
      expect(dateOf(_exactSerial, date1904: true), expected);
      expect(dateOf('1', date1904: true), DateTime.utc(1904, 1, 2));
    });

    test('rejects a serial below 1', () {
      final errors = failedErrors([
        row(date: '0.9999'),
        row(date: '0'),
        row(date: '-1'),
      ]);

      expect(errors.map((e) => e.runtimeType), everyElement(InvalidDate));
      expect(errors, hasLength(3));
    });

    test('rejects a non-numeric date', () {
      final errors = failedErrors([row(date: '2026-11-26')]);

      expect(errors.single, isA<InvalidDate>());
    });
  });
}
