import 'package:domain/domain.dart';

const uncategorizedName = 'Uncategorized';

const _syntheticTransferNames = <AccountType, String>{
  AccountType.savings: 'Savings transfers',
  AccountType.investment: 'Investment transfers',
  AccountType.insurance: 'Insurance transfers',
  AccountType.other: 'Other transfers',
  AccountType.loan: 'Loan transfers',
  AccountType.overdraft: 'Overdraft transfers',
};

String analysisBucketName(String? bucketID) {
  if (bucketID == null) return uncategorizedName;
  final type = syntheticTransferExpenseAccountType(bucketID);
  return _syntheticTransferNames[type] ?? uncategorizedName;
}
