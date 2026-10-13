import 'package:domain/domain.dart';

// MARK: - Constants
const _accountTypeLabels = <AccountType, String>{
  AccountType.cash: 'Cash',
  AccountType.checking: 'Checking',
  AccountType.savings: 'Savings',
  AccountType.card: 'Card',
  AccountType.prepaid: 'Prepaid',
  AccountType.investment: 'Investment',
  AccountType.insurance: 'Insurance',
  AccountType.other: 'Other',
  AccountType.loan: 'Loan',
  AccountType.overdraft: 'Overdraft',
};

// MARK: - Helpers
String accountTypeLabel(AccountType type) => _accountTypeLabels[type]!;
