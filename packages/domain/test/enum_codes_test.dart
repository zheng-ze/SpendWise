import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('LifecycleState', () {
    test('codes never change, persistence writes them', () {
      const table = {
        0: LifecycleState.active,
        1: LifecycleState.archived,
        2: LifecycleState.referenceOnly,
        3: LifecycleState.tombstoned,
      };
      table.forEach((code, state) {
        expect(state.code, code);
        expect(LifecycleState.fromCode(code), state);
      });
    });

    test('fromCode rejects an unknown code', () {
      expect(() => LifecycleState.fromCode(-1), throwsArgumentError);
    });

    test('isActive is true only for active', () {
      for (final state in LifecycleState.values) {
        expect(state.isActive, state == LifecycleState.active);
      }
    });
  });

  group('AccountType', () {
    test('codes never change, persistence writes them', () {
      const table = {
        0: AccountType.cash,
        1: AccountType.checking,
        2: AccountType.savings,
        3: AccountType.card,
        4: AccountType.prepaid,
        5: AccountType.investment,
        6: AccountType.insurance,
        7: AccountType.other,
      };
      table.forEach((code, type) {
        expect(type.code, code);
        expect(AccountType.fromCode(code), type);
      });
    });

    test('fromCode rejects an unknown code', () {
      expect(() => AccountType.fromCode(-1), throwsArgumentError);
    });
  });

  group('CategoryKind', () {
    test('codes never change, persistence writes them', () {
      const table = {0: CategoryKind.income, 1: CategoryKind.expense};
      table.forEach((code, kind) {
        expect(kind.code, code);
        expect(CategoryKind.fromCode(code), kind);
      });
    });

    test('fromCode rejects an unknown code', () {
      expect(() => CategoryKind.fromCode(-1), throwsArgumentError);
    });
  });
}
