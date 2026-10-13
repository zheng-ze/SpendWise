import 'package:domain/domain.dart';

// MARK: - Steps

sealed class BudgetsStep {}

// MARK: - Navigation Steps

class BudgetLimitEditRequested extends BudgetsStep {}

class BudgetDetailRequested extends BudgetsStep {
  BudgetDetailRequested(this.budgetID);

  final String budgetID;
}

class BudgetFormRequested extends BudgetsStep {}

// MARK: - Picker Steps

class PickLimitRequested extends BudgetsStep {
  PickLimitRequested(this.target);

  final LimitEditTarget target;
}

class PickCategoryRequested extends BudgetsStep {}

class BudgetFormSaved extends BudgetsStep {}

// MARK: - Limit Targets

sealed class LimitEditTarget {}

class DefaultLimitTarget extends LimitEditTarget {
  DefaultLimitTarget(this.current, this.effectiveFromMonth);

  final Decimal current;
  final YearMonth effectiveFromMonth;
}

class MonthLimitTarget extends LimitEditTarget {
  MonthLimitTarget(this.month, this.current);

  final YearMonth month;
  final Decimal current;
}
