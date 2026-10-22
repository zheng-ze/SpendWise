import 'package:domain/domain.dart';
import 'package:test/test.dart';

import '../support/builders.dart';

void main() {
  late LedgerState ledger;

  String hex(int n) =>
      '6f1a2b3c-4d5e-6f70-8192-a3b4c5d6e7f${n.toRadixString(16)}';
  String upper(int n) => hex(n).toUpperCase();

  setUp(() {
    ledger = LedgerState();
    ledger.addAccount(account(hex(1)));
  });

  group('mutators normalize a bare id', () {
    test('deleteAccount archives rather than silently no-opping', () {
      final changes = ledger.deleteAccount(upper(1));

      expect(changes, [
        UpsertAccount(account(hex(1), lifecycle: LifecycleState.archived)),
      ]);
      expect(ledger.moneySources[hex(1)]?.lifecycle, LifecycleState.archived);
    });

    test('restoreAccount restores rather than silently no-opping', () {
      ledger.deleteAccount(hex(1));
      final changes = ledger.restoreAccount(upper(1));

      expect(changes, [UpsertAccount(account(hex(1)))]);
      expect(ledger.moneySources[hex(1)]?.lifecycle, LifecycleState.active);
    });

    test('addPocket resolves an uppercase parent id', () {
      final changes = ledger.addPocket(pocket(hex(2)), upper(1));

      expect(changes, [
        UpsertPocket(pocket(hex(2))),
        UpsertAccount(account(hex(1), subPocketIDs: {hex(2)})),
      ]);
    });

    test('deletePocket and restorePocket resolve an uppercase id', () {
      ledger.addPocket(pocket(hex(2)), hex(1));

      expect(ledger.deletePocket(upper(2)), [
        UpsertPocket(pocket(hex(2), lifecycle: LifecycleState.archived)),
      ]);
      expect(ledger.restorePocket(upper(2)), [UpsertPocket(pocket(hex(2)))]);
    });

    test('setOpeningBalance resolves an uppercase holder id', () {
      final changes = ledger.setOpeningBalance(Decimal.fromInt(250), upper(1));

      expect(changes, hasLength(1));
      expect(ledger.entries.values.single.sourceID, hex(1));
    });

    test('deleteEntry resolves an uppercase id', () {
      ledger.addEntry(entry(id: hex(4), sourceID: hex(1)));
      final changes = ledger.deleteEntry(upper(4));

      expect(changes, [DeleteEntry(hex(4))]);
      expect(ledger.entries, isEmpty);
    });

    test('deleteCategory and restoreCategory resolve an uppercase id', () {
      ledger.addCategory(category(hex(3)));

      expect(ledger.deleteCategory(upper(3)), [
        UpsertCategory(category(hex(3), lifecycle: LifecycleState.archived)),
      ]);
      expect(ledger.restoreCategory(upper(3)), [
        UpsertCategory(category(hex(3))),
      ]);
    });
  });

  group('queries normalize a bare id', () {
    test('sourceName resolves an uppercase id', () {
      expect(ledger.sourceName(upper(1)), 'acc');
    });

    test('sourceName still returns null for a null id', () {
      expect(ledger.sourceName(null), isNull);
    });

    test('owningAccount resolves an uppercase pocket id', () {
      ledger.addPocket(pocket(hex(2)), hex(1));

      expect(ledger.owningAccount(upper(2))?.id, hex(1));
    });

    test('entriesReferencing resolves an uppercase id', () {
      ledger.addEntry(entry(id: hex(4), sourceID: hex(1)));

      expect(ledger.entriesReferencing(upper(1)), 1);
    });

    test('entryCount resolves uppercase ids', () {
      ledger.addEntry(entry(id: hex(4), sourceID: hex(1)));

      expect(ledger.entryCount({upper(1)}), 1);
    });

    test('entryCountReferencing resolves an uppercase category id', () {
      ledger.addCategory(category(hex(3)));
      ledger.addEntry(entry(id: hex(4), sourceID: hex(1), categoryID: hex(3)));

      expect(ledger.entryCountReferencing(upper(3)), 1);
    });
  });
}
