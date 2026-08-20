import 'package:domain/src/account_type.dart';

/// The prefix is not uuid-shaped, so this never collides with a real category
/// id. Derived at call time and never persisted, so every device agrees.
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

/// Safe to call with a real category id too. It only ever returns non-null
/// for one of this scheme's own ids.
AccountType? syntheticTransferExpenseAccountType(String bucketID) {
  if (!bucketID.startsWith(_prefix)) return null;

  final name = bucketID.substring(_prefix.length);
  for (final type in AccountType.values) {
    if (type.name == name && type.allowsTransfersAsExpense) return type;
  }
  return null;
}
