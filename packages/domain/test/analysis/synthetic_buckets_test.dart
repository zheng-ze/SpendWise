import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('syntheticTransferExpenseBucketID', () {
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
