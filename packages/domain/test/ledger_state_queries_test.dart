import 'package:decimal/decimal.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

const accountA = '11111111-1111-4111-8111-111111111111';
const accountB = '11111111-1111-4111-8111-111111111112';
const pocketP = '22222222-2222-4222-8222-222222222221';
const pocketQ = '22222222-2222-4222-8222-222222222222';
const categoryC = '33333333-3333-4333-8333-333333333331';
const categoryD = '33333333-3333-4333-8333-333333333332';
const ghostID = '99999999-9999-4999-8999-999999999999';

Account account(
  String id, {
  String name = 'acc',
  Set<String> subPocketIDs = const {},
  LifecycleState lifecycle = LifecycleState.active,
}) => Account(
  id: id,
  name: name,
  type: AccountType.savings,
  subPocketIDs: subPocketIDs,
  lifecycle: lifecycle,
);

SubPocket pocket(
  String id, {
  String name = 'pkt',
  LifecycleState lifecycle = LifecycleState.active,
}) => SubPocket(id: id, name: name, lifecycle: lifecycle);

TransactionCategory category(
  String id, {
  String name = 'cat',
  LifecycleState lifecycle = LifecycleState.active,
}) => TransactionCategory(
  id: id,
  name: name,
  kind: CategoryKind.expense,
  colorHex: '#888888',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'tag',
  lifecycle: lifecycle,
);

Entry entry({
  required String sourceID,
  String? destinationID,
  String? categoryID,
}) => Entry(
  amount: Decimal.fromInt(-10),
  name: 'e',
  sourceID: sourceID,
  destinationID: destinationID,
  categoryID: categoryID,
);

void main() {
  test('a ledger built with no arguments is empty', () {
    final ledger = LedgerState();
    expect(ledger.moneySources, isEmpty);
    expect(ledger.entries, isEmpty);
    expect(ledger.categories, isEmpty);
  });

  group('active and binned sets', () {
    // The pocket reaches referenceOnly by surviving a purge of its own parent
    // while an entry still names it; accountB stays merely archived, so the
    // binned sets have something to hold.
    final ledger = LedgerState();
    ledger.addAccount(account(accountA));
    ledger.addAccount(account(accountB));
    ledger.addAccount(account(ghostID, name: 'pocket parent'));
    ledger.addPocket(pocket(pocketP), ghostID);
    ledger.addEntry(entry(sourceID: pocketP));
    ledger.addCategory(category(categoryC));
    ledger.addCategory(category(categoryD));
    ledger.deleteAccount(ghostID);
    ledger.purgeAccount(ghostID);
    ledger.deleteAccount(accountB);
    ledger.deleteCategory(categoryD);

    test('active sets hold only active ids', () {
      expect(ledger.activeSources, {accountA});
      expect(ledger.activeCategories, {categoryC});
    });

    test('binned sets hold only archived ids', () {
      expect(ledger.binnedSources, {accountB});
      expect(ledger.binnedCategories, {categoryD});
    });
  });

  group('activeAccounts', () {
    test('name-sorted ascending, archived absent, pockets absent', () {
      final ledger = LedgerState();
      ledger.addAccount(account(accountA, name: 'zulu'));
      ledger.addAccount(account(accountB, name: 'alpha'));
      ledger.addAccount(account(ghostID, name: 'archived'));
      ledger.addPocket(pocket(pocketP, name: 'aaa'), accountA);
      ledger.deleteAccount(ghostID);

      expect(ledger.activeAccounts.map((a) => a.name), ['alpha', 'zulu']);
    });
  });

  group('activePockets', () {
    test('resolves through the parent links, active only, name-sorted', () {
      final ledger = LedgerState();
      ledger.addAccount(account(accountA));
      ledger.addPocket(pocket(pocketP, name: 'zulu'), accountA);
      ledger.addPocket(pocket(pocketQ, name: 'alpha'), accountA);
      ledger.addPocket(pocket(ghostID, name: 'archived'), accountA);
      ledger.deletePocket(ghostID);

      final parent = ledger.moneySources[accountA]!.asAccount!;
      expect(ledger.activePockets(parent).map((p) => p.name), [
        'alpha',
        'zulu',
      ]);
    });

    test("another account's pockets are excluded", () {
      final ledger = LedgerState();
      ledger.addAccount(account(accountA));
      ledger.addAccount(account(accountB));
      ledger.addPocket(pocket(pocketP, name: 'mine'), accountA);
      ledger.addPocket(pocket(pocketQ, name: 'theirs'), accountB);

      final owner = ledger.moneySources[accountA]!.asAccount!;
      expect(ledger.activePockets(owner).map((p) => p.name), ['mine']);
    });
  });

  group('sourceName', () {
    test('an account yields its own name', () {
      final ledger = LedgerState();
      ledger.addAccount(account(accountA, name: 'Bank'));

      expect(ledger.sourceName(accountA), 'Bank');
    });

    test('an owned pocket is parent-qualified', () {
      final ledger = LedgerState();
      ledger.addAccount(account(accountA, name: 'Bank'));
      ledger.addPocket(pocket(pocketP, name: 'Rent'), accountA);

      expect(ledger.sourceName(pocketP), 'Bank/Rent');
    });

    test('a null or unknown id yields null', () {
      final ledger = LedgerState();
      ledger.addAccount(account(accountA));

      expect(ledger.sourceName(null), isNull);
      expect(ledger.sourceName(ghostID), isNull);
    });

    test('an archived holder still resolves its name', () {
      final ledger = LedgerState();
      ledger.addAccount(account(accountA, name: 'Bank'));
      ledger.deleteAccount(accountA);

      expect(ledger.sourceName(accountA), 'Bank');
    });
  });

  group('reference counts', () {
    final ledger = LedgerState();
    ledger.addAccount(account(accountA));
    ledger.addAccount(account(accountB));
    ledger.addPocket(pocket(pocketP), accountB);
    ledger.addCategory(category(categoryC));
    ledger.addCategory(category(categoryD));
    ledger.addEntry(entry(sourceID: accountA, categoryID: categoryC));
    ledger.addEntry(entry(sourceID: accountB, destinationID: accountA));
    ledger.addEntry(entry(sourceID: pocketP, categoryID: categoryD));

    test('entriesReferencing spans source and destination', () {
      expect(ledger.entriesReferencing(accountA), 2);
      expect(ledger.entriesReferencing(pocketP), 1);
      expect(ledger.entriesReferencing(ghostID), 0);
    });

    test('entryCount counts an entry touching two ids in the set once', () {
      expect(ledger.entryCount({accountA, accountB}), 2);
      expect(ledger.entryCount({accountA}), 2);
      expect(ledger.entryCount({}), 0);
    });

    test('entryCountReferencing counts entries carrying the category', () {
      expect(ledger.entryCountReferencing(categoryC), 1);
      expect(ledger.entryCountReferencing(ghostID), 0);
    });
  });
}
