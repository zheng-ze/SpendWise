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

final class UnexpectedColumns extends MoneyManagerImportError {
  const UnexpectedColumns();
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

const _expectedHeaders = [
  'Date',
  'Account',
  'Category',
  'Subcategory',
  'Note',
  'SGD',
  'Income/Expense',
  'Tag',
  'Description',
  'Amount',
  'Currency',
  'Account',
];

const _dateColumn = 0;
const _accountColumn = 1;
const _categoryColumn = 2;
const _subcategoryColumn = 3;
const _noteColumn = 4;
const _typeColumn = 6;
const _descriptionColumn = 8;
const _amountColumn = 9;
const _currencyColumn = 10;

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
  final header = _trimmedHeader(rows.first);
  final missing = _missingHeaders(header);
  if (missing.isNotEmpty) {
    return MoneyManagerRecordsFailed([MissingColumns(missing)]);
  }
  if (!_isExpectedHeader(header)) {
    return const MoneyManagerRecordsFailed([UnexpectedColumns()]);
  }

  final parsed = <MoneyManagerRow>[];
  final errors = <MoneyManagerImportError>[];
  for (var index = _headerRowCount; index < rows.length; index++) {
    final cells = _RowCells(rows[index]);
    final row = _parseRow(index + 1, cells, sheet.date1904, errors);
    if (row != null) parsed.add(row);
  }
  if (errors.isNotEmpty) return MoneyManagerRecordsFailed(errors);
  return MoneyManagerRecords(parsed);
}

List<String> _trimmedHeader(List<String> header) {
  final trimmed = [for (final cell in header) cell.trim()];
  while (trimmed.isNotEmpty && trimmed.last.isEmpty) {
    trimmed.removeLast();
  }
  return trimmed;
}

List<String> _missingHeaders(List<String> header) {
  final remaining = [...header];
  final missing = <String>[];
  for (final name in _expectedHeaders) {
    if (remaining.remove(name)) continue;
    if (!missing.contains(name)) missing.add(name);
  }
  return missing;
}

bool _isExpectedHeader(List<String> header) {
  if (header.length != _expectedHeaders.length) return false;
  for (var index = 0; index < header.length; index++) {
    if (header[index] != _expectedHeaders[index]) return false;
  }
  return true;
}

final class _RowCells {
  const _RowCells(this._cells);

  final List<String> _cells;

  String operator [](int column) {
    if (column >= _cells.length) return '';
    return _cells[column].trim();
  }
}

MoneyManagerRow? _parseRow(
  int sheetRow,
  _RowCells cells,
  bool date1904,
  List<MoneyManagerImportError> errors,
) {
  final before = errors.length;
  final date = _parseDate(cells[_dateColumn], date1904);
  if (date == null) errors.add(InvalidDate(sheetRow));

  final account = cells[_accountColumn];
  if (account.isEmpty) errors.add(MissingAccount(sheetRow));

  final typeText = cells[_typeColumn];
  final type = _parseType(typeText);
  final category = cells[_categoryColumn];
  final categoryError = _categoryError(sheetRow, type, typeText, category);
  if (categoryError != null) errors.add(categoryError);

  final amountText = cells[_amountColumn];
  final amount = _parseAmount(amountText);
  if (amount == null) errors.add(InvalidAmount(sheetRow, amountText));

  final currency = cells[_currencyColumn];
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
    subcategory: cells[_subcategoryColumn],
    note: cells[_noteColumn],
    description: cells[_descriptionColumn],
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
