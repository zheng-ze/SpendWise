import 'package:domain/domain.dart';
import 'package:test/test.dart';

const accountID = '11111111-1111-4111-8111-111111111111';
const pocketID = '22222222-2222-4222-8222-222222222222';
const categoryID = '33333333-3333-4333-8333-333333333333';
const entryID = '44444444-4444-4444-8444-444444444444';
const budgetID = '55555555-5555-4555-8555-555555555555';

Account account({String id = accountID, String name = 'acc'}) =>
    Account(id: id, name: name, type: AccountType.savings);

SubPocket pocket({String id = pocketID, String name = 'pkt'}) =>
    SubPocket(id: id, name: name);

TransactionCategory category({String id = categoryID, String name = 'cat'}) =>
    TransactionCategory(
      id: id,
      name: name,
      kind: CategoryKind.expense,
      colorHex: '#888888',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    );

Entry entry({String id = entryID, String name = 'e'}) => Entry(
  id: id,
  date: DateTime.utc(2026),
  amount: Decimal.fromInt(-10),
  name: name,
  sourceID: accountID,
);

Budget budget({String id = budgetID, Decimal? amount}) => Budget(
  id: id,
  categoryID: categoryID,
  limitEvents: [
    LimitEvent(
      effectiveFromMonth: null,
      value: amount ?? Decimal.fromInt(100),
      kind: LimitEventKind.defaultLimit,
    ),
  ],
  createdAtMonth: const YearMonth(2026, 1),
);

void main() {
  group('LedgerChange equality', () {
    test('same case and equal payload compare equal', () {
      expect(UpsertAccount(account()), UpsertAccount(account()));
      expect(UpsertPocket(pocket()), UpsertPocket(pocket()));
      expect(UpsertCategory(category()), UpsertCategory(category()));
      expect(UpsertEntry(entry()), UpsertEntry(entry()));
      expect(
        const DeleteMoneySource(accountID),
        const DeleteMoneySource(accountID),
      );
      expect(
        const DeleteCategory(categoryID),
        const DeleteCategory(categoryID),
      );
      expect(const DeleteEntry(entryID), const DeleteEntry(entryID));
    });

    test('equal changes share a hash code', () {
      expect(
        UpsertAccount(account()).hashCode,
        UpsertAccount(account()).hashCode,
      );
      expect(
        const DeleteMoneySource(accountID).hashCode,
        const DeleteMoneySource(accountID).hashCode,
      );
    });

    test('differing payload compares unequal', () {
      expect(
        UpsertAccount(account(name: 'other')),
        isNot(UpsertAccount(account())),
      );
      expect(
        UpsertPocket(pocket(name: 'other')),
        isNot(UpsertPocket(pocket())),
      );
      expect(
        UpsertCategory(category(name: 'other')),
        isNot(UpsertCategory(category())),
      );
      expect(UpsertEntry(entry(name: 'other')), isNot(UpsertEntry(entry())));
      expect(
        const DeleteMoneySource(accountID),
        isNot(const DeleteMoneySource(pocketID)),
      );
    });

    test('delete cases with the same id never compare equal across cases', () {
      expect(
        const DeleteMoneySource(entryID),
        isNot(const DeleteEntry(entryID)),
      );
      expect(const DeleteCategory(entryID), isNot(const DeleteEntry(entryID)));
      expect(
        const DeleteMoneySource(entryID),
        isNot(const DeleteCategory(entryID)),
      );
    });

    test('budget cases behave the same as the other upsert/delete cases', () {
      expect(UpsertBudget(budget()), UpsertBudget(budget()));
      expect(UpsertBudget(budget()).hashCode, UpsertBudget(budget()).hashCode);
      expect(
        UpsertBudget(budget(amount: Decimal.fromInt(200))),
        isNot(UpsertBudget(budget())),
      );
      expect(const DeleteBudget(budgetID), const DeleteBudget(budgetID));
      expect(
        const DeleteBudget(budgetID),
        isNot(const DeleteBudget(accountID)),
      );
      expect(const DeleteBudget(entryID), isNot(const DeleteEntry(entryID)));
    });

    test('change lists compare by value', () {
      expect(
        [UpsertPocket(pocket()), UpsertAccount(account())],
        [UpsertPocket(pocket()), UpsertAccount(account())],
      );
      expect([
        UpsertAccount(account()),
        UpsertPocket(pocket()),
      ], isNot([UpsertPocket(pocket()), UpsertAccount(account())]));
    });
  });

  group('LedgerChange.targetID', () {
    test('yields the payload id for all seven cases', () {
      expect(UpsertAccount(account()).targetID, accountID);
      expect(UpsertPocket(pocket()).targetID, pocketID);
      expect(UpsertCategory(category()).targetID, categoryID);
      expect(UpsertEntry(entry()).targetID, entryID);
      expect(const DeleteMoneySource(accountID).targetID, accountID);
      expect(const DeleteCategory(categoryID).targetID, categoryID);
      expect(const DeleteEntry(entryID).targetID, entryID);
      expect(UpsertBudget(budget()).targetID, budgetID);
      expect(const DeleteBudget(budgetID).targetID, budgetID);
    });
  });

  group('LedgerChange.upsertSource', () {
    test('dispatches on the source variant', () {
      expect(
        LedgerChange.upsertSource(AccountSource(account())),
        UpsertAccount(account()),
      );
      expect(
        LedgerChange.upsertSource(PocketSource(pocket())),
        UpsertPocket(pocket()),
      );
    });
  });

  group('LedgerError equality', () {
    test('same case and id compare equal', () {
      expect(const IdCollision(accountID), const IdCollision(accountID));
      expect(const UnknownAccount(accountID), const UnknownAccount(accountID));
      expect(const UnknownHolder(pocketID), const UnknownHolder(pocketID));
      expect(
        const UnknownCategory(categoryID),
        const UnknownCategory(categoryID),
      );
      expect(const UnknownEntry(entryID), const UnknownEntry(entryID));
      expect(
        const InactiveReference(accountID),
        const InactiveReference(accountID),
      );
      expect(const ZeroAmount(), const ZeroAmount());
      expect(const CategoryTooDeep(), const CategoryTooDeep());
      expect(const CategoryKindMismatch(), const CategoryKindMismatch());
      expect(const UnknownBudget(budgetID), const UnknownBudget(budgetID));
      expect(const CategoryAlreadyBudgeted(), const CategoryAlreadyBudgeted());
    });

    test('equal errors share a hash code', () {
      expect(
        const IdCollision(accountID).hashCode,
        const IdCollision(accountID).hashCode,
      );
      expect(const ZeroAmount().hashCode, const ZeroAmount().hashCode);
    });

    test('differing id compares unequal', () {
      expect(const IdCollision(accountID), isNot(const IdCollision(pocketID)));
      expect(
        const InactiveReference(accountID),
        isNot(const InactiveReference(pocketID)),
      );
    });

    test('cases carrying the same id never compare equal across cases', () {
      expect(
        const IdCollision(accountID),
        isNot(const UnknownAccount(accountID)),
      );
      expect(
        const UnknownAccount(accountID),
        isNot(const UnknownHolder(accountID)),
      );
      expect(
        const UnknownCategory(accountID),
        isNot(const UnknownEntry(accountID)),
      );
      expect(
        const UnknownHolder(accountID),
        isNot(const InactiveReference(accountID)),
      );
      expect(
        const UnknownBudget(accountID),
        isNot(const UnknownAccount(accountID)),
      );
    });

    test('differing id compares unequal for UnknownBudget', () {
      expect(
        const UnknownBudget(budgetID),
        isNot(const UnknownBudget(accountID)),
      );
    });

    test('payload-free cases never compare equal across cases', () {
      expect(const ZeroAmount(), isNot(const CategoryTooDeep()));
      expect(const CategoryTooDeep(), isNot(const CategoryKindMismatch()));
      expect(const CategoryKindMismatch(), isNot(const ZeroAmount()));
    });

    test('errors are throwable', () {
      expect(
        () => throw const ZeroAmount(),
        throwsA(
          isA<LedgerError>().having((e) => e, 'value', const ZeroAmount()),
        ),
      );
    });
  });
}
