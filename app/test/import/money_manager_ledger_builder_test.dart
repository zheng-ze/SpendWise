import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/import/money_manager/money_manager_ledger_builder.dart';
import 'package:spendwise/import/money_manager/money_manager_records.dart';

const _hexIdPrefix = 'abcdef00-0000-4000-8000-';
const _idDigits = 12;
const _idRadix = 16;

MoneyManagerRow row({
  MoneyManagerRowType type = MoneyManagerRowType.expense,
  DateTime? date,
  String account = 'Cash',
  String category = 'Food',
  String subcategory = '',
  String note = '',
  String description = '',
  String amount = '2.0',
}) {
  return MoneyManagerRow(
    sheetRow: 2,
    type: type,
    date: date ?? DateTime.utc(2026, 11, 26),
    account: account,
    category: category,
    subcategory: subcategory,
    note: note,
    description: description,
    amount: Decimal.parse(amount),
  );
}

MoneyManagerRow transfer({
  String account = 'Cash',
  String destination = 'Bank',
  String note = '',
  String amount = '10',
}) {
  return row(
    type: MoneyManagerRowType.transferOut,
    account: account,
    category: destination,
    note: note,
    amount: amount,
  );
}

String Function() hexIds({String prefix = _hexIdPrefix}) {
  var counter = 0;
  return () {
    counter++;
    return '$prefix${counter.toRadixString(_idRadix).padLeft(_idDigits, '0')}';
  };
}

LedgerState build(List<MoneyManagerRow> rows) {
  return buildMoneyManagerLedger(rows, newIDFn: hexIds());
}

List<Account> accountsOf(LedgerState ledger) {
  return ledger.moneySources.values.map((s) => s.asAccount!).toList();
}

List<String> accountNames(LedgerState ledger) {
  return accountsOf(ledger).map((account) => account.name).toList();
}

TransactionCategory categoryNamed(
  LedgerState ledger,
  String name, {
  CategoryKind? kind,
}) {
  return ledger.categories.values.singleWhere(
    (c) => c.name == name && (kind == null || c.kind == kind),
  );
}

Entry onlyEntry(LedgerState ledger) => ledger.entries.values.single;

void main() {
  group('accounts', () {
    test('are the union of Account values and transfer destinations', () {
      final ledger = build([
        row(account: 'Cash'),
        transfer(account: 'Cash', destination: 'System'),
        transfer(account: 'Bank', destination: 'Savings'),
      ]);

      expect(accountNames(ledger), ['Cash', 'System', 'Bank', 'Savings']);
    });

    test('are all type other with default flags and no pockets', () {
      final ledger = build([transfer()]);

      final accounts = accountsOf(ledger);
      expect(accounts.every((a) => a.type == AccountType.other), isTrue);
      expect(accounts.every((a) => a.subPocketIDs.isEmpty), isTrue);
      expect(ledger.moneySources.values.every((s) => s.asPocket == null), true);
    });

    test('a name shared by a row account and a destination is one account', () {
      final ledger = build([
        row(account: 'Bank'),
        transfer(account: 'Cash', destination: 'Bank'),
      ]);

      expect(accountNames(ledger), ['Bank', 'Cash']);
    });

    test('a repeated name creates one account', () {
      final ledger = build([row(account: 'Cash'), row(account: 'Cash')]);

      expect(accountNames(ledger), ['Cash']);
    });

    test('a destination-only account is created', () {
      final ledger = build([transfer(account: 'Cash', destination: 'OA')]);

      expect(accountNames(ledger), contains('OA'));
    });
  });

  group('categories', () {
    test('Other exists once per kind', () {
      final ledger = build([
        row(category: 'Other'),
        row(category: 'Other'),
        row(type: MoneyManagerRowType.income, category: 'Other'),
        row(type: MoneyManagerRowType.income, category: 'Other'),
      ]);

      final others = ledger.categories.values.where((c) => c.name == 'Other');
      expect(others.map((c) => c.kind), [
        CategoryKind.expense,
        CategoryKind.income,
      ]);
    });

    test('are created with the fixed presentation fields', () {
      final ledger = build([row(category: 'Food')]);

      final category = categoryNamed(ledger, 'Food');
      expect(category.symbol, 'tag');
      expect(category.colorHex, '#007AFF');
      expect(category.includeInAnalysis, isTrue);
      expect(category.parentID, isNull);
    });

    test('a repeated root category is created once', () {
      final ledger = build([row(category: 'Food'), row(category: 'Food')]);

      expect(ledger.categories, hasLength(1));
    });

    test('a subcategory creates a child and the entry books to it', () {
      final ledger = build([row(category: 'Food', subcategory: 'Lunch')]);

      final root = categoryNamed(ledger, 'Food');
      final child = categoryNamed(ledger, 'Lunch');
      expect(child.parentID, root.id);
      expect(child.kind, CategoryKind.expense);
      expect(onlyEntry(ledger).categoryID, child.id);
    });

    test('a child is created once per kind, parent and name', () {
      final ledger = build([
        row(category: 'Food', subcategory: 'Lunch'),
        row(category: 'Food', subcategory: 'Lunch'),
        row(category: 'Drink', subcategory: 'Lunch'),
        row(
          type: MoneyManagerRowType.income,
          category: 'Food',
          subcategory: 'Lunch',
        ),
      ]);

      final names = ledger.categories.values.map((c) => c.name).toList();
      expect(names, ['Food', 'Lunch', 'Drink', 'Lunch', 'Food', 'Lunch']);
    });

    test('a row without subcategory books to the root', () {
      final ledger = build([row(category: 'Food')]);

      expect(onlyEntry(ledger).categoryID, categoryNamed(ledger, 'Food').id);
    });

    test('transfers create no categories', () {
      final ledger = build([transfer()]);

      expect(ledger.categories, isEmpty);
    });
  });

  group('entries', () {
    test('an expense is stored negated and books to its account', () {
      final ledger = build([row(amount: '2.0', account: 'GrabPay')]);

      final entry = onlyEntry(ledger);
      expect(entry.amount, Decimal.parse('-2'));
      expect(entry.sourceID, accountsOf(ledger).single.id);
      expect(entry.destinationID, isNull);
    });

    test('an income is stored positive', () {
      final ledger = build([
        row(type: MoneyManagerRowType.income, amount: '1046.65'),
      ]);

      final entry = onlyEntry(ledger);
      expect(entry.amount, Decimal.parse('1046.65'));
      expect(entry.destinationID, isNull);
      expect(entry.categoryID, categoryNamed(ledger, 'Food').id);
    });

    test('a transfer is positive from the account to the destination', () {
      final ledger = build([
        transfer(account: 'Cash', destination: 'Bank', amount: '10'),
      ]);

      final ids = {for (final a in accountsOf(ledger)) a.name: a.id};
      final entry = onlyEntry(ledger);
      expect(entry.amount, Decimal.parse('10'));
      expect(entry.sourceID, ids['Cash']);
      expect(entry.destinationID, ids['Bank']);
      expect(entry.categoryID, isNull);
    });

    test('keep the calendar day of the row date', () {
      final ledger = build([row(date: DateTime.utc(2026, 11, 26, 23, 59))]);

      expect(onlyEntry(ledger).date, DateTime.utc(2026, 11, 26));
    });

    test('Description becomes the note and blank becomes null', () {
      final ledger = build([
        row(description: 'paid by card', note: 'with'),
        row(description: '  ', note: 'blank'),
      ]);

      final notes = {for (final e in ledger.entries.values) e.name: e.note};
      expect(notes, {'with': 'paid by card', 'blank': null});
    });

    test('a transfer carries the Description as its note', () {
      final ledger = build([
        row(
          type: MoneyManagerRowType.transferOut,
          category: 'Bank',
          description: 'top up',
        ),
      ]);

      expect(onlyEntry(ledger).note, 'top up');
    });
  });

  group('entry name', () {
    test('uses the Note first', () {
      final ledger = build([
        row(note: 'Coffee', subcategory: 'Drinks', category: 'Food'),
      ]);

      expect(onlyEntry(ledger).name, 'Coffee');
    });

    test('falls back to the Subcategory', () {
      final ledger = build([row(subcategory: 'Drinks', category: 'Food')]);

      expect(onlyEntry(ledger).name, 'Drinks');
    });

    test('falls back to the Category', () {
      final ledger = build([row(category: 'Food')]);

      expect(onlyEntry(ledger).name, 'Food');
    });

    test('a transfer without a note is named Transfer to the destination', () {
      final ledger = build([transfer(destination: 'Bank')]);

      expect(onlyEntry(ledger).name, 'Transfer to Bank');
    });

    test('a transfer uses its Note when present', () {
      final ledger = build([transfer(note: 'Rent')]);

      expect(onlyEntry(ledger).name, 'Rent');
    });
  });

  group('ids', () {
    test('injected ids with hex letters are used as given', () {
      final ledger = build([row(), transfer()]);

      final ids = [
        ...ledger.moneySources.keys,
        ...ledger.categories.keys,
        ...ledger.entries.keys,
      ];
      expect(ids.every((id) => id.startsWith('abcdef00')), isTrue);
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('uppercase injected ids are stored lowercase', () {
      final ledger = buildMoneyManagerLedger([
        row(category: 'Food', subcategory: 'Lunch'),
        transfer(),
      ], newIDFn: hexIds(prefix: _hexIdPrefix.toUpperCase()));

      final entry = ledger.entries.values.first;
      final ids = [
        ...ledger.moneySources.keys,
        ...ledger.categories.keys,
        ...ledger.entries.keys,
        entry.sourceID,
        entry.categoryID!,
      ];
      expect(ids.every((id) => id == id.toLowerCase()), isTrue);
      expect(ids.every((id) => id.startsWith('abcdef00')), isTrue);
    });
  });

  test('the default id function produces distinct ids', () {
    final ledger = buildMoneyManagerLedger([row(), row()]);

    expect(ledger.entries, hasLength(2));
  });
}
