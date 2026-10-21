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

    test('id-taking mutators resolve uppercase ids', () {
      late LedgerState state;
      LedgerState freshLedger() {
        final fresh = LedgerState();
        fresh.addAccount(account(hex(1)));
        return fresh;
      }

      final cases = <({void Function() verify})>[
        (
          verify: () {
            final changes = state.addPocket(pocket(hex(2)), upper(1));

            expect(changes, [
              UpsertPocket(pocket(hex(2))),
              UpsertAccount(account(hex(1), subPocketIDs: {hex(2)})),
            ]);
          },
        ),
        (
          verify: () {
            state.addPocket(pocket(hex(2)), hex(1));

            expect(state.deletePocket(upper(2)), [
              UpsertPocket(pocket(hex(2), lifecycle: LifecycleState.archived)),
            ]);
            expect(state.restorePocket(upper(2)), [
              UpsertPocket(pocket(hex(2))),
            ]);
          },
        ),
        (
          verify: () {
            final changes = state.setOpeningBalance(
              Decimal.fromInt(250),
              upper(1),
            );

            expect(changes, hasLength(1));
            expect(state.entries.values.single.sourceID, hex(1));
          },
        ),
        (
          verify: () {
            state.addEntry(entry(id: hex(4), sourceID: hex(1)));
            final changes = state.deleteEntry(upper(4));

            expect(changes, [DeleteEntry(hex(4))]);
            expect(state.entries, isEmpty);
          },
        ),
        (
          verify: () {
            state.addCategory(category(hex(3)));

            expect(state.deleteCategory(upper(3)), [
              UpsertCategory(
                category(hex(3), lifecycle: LifecycleState.archived),
              ),
            ]);
            expect(state.restoreCategory(upper(3)), [
              UpsertCategory(category(hex(3))),
            ]);
          },
        ),
        (
          verify: () {
            state.deleteAccount(hex(1));
            final changes = state.restoreAccount(upper(1));

            expect(changes, [UpsertAccount(account(hex(1)))]);
            expect(
              state.moneySources[hex(1)]?.lifecycle,
              LifecycleState.active,
            );
          },
        ),
      ];

      for (final testCase in cases) {
        state = freshLedger();
        testCase.verify();
      }

      final queryCases = <({void Function() verify})>[
        (verify: () => expect(state.sourceName(upper(1)), 'acc')),
        (
          verify: () {
            state.addEntry(entry(id: hex(4), sourceID: hex(1)));

            expect(state.entriesReferencing(upper(1)), 1);
          },
        ),
        (
          verify: () {
            state.addEntry(entry(id: hex(4), sourceID: hex(1)));

            expect(state.entryCount({upper(1)}), 1);
          },
        ),
        (
          verify: () {
            state.addCategory(category(hex(3)));
            state.addEntry(
              entry(id: hex(4), sourceID: hex(1), categoryID: hex(3)),
            );

            expect(state.entryCountReferencing(upper(3)), 1);
          },
        ),
      ];

      for (final testCase in queryCases) {
        state = LedgerState();
        state.addAccount(account(hex(1)));
        testCase.verify();
      }
    });
  });

  group('queries normalize a bare id', () {
    test('sourceName still returns null for a null id', () {
      expect(ledger.sourceName(null), isNull);
    });

    test('owningAccount resolves an uppercase pocket id', () {
      ledger.addPocket(pocket(hex(2)), hex(1));

      expect(ledger.owningAccount(upper(2))?.id, hex(1));
    });
  });
}
