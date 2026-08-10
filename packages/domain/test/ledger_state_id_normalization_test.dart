import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

void main() {
  late LedgerState ledger;

  String upper(int n) => uuid(n).toUpperCase();

  setUp(() {
    ledger = LedgerState();
    ledger.addAccount(account(uuid(1)));
  });

  group('mutators canonicalize a bare id', () {
    test('deleteAccount archives rather than silently no-opping', () {
      final changes = ledger.deleteAccount(upper(1));

      expect(changes, [
        UpsertAccount(account(uuid(1), lifecycle: LifecycleState.archived)),
      ]);
      expect(ledger.moneySources[uuid(1)]?.lifecycle, LifecycleState.archived);
    });

    test('restoreAccount restores rather than silently no-opping', () {
      ledger.deleteAccount(uuid(1));
      final changes = ledger.restoreAccount(upper(1));

      expect(changes, [UpsertAccount(account(uuid(1)))]);
      expect(ledger.moneySources[uuid(1)]?.lifecycle, LifecycleState.active);
    });

    test('addPocket resolves an uppercase parent id', () {
      final changes = ledger.addPocket(pocket(uuid(2)), upper(1));

      expect(changes, [
        UpsertPocket(pocket(uuid(2))),
        UpsertAccount(account(uuid(1), subPocketIDs: {uuid(2)})),
      ]);
    });

    test('deletePocket and restorePocket resolve an uppercase id', () {
      ledger.addPocket(pocket(uuid(2)), uuid(1));

      expect(ledger.deletePocket(upper(2)), [
        UpsertPocket(pocket(uuid(2), lifecycle: LifecycleState.archived)),
      ]);
      expect(ledger.restorePocket(upper(2)), [UpsertPocket(pocket(uuid(2)))]);
    });

    test('setOpeningBalance resolves an uppercase holder id', () {
      final changes = ledger.setOpeningBalance(Decimal.fromInt(250), upper(1));

      expect(changes, hasLength(1));
      expect(ledger.entries.values.single.sourceID, uuid(1));
    });

    test('deleteEntry resolves an uppercase id', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1)));
      final changes = ledger.deleteEntry(upper(4));

      expect(changes, [DeleteEntry(uuid(4))]);
      expect(ledger.entries, isEmpty);
    });

    test('deleteCategory and restoreCategory resolve an uppercase id', () {
      ledger.addCategory(category(uuid(3)));

      expect(ledger.deleteCategory(upper(3)), [
        UpsertCategory(category(uuid(3), lifecycle: LifecycleState.archived)),
      ]);
      expect(ledger.restoreCategory(upper(3)), [
        UpsertCategory(category(uuid(3))),
      ]);
    });
  });

  group('queries canonicalize a bare id', () {
    test('sourceName resolves an uppercase id', () {
      expect(ledger.sourceName(upper(1)), 'acc');
    });

    test('sourceName still returns null for a null id', () {
      expect(ledger.sourceName(null), isNull);
    });

    test('owningAccount resolves an uppercase pocket id', () {
      ledger.addPocket(pocket(uuid(2)), uuid(1));

      expect(ledger.owningAccount(upper(2))?.id, uuid(1));
    });

    test('entriesReferencing resolves an uppercase id', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1)));

      expect(ledger.entriesReferencing(upper(1)), 1);
    });

    test('entryCount resolves uppercase ids', () {
      ledger.addEntry(entry(id: uuid(4), sourceID: uuid(1)));

      expect(ledger.entryCount({upper(1)}), 1);
    });

    test('entryCountReferencing resolves an uppercase category id', () {
      ledger.addCategory(category(uuid(3)));
      ledger.addEntry(
        entry(id: uuid(4), sourceID: uuid(1), categoryID: uuid(3)),
      );

      expect(ledger.entryCountReferencing(upper(3)), 1);
    });
  });
}
