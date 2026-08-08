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

LedgerState stateWith({
  List<MoneySource> sources = const [],
  List<Entry> entries = const [],
  List<TransactionCategory> categories = const [],
}) => LedgerState(
  moneySources: {for (final source in sources) source.id: source},
  entries: {for (final e in entries) e.id: e},
  categories: {for (final c in categories) c.id: c},
);

void main() {
  test('a ledger built with no arguments is empty', () {
    final ledger = LedgerState();
    expect(ledger.moneySources, isEmpty);
    expect(ledger.entries, isEmpty);
    expect(ledger.categories, isEmpty);
  });

  group('active and binned sets', () {
    final ledger = stateWith(
      sources: [
        AccountSource(account(accountA)),
        AccountSource(account(accountB, lifecycle: LifecycleState.archived)),
        PocketSource(pocket(pocketP, lifecycle: LifecycleState.referenceOnly)),
      ],
      categories: [
        category(categoryC),
        category(categoryD, lifecycle: LifecycleState.archived),
      ],
    );

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
      final ledger = stateWith(
        sources: [
          AccountSource(account(accountA, name: 'zulu')),
          AccountSource(account(accountB, name: 'alpha')),
          AccountSource(
            account(
              ghostID,
              name: 'archived',
              lifecycle: LifecycleState.archived,
            ),
          ),
          PocketSource(pocket(pocketP, name: 'aaa')),
        ],
      );
      expect(ledger.activeAccounts.map((a) => a.name), ['alpha', 'zulu']);
    });
  });

  group('activePockets', () {
    test('resolves through the parent links, active only, name-sorted', () {
      final parent = account(
        accountA,
        subPocketIDs: {pocketP, pocketQ, ghostID},
      );
      final ledger = stateWith(
        sources: [
          AccountSource(parent),
          PocketSource(pocket(pocketP, name: 'zulu')),
          PocketSource(pocket(pocketQ, name: 'alpha')),
          PocketSource(
            pocket(
              ghostID,
              name: 'archived',
              lifecycle: LifecycleState.archived,
            ),
          ),
        ],
      );
      expect(ledger.activePockets(parent).map((p) => p.name), [
        'alpha',
        'zulu',
      ]);
    });

    test("another account's pockets are excluded", () {
      final owner = account(accountA, subPocketIDs: {pocketP});
      final other = account(accountB, subPocketIDs: {pocketQ});
      final ledger = stateWith(
        sources: [
          AccountSource(owner),
          AccountSource(other),
          PocketSource(pocket(pocketP, name: 'mine')),
          PocketSource(pocket(pocketQ, name: 'theirs')),
        ],
      );
      expect(ledger.activePockets(owner).map((p) => p.name), ['mine']);
    });
  });

  group('sourceName', () {
    test('an account yields its own name', () {
      final ledger = stateWith(
        sources: [AccountSource(account(accountA, name: 'Bank'))],
      );
      expect(ledger.sourceName(accountA), 'Bank');
    });

    test('an owned pocket is parent-qualified', () {
      final ledger = stateWith(
        sources: [
          AccountSource(
            account(accountA, name: 'Bank', subPocketIDs: {pocketP}),
          ),
          PocketSource(pocket(pocketP, name: 'Rent')),
        ],
      );
      expect(ledger.sourceName(pocketP), 'Bank/Rent');
    });

    test('an unowned pocket yields its bare name', () {
      final ledger = stateWith(
        sources: [PocketSource(pocket(pocketP, name: 'Rent'))],
      );
      expect(ledger.sourceName(pocketP), 'Rent');
    });

    test('a null or unknown id yields null', () {
      final ledger = stateWith(sources: [AccountSource(account(accountA))]);
      expect(ledger.sourceName(null), isNull);
      expect(ledger.sourceName(ghostID), isNull);
    });

    test('an archived holder still resolves its name', () {
      final ledger = stateWith(
        sources: [
          AccountSource(
            account(accountA, name: 'Bank', lifecycle: LifecycleState.archived),
          ),
        ],
      );
      expect(ledger.sourceName(accountA), 'Bank');
    });
  });

  group('reference counts', () {
    final ledger = stateWith(
      sources: [
        AccountSource(account(accountA)),
        AccountSource(account(accountB)),
        PocketSource(pocket(pocketP)),
      ],
      entries: [
        entry(sourceID: accountA, categoryID: categoryC),
        entry(sourceID: accountB, destinationID: accountA),
        entry(sourceID: pocketP, categoryID: categoryD),
      ],
      categories: [category(categoryC), category(categoryD)],
    );

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
