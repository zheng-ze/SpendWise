enum BudgetHost { money, stats }

typedef HostedBudget = ({BudgetHost host, String budgetID});

class BudgetDraftKey {
  BudgetDraftKey();
}
