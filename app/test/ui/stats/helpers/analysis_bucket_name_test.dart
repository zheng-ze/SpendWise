import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/format/analysis_bucket_name.dart';

const _transferNames = <AccountType, String>{
  AccountType.savings: 'Savings transfers',
  AccountType.investment: 'Investment transfers',
  AccountType.insurance: 'Insurance transfers',
  AccountType.other: 'Other transfers',
  AccountType.loan: 'Loan transfers',
  AccountType.overdraft: 'Overdraft transfers',
};

void main() {
  test('shared bucket names preserve every synthetic transfer name', () {
    for (final entry in _transferNames.entries) {
      final id = syntheticTransferExpenseBucketID(entry.key);
      expect(analysisBucketName(id), entry.value);
    }
  });
  test('absent and unresolved buckets share the Uncategorized label', () {
    expect(uncategorizedName, 'Uncategorized');
    expect(analysisBucketName(null), uncategorizedName);
    expect(
      analysisBucketName('a0000000-0000-0000-0000-000000000001'),
      uncategorizedName,
    );
  });
}
