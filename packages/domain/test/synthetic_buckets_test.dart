import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('syntheticTransferExpenseBucketID', () {
    test('is deterministic for the same type', () {
      final first = syntheticTransferExpenseBucketID(AccountType.savings);
      final second = syntheticTransferExpenseBucketID(AccountType.savings);

      expect(first, second);
    });

    test('differs between two eligible types', () {
      final savings = syntheticTransferExpenseBucketID(AccountType.savings);
      final investment = syntheticTransferExpenseBucketID(
        AccountType.investment,
      );

      expect(savings, isNot(investment));
    });

    test(
      'is not shaped like a uuid, so it cannot collide with a category id',
      () {
        final id = syntheticTransferExpenseBucketID(AccountType.savings);
        final uuidPattern = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        );

        expect(uuidPattern.hasMatch(id), isFalse);
      },
    );

    test('throws for a type that does not allow transfers as expense', () {
      expect(
        () => syntheticTransferExpenseBucketID(AccountType.cash),
        throwsArgumentError,
      );
    });
  });

  group('syntheticTransferExpenseAccountType', () {
    test('recovers the type that produced the id', () {
      final id = syntheticTransferExpenseBucketID(AccountType.savings);

      expect(syntheticTransferExpenseAccountType(id), AccountType.savings);
    });

    test('returns null for a real category id', () {
      expect(
        syntheticTransferExpenseAccountType(
          'a0000000-0000-0000-0000-000000000001',
        ),
        isNull,
      );
    });

    test('returns null for an ineligible type name wearing the prefix', () {
      expect(
        syntheticTransferExpenseAccountType('transfer-expense:cash'),
        isNull,
      );
    });
  });
}
