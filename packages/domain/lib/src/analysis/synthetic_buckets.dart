import 'package:domain/src/accounts/account_type.dart';

String syntheticTransferExpenseBucketID(AccountType type) {
  if (!type.allowsTransfersAsExpense) {
    throw ArgumentError.value(
      type,
      'type',
      'does not allow transfers as expense',
    );
  }
  return 'transfer-expense:${type.name}';
}

const _prefix = 'transfer-expense:';

AccountType? syntheticTransferExpenseAccountType(String bucketID) {
  if (!bucketID.startsWith(_prefix)) return null;

  final name = bucketID.substring(_prefix.length);
  for (final type in AccountType.values) {
    if (type.name == name && type.allowsTransfersAsExpense) return type;
  }
  return null;
}
