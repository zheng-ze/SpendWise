import 'package:spendwise/import/money_manager/money_manager_importer.dart';
import 'package:spendwise/import/money_manager/money_manager_records.dart';

const String importSaveFailedMessage =
    "Couldn't save the import. Your data was not changed.";
const String importUnexpectedMessage =
    "Couldn't import this file. Your data was not changed.";
const String unreadableFileMessage =
    "Couldn't read this file as an Excel workbook.";
const String noRowsMessage = 'The file has no rows to import.';
const String invalidDateText = "Date isn't valid";
const String missingAccountText = 'Account is missing';
const String missingCategoryText = 'Category is missing';
const String missingDestinationText = 'Destination account is missing';
const String columnSeparator = ', ';

List<String> importErrorMessages(ImportOutcome outcome) {
  return switch (outcome) {
    ImportSucceeded() => const [],
    ImportRejected(:final errors) => _rejectedMessages(errors),
    ImportSaveFailed() => const [importSaveFailedMessage],
    ImportFailedUnexpectedly() => const [importUnexpectedMessage],
  };
}

List<String> _rejectedMessages(List<MoneyManagerImportError> errors) {
  final fileMessages = [
    for (final error in errors)
      if (error is! MoneyManagerRowError) _fileMessage(error),
  ];
  final rowErrors = [
    for (var index = 0; index < errors.length; index++)
      if (errors[index] case final MoneyManagerRowError rowError)
        (index, rowError),
  ];
  rowErrors.sort((a, b) {
    final byRow = a.$2.sheetRow.compareTo(b.$2.sheetRow);
    return byRow != 0 ? byRow : a.$1.compareTo(b.$1);
  });
  final rowMessages = [for (final (_, error) in rowErrors) _rowMessage(error)];
  return [...fileMessages, ...rowMessages];
}

String _fileMessage(MoneyManagerImportError error) {
  return switch (error) {
    UnreadableFile() => unreadableFileMessage,
    MissingColumns(:final names) =>
      'Missing columns: ${names.join(columnSeparator)}',
    NoRows() => noRowsMessage,
    MoneyManagerRowError() => _rowMessage(error),
  };
}

String _rowMessage(MoneyManagerRowError error) {
  return 'Row ${error.sheetRow}: ${_rowDetail(error)}';
}

String _rowDetail(MoneyManagerRowError error) {
  return switch (error) {
    InvalidDate() => invalidDateText,
    MissingAccount() => missingAccountText,
    MissingCategory() => missingCategoryText,
    MissingDestination() => missingDestinationText,
    UnsupportedType(:final value) => 'Type "$value" isn\'t supported',
    InvalidAmount(:final text) => 'Amount "$text" isn\'t a valid amount',
    UnsupportedCurrency(:final value) =>
      'Currency "$value" isn\'t supported (only SGD)',
  };
}
