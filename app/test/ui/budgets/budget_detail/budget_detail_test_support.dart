import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';

const detailBudgetID = 'b1';

Decimal dec(String value) => Decimal.parse(value);

final checkingAccount = Account(
  id: 'a0000000-0000-0000-0000-000000000010',
  name: 'Checking',
  type: AccountType.checking,
);

final savingsAccount = Account(
  id: 'a0000000-0000-0000-0000-000000000011',
  name: 'Savings',
  type: AccountType.savings,
  incomingTransfersAsExpenses: true,
);

final foodCategory = TransactionCategory(
  id: 'c0000000-0000-0000-0000-000000000001',
  name: 'Food',
  kind: CategoryKind.expense,
  colorHex: '#00AA00',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'restaurant',
);

Budget detailBudget({
  String id = detailBudgetID,
  String? categoryID,
  List<LimitEvent>? limitEvents,
}) {
  return Budget(
    id: id,
    categoryID: categoryID,
    limitEvents:
        limitEvents ??
        [
          LimitEvent(
            effectiveFromMonth: null,
            value: dec('100'),
            kind: LimitEventKind.defaultLimit,
          ),
        ],
    createdAtMonth: const YearMonth(2026, 1),
  );
}

Ledger detailLedger({
  List<Budget> budgets = const [],
  List<Entry> entries = const [],
}) {
  return Ledger(
    state: LedgerState(
      moneySources: {
        checkingAccount.id: MoneySource.account(checkingAccount),
        savingsAccount.id: MoneySource.account(savingsAccount),
      },
      categories: {foodCategory.id: foodCategory},
      entries: {for (final entry in entries) entry.id: entry},
      budgets: {for (final budget in budgets) budget.id: budget},
    ),
  );
}

// MARK: - Clock

class DetailClock {
  DetailClock(this.now);

  DateTime now;

  DateTime read() => now;
}

ProviderContainer detailContainer({
  required Ledger ledger,
  required DetailClock clock,
  ComputeRunner? runner,
}) {
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWithValue(ledger),
      clockProvider.overrideWithValue(clock.read),
      analysisComputeRunnerProvider.overrideWithValue(
        runner ?? syncComputeRunner,
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

// MARK: - Reads

ProviderSubscription<AsyncValue<BudgetDetailViewState>> keepDetailAlive(
  ProviderContainer container, {
  String budgetID = detailBudgetID,
}) {
  return container.listen(budgetDetailViewModelProvider(budgetID), (_, _) {});
}

BudgetDetailViewState detailState(
  ProviderContainer container, {
  String budgetID = detailBudgetID,
}) {
  return container.read(budgetDetailViewModelProvider(budgetID)).requireValue;
}

BudgetDetailContext detailContext(
  ProviderContainer container, {
  String budgetID = detailBudgetID,
}) {
  return container.read(budgetDetailContextProvider(budgetID));
}

Future<BudgetDetailViewState> settledDetail(
  ProviderContainer container, {
  String budgetID = detailBudgetID,
}) async {
  await pumpEventQueue();
  return detailState(container, budgetID: budgetID);
}
