import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final account = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );
  final destinationAccount = Account(
    id: 'a0000000-0000-0000-0000-000000000002',
    name: 'Savings',
    type: AccountType.savings,
  );

  final parentCategory = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000001',
    name: 'Food',
    kind: CategoryKind.expense,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'restaurant',
  );
  final childCategory = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000002',
    name: 'Coffee',
    kind: CategoryKind.expense,
    colorHex: '#00FF00',
    includeInAnalysis: true,
    parentID: parentCategory.id,
    symbol: 'local_cafe',
  );

  LedgerState baseState() => LedgerState(
    moneySources: {
      account.id: MoneySource.account(account),
      destinationAccount.id: MoneySource.account(destinationAccount),
    },
    categories: {
      parentCategory.id: parentCategory,
      childCategory.id: childCategory,
    },
  );

  test('non-transfer with a parent-only category titles the row from it', () {
    final state = baseState();
    final entry = Entry(
      amount: dec('-12.50'),
      name: 'lunch',
      categoryID: parentCategory.id,
      sourceID: account.id,
    );

    final row = transactionRow(entry, state);

    expect(row.title, 'Food');
    expect(row.accountLine, 'Checking');
    expect(row.symbolName, 'restaurant');
    expect(row.color, parseColorHex(parentCategory.colorHex));
    expect(row.amount, dec('-12.50'));
    expect(row.amountKind, AmountKind.expense);
    expect(row.note, 'lunch');
  });

  test('non-transfer under a nested category titles as Parent/Child', () {
    final state = baseState();
    final entry = Entry(
      amount: dec('-4.20'),
      name: 'flat white',
      categoryID: childCategory.id,
      sourceID: account.id,
    );

    final row = transactionRow(entry, state);

    expect(row.title, 'Food/Coffee');
    expect(row.symbolName, 'local_cafe');
    expect(row.color, parseColorHex(childCategory.colorHex));
  });

  test('non-transfer with no category is Uncategorized', () {
    final state = baseState();
    final entry = Entry(amount: dec('100'), name: 'gift', sourceID: account.id);

    final row = transactionRow(entry, state);

    expect(row.title, 'Uncategorized');
    expect(row.symbolName, 'help_outline');
    expect(row.amountKind, AmountKind.income);
    expect(row.amount, dec('100'));
  });

  test('transfer titles as Transfer with a Source > Destination line', () {
    final state = baseState();
    final entry = Entry(
      amount: dec('75'),
      name: 'move funds',
      sourceID: account.id,
      destinationID: destinationAccount.id,
    );

    final row = transactionRow(entry, state);

    expect(row.title, 'Transfer');
    expect(row.accountLine, 'Checking > Savings');
    expect(row.symbolName, 'swap_horiz');
    expect(row.amountKind, AmountKind.transfer);
    expect(row.amount, dec('75'));
  });

  test('transfer amount is an unsigned magnitude even if stored negative', () {
    final state = baseState();
    final entry = Entry(
      amount: dec('-30'),
      name: 'reversed transfer',
      sourceID: account.id,
      destinationID: destinationAccount.id,
    );

    final row = transactionRow(entry, state);

    expect(row.amount, dec('30'));
    expect(row.amountKind, AmountKind.transfer);
  });

  test('unresolvable source falls back to an unknown label', () {
    final state = LedgerState(
      moneySources: {
        destinationAccount.id: MoneySource.account(destinationAccount),
      },
    );
    final entry = Entry(
      amount: dec('-5'),
      name: 'orphaned',
      sourceID: 'a0000000-0000-0000-0000-00000000dead',
    );

    final row = transactionRow(entry, state);

    expect(row.accountLine, 'Unknown');
  });

  test(
    'unresolvable destination falls back to an unknown label in a transfer',
    () {
      final state = LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
      );
      final entry = Entry(
        amount: dec('10'),
        name: 'to nowhere',
        sourceID: account.id,
        destinationID: 'a0000000-0000-0000-0000-00000000dead',
      );

      final row = transactionRow(entry, state);

      expect(row.accountLine, 'Checking > Unknown');
    },
  );

  group('transfer scope', () {
    test('destination in scope, source out, reads as a gain', () {
      final state = baseState();
      final entry = Entry(
        amount: dec('75'),
        name: 'move funds',
        sourceID: account.id,
        destinationID: destinationAccount.id,
      );

      final row = transactionRow(
        entry,
        state,
        scopeIDs: {destinationAccount.id},
      );

      expect(row.amountKind, AmountKind.income);
    });

    test('source in scope, destination out, reads as a loss', () {
      final state = baseState();
      final entry = Entry(
        amount: dec('75'),
        name: 'move funds',
        sourceID: account.id,
        destinationID: destinationAccount.id,
      );

      final row = transactionRow(entry, state, scopeIDs: {account.id});

      expect(row.amountKind, AmountKind.expense);
    });

    test('a transfer from an account to its own pocket is neutral at account '
        'scope and a gain at pocket scope', () {
      final pocketID = 'p0000000-0000-0000-0000-000000000001';
      final accountWithPocket = Account(
        id: account.id,
        name: account.name,
        type: account.type,
        subPocketIDs: {pocketID},
      );
      final pocket = SubPocket(id: pocketID, name: 'Savings jar');
      final state = LedgerState(
        moneySources: {
          accountWithPocket.id: MoneySource.account(accountWithPocket),
          pocket.id: MoneySource.pocket(pocket),
        },
      );
      final entry = Entry(
        amount: dec('20'),
        name: 'set aside',
        sourceID: accountWithPocket.id,
        destinationID: pocket.id,
      );

      final accountScopeRow = transactionRow(
        entry,
        state,
        scopeIDs: {accountWithPocket.id, pocket.id},
      );
      final pocketScopeRow = transactionRow(
        entry,
        state,
        scopeIDs: {pocket.id},
      );

      expect(accountScopeRow.amountKind, AmountKind.transfer);
      expect(pocketScopeRow.amountKind, AmountKind.income);
    });
  });
}
