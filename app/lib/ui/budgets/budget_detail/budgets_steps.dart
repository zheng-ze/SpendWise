// MARK: - Steps

sealed class BudgetsStep {}

// MARK: - Navigation Steps

class BudgetEditRequested extends BudgetsStep {}

class BudgetFormRequested extends BudgetsStep {}

// MARK: - Picker Steps

class PickCategoryRequested extends BudgetsStep {}

class BudgetFormSaved extends BudgetsStep {}

class BudgetLimitSaved extends BudgetsStep {}
