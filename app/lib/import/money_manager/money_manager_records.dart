import 'package:decimal/decimal.dart';
import 'package:spendwise/import/xlsx/xlsx_sheet.dart';

enum MoneyManagerRowType { expense, income, transferOut }

final class MoneyManagerRow {
  const MoneyManagerRow({
    required this.sheetRow,
    required this.type,
    required this.date,
    required this.account,
    required this.category,
    required this.subcategory,
    required this.note,
    required this.description,
    required this.amount,
  });

  final int sheetRow;
  final MoneyManagerRowType type;
  final DateTime date;
  final String account;
  final String category;
  final String subcategory;
  final String note;
  final String description;
  final Decimal amount;
}

sealed class MoneyManagerImportError {
  const MoneyManagerImportError();
}

sealed class MoneyManagerRowError extends MoneyManagerImportError {
  const MoneyManagerRowError(this.sheetRow);

  final int sheetRow;
}

final class UnreadableFile extends MoneyManagerImportError {
  const UnreadableFile();
}

final class MissingColumns extends MoneyManagerImportError {
  const MissingColumns(this.names);

  final List<String> names;
}

final class NoRows extends MoneyManagerImportError {
  const NoRows();
}

final class InvalidDate extends MoneyManagerRowError {
  const InvalidDate(super.sheetRow);
}

final class MissingAccount extends MoneyManagerRowError {
  const MissingAccount(super.sheetRow);
}

final class MissingCategory extends MoneyManagerRowError {
  const MissingCategory(super.sheetRow);
}

final class MissingDestination extends MoneyManagerRowError {
  const MissingDestination(super.sheetRow);
}

final class UnsupportedType extends MoneyManagerRowError {
  const UnsupportedType(super.sheetRow, this.value);

  final String value;
}

final class InvalidAmount extends MoneyManagerRowError {
  const InvalidAmount(super.sheetRow, this.text);

  final String text;
}

final class UnsupportedCurrency extends MoneyManagerRowError {
  const UnsupportedCurrency(super.sheetRow, this.value);

  final String value;
}

sealed class MoneyManagerParseResult {
  const MoneyManagerParseResult();
}

final class MoneyManagerRecords extends MoneyManagerParseResult {
  const MoneyManagerRecords(this.rows);

  final List<MoneyManagerRow> rows;
}

final class MoneyManagerRecordsFailed extends MoneyManagerParseResult {
  const MoneyManagerRecordsFailed(this.errors);

  final List<MoneyManagerImportError> errors;
}

const _dateHeader = 'Date';
const _accountHeader = 'Account';
const _categoryHeader = 'Category';
const _subcategoryHeader = 'Subcategory';
const _noteHeader = 'Note';
const _typeHeader = 'Income/Expense';
const _descriptionHeader = 'Description';
const _amountHeader = 'Amount';
const _currencyHeader = 'Currency';

const _requiredHeaders = [
  _dateHeader,
  _accountHeader,
  _categoryHeader,
  _subcategoryHeader,
  _noteHeader,
  _typeHeader,
  _descriptionHeader,
  _amountHeader,
  _currencyHeader,
];

const _expenseValue = 'Expense';
const _incomeValue = 'Income';
const _transferOutValue = 'Transfer-Out';
const _supportedCurrency = 'SGD';
const _maxAmountScale = 2;
const _minSerialDay = 1;
const _maxSerialDay1900 = 2958465;
const _daysBetweenEpochs = 1462;
const _headerRowCount = 1;
const _firstSerialEpoch1900 = (1899, 12, 30);
const _firstSerialEpoch1904 = (1904, 1, 1);

MoneyManagerParseResult parseMoneyManagerSheet(XlsxSheet sheet) {
  final rows = sheet.rows;
  if (rows.length <= _headerRowCount) {
    return const MoneyManagerRecordsFailed([NoRows()]);
  }
  final columns = _columnIndexes(rows.first);
  final missing = _requiredHeaders.where((name) => !columns.containsKey(name));
  if (missing.isNotEmpty) {
    return MoneyManagerRecordsFailed([MissingColumns(missing.toList())]);
  }

  final parsed = <MoneyManagerRow>[];
  final errors = <MoneyManagerImportError>[];
  for (var index = _headerRowCount; index < rows.length; index++) {
    final cells = _RowCells(rows[index], columns);
    final row = _parseRow(index + 1, cells, sheet.date1904, errors);
    if (row != null) parsed.add(row);
  }
  if (errors.isNotEmpty) return MoneyManagerRecordsFailed(errors);
  return MoneyManagerRecords(parsed);
}

Map<String, int> _columnIndexes(List<String> header) {
  final columns = <String, int>{};
  for (var index = 0; index < header.length; index++) {
    columns.putIfAbsent(header[index].trim(), () => index);
  }
  return columns;
}

final class _RowCells {
  const _RowCells(this._cells, this._columns);

  final List<String> _cells;
  final Map<String, int> _columns;

  String operator [](String header) {
    final index = _columns[header]!;
    if (index >= _cells.length) return '';
    return _cells[index].trim();
  }
}

MoneyManagerRow? _parseRow(
  int sheetRow,
  _RowCells cells,
  bool date1904,
  List<MoneyManagerImportError> errors,
) {
  final before = errors.length;
  final date = _parseDate(cells[_dateHeader], date1904);
  if (date == null) errors.add(InvalidDate(sheetRow));

  final account = cells[_accountHeader];
  if (account.isEmpty) errors.add(MissingAccount(sheetRow));

  final typeText = cells[_typeHeader];
  final type = _parseType(typeText);
  final category = cells[_categoryHeader];
  final categoryError = _categoryError(sheetRow, type, typeText, category);
  if (categoryError != null) errors.add(categoryError);

  final amountText = cells[_amountHeader];
  final amount = _parseAmount(amountText);
  if (amount == null) errors.add(InvalidAmount(sheetRow, amountText));

  final currency = cells[_currencyHeader];
  if (currency != _supportedCurrency) {
    errors.add(UnsupportedCurrency(sheetRow, currency));
  }

  if (errors.length > before) return null;
  return MoneyManagerRow(
    sheetRow: sheetRow,
    type: type!,
    date: date!,
    account: account,
    category: category,
    subcategory: cells[_subcategoryHeader],
    note: cells[_noteHeader],
    description: cells[_descriptionHeader],
    amount: amount!,
  );
}

MoneyManagerRowError? _categoryError(
  int sheetRow,
  MoneyManagerRowType? type,
  String typeText,
  String category,
) {
  if (type == null) return UnsupportedType(sheetRow, typeText);
  if (category.isNotEmpty) return null;
  if (type == MoneyManagerRowType.transferOut) {
    return MissingDestination(sheetRow);
  }
  return MissingCategory(sheetRow);
}

MoneyManagerRowType? _parseType(String text) => switch (text) {
  _expenseValue => MoneyManagerRowType.expense,
  _incomeValue => MoneyManagerRowType.income,
  _transferOutValue => MoneyManagerRowType.transferOut,
  _ => null,
};

Decimal? _parseAmount(String text) {
  final amount = Decimal.tryParse(text);
  if (amount == null) return null;
  if (amount <= Decimal.zero) return null;
  if (amount.scale > _maxAmountScale) return null;
  return amount;
}

DateTime? _parseDate(String text, bool date1904) {
  final serial = Decimal.tryParse(text);
  if (serial == null) return null;
  final day = serial.floor().toBigInt().toInt();
  final maxDay = date1904
      ? _maxSerialDay1900 - _daysBetweenEpochs
      : _maxSerialDay1900;
  if (day < _minSerialDay || day > maxDay) return null;
  final (year, month, firstDay) = date1904
      ? _firstSerialEpoch1904
      : _firstSerialEpoch1900;
  return DateTime.utc(year, month, firstDay + day);
}
