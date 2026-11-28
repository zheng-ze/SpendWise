import 'package:domain/domain.dart';
import 'package:spendwise/import/money_manager/money_manager_records.dart';

const _categorySymbol = 'tag';
const _categoryColorHex = '#007AFF';
const _transferNamePrefix = 'Transfer to ';

LedgerState buildMoneyManagerLedger(
  List<MoneyManagerRow> rows, {
  String Function() newIDFn = newID,
}) {
  final ledger = LedgerState();
  final builder = _LedgerBuilder(ledger, newIDFn);
  for (final row in rows) {
    builder.addRow(row);
  }
  return ledger;
}

typedef _CategoryKey = (CategoryKind kind, String? parent, String name);

final class _LedgerBuilder {
  _LedgerBuilder(this._ledger, this._newID);

  final LedgerState _ledger;
  final String Function() _newID;
  final Map<String, String> _accountIDs = {};
  final Map<_CategoryKey, String> _categoryIDs = {};

  void addRow(MoneyManagerRow row) {
    final sourceID = _accountID(row.account);
    if (row.type == MoneyManagerRowType.transferOut) {
      _addTransfer(row, sourceID);
      return;
    }
    _addCashflow(row, sourceID);
  }

  void _addTransfer(MoneyManagerRow row, String sourceID) {
    final destinationID = _accountID(row.category);
    _ledger.addEntry(
      Entry(
        id: _newID(),
        date: row.date,
        amount: row.amount,
        name: _entryName(row, '$_transferNamePrefix${row.category}'),
        sourceID: sourceID,
        destinationID: destinationID,
        note: row.description,
      ),
    );
  }

  void _addCashflow(MoneyManagerRow row, String sourceID) {
    final isExpense = row.type == MoneyManagerRowType.expense;
    final kind = isExpense ? CategoryKind.expense : CategoryKind.income;
    final categoryID = _bookingCategoryID(kind, row);
    _ledger.addEntry(
      Entry(
        id: _newID(),
        date: row.date,
        amount: isExpense ? -row.amount : row.amount,
        name: _entryName(row, row.category),
        categoryID: categoryID,
        sourceID: sourceID,
        note: row.description,
      ),
    );
  }

  String _entryName(MoneyManagerRow row, String fallback) {
    if (row.note.isNotEmpty) return row.note;
    if (row.subcategory.isNotEmpty) return row.subcategory;
    return fallback;
  }

  String _accountID(String name) {
    final existing = _accountIDs[name];
    if (existing != null) return existing;

    final account = Account(id: _newID(), name: name, type: AccountType.other);
    _ledger.addAccount(account);
    return _accountIDs[name] = account.id;
  }

  String _bookingCategoryID(CategoryKind kind, MoneyManagerRow row) {
    final rootID = _categoryID(kind, null, row.category);
    if (row.subcategory.isEmpty) return rootID;
    return _categoryID(kind, rootID, row.subcategory);
  }

  String _categoryID(CategoryKind kind, String? parentID, String name) {
    final key = (kind, parentID, name);
    final existing = _categoryIDs[key];
    if (existing != null) return existing;

    final category = TransactionCategory(
      id: _newID(),
      name: name,
      kind: kind,
      colorHex: _categoryColorHex,
      includeInAnalysis: true,
      parentID: parentID,
      symbol: _categorySymbol,
    );
    _ledger.addCategory(category);
    return _categoryIDs[key] = category.id;
  }
}
