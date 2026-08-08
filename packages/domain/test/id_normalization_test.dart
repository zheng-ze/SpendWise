import 'package:decimal/decimal.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

const _upper = '6F1A2B3C-4D5E-6F70-8192-A3B4C5D6E7F8';
const _lower = '6f1a2b3c-4d5e-6f70-8192-a3b4c5d6e7f8';

void main() {
  test('Entry canonicalizes every id it holds', () {
    final entry = Entry(
      id: _upper,
      amount: Decimal.one,
      name: 'e',
      categoryID: _upper,
      sourceID: _upper,
      destinationID: _upper,
    );

    expect(entry.id, _lower);
    expect(entry.categoryID, _lower);
    expect(entry.sourceID, _lower);
    expect(entry.destinationID, _lower);
  });

  test('Account canonicalizes its id and pocket links', () {
    final account = Account(
      id: _upper,
      name: 'a',
      type: AccountType.savings,
      subPocketIDs: {_upper},
    );

    expect(account.id, _lower);
    expect(account.subPocketIDs, {_lower});
  });

  test('SubPocket canonicalizes its id', () {
    expect(SubPocket(id: _upper, name: 'p').id, _lower);
  });

  test('TransactionCategory canonicalizes its id and parent', () {
    final category = TransactionCategory(
      id: _upper,
      name: 'c',
      kind: CategoryKind.expense,
      colorHex: '#888888',
      includeInAnalysis: true,
      parentID: _upper,
      symbol: 'tag',
    );

    expect(category.id, _lower);
    expect(category.parentID, _lower);
  });

  test('null optional ids stay null', () {
    final entry = Entry(amount: Decimal.one, name: 'e', sourceID: _lower);

    expect(entry.categoryID, isNull);
    expect(entry.destinationID, isNull);
  });

  test('generated ids are canonical', () {
    final id = Entry(amount: Decimal.one, name: 'e', sourceID: _lower).id;

    expect(id, canonicalID(id));
  });

  test('pocket links added after construction are canonicalized', () {
    final account = Account(
      name: 'a',
      type: AccountType.savings,
    ).addSubPocket(_upper);

    expect(account.subPocketIDs, {_lower});
    expect(account.removeSubPocket(_upper).subPocketIDs, isEmpty);
  });

  test('an uppercase id resolves against a canonical one', () {
    final entry = Entry(
      amount: Decimal.one,
      name: 'e',
      sourceID: _upper,
      destinationID: _lower,
    );

    expect(entry.references(_lower), isTrue);
    expect(entry.holderIDs, {_lower});
  });
}
