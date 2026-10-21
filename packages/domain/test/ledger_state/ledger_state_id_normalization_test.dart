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
