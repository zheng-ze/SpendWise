import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';

const checkingID = '11111111-1111-4111-8111-111111111111';
const savingsID = '22222222-2222-4222-8222-222222222222';
const cardID = '33333333-3333-4333-8333-333333333333';
const groceriesID = '44444444-4444-4444-8444-444444444444';
const salaryID = '55555555-5555-4555-8555-555555555555';

final fixtureToday = DateTime.utc(2026, 10, 3);

String entryID(int n) =>
    'e0000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

LedgerState emptyState() {
  final state = LedgerState();
  state.addAccount(
    Account(id: checkingID, name: 'Checking', type: AccountType.checking),
  );
  state.addAccount(
    Account(id: savingsID, name: 'Savings', type: AccountType.savings),
  );
  state.addAccount(
    Account(
      id: cardID,
      name: 'Amex Card',
      type: AccountType.card,
      statementDay: 15,
    ),
  );
  state.addCategory(
    TransactionCategory(
      id: groceriesID,
      name: 'Groceries',
      kind: CategoryKind.expense,
      colorHex: '#29755E',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    ),
  );
  state.addCategory(
    TransactionCategory(
      id: salaryID,
      name: 'Salary',
      kind: CategoryKind.income,
      colorHex: '#28684F',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    ),
  );
  return state;
}

Entry entry(
  int n,
  String amount,
  DateTime date, {
  String name = '',
  String sourceID = checkingID,
  String? destinationID,
  String? categoryID,
}) => Entry(
  id: entryID(n),
  amount: Decimal.parse(amount),
  name: name,
  sourceID: sourceID,
  destinationID: destinationID,
  categoryID: categoryID,
  date: date,
);

RecurringPlan monthlyPlan(String name, String amount, DateTime anchor) =>
    RecurringPlan(
      template: EntryTemplate(
        amount: Decimal.parse(amount),
        name: name,
        categoryID: Decimal.parse(amount) < Decimal.zero
            ? groceriesID
            : salaryID,
        sourceID: Decimal.parse(amount) < Decimal.zero ? cardID : checkingID,
      ),
      frequency: RecurrenceFrequency.monthly,
      anchor: anchor,
      lastResolvedDate: DateTime.utc(2026, 10, 1),
    );

LedgerState defaultState() {
  final state = emptyState();
  state.addBudget(null, Decimal.parse('1200'), now: DateTime.utc(2026, 10, 1));
  state.addEntry(
    entry(
      1,
      '3200.00',
      DateTime.utc(2026, 10, 3),
      name: 'Monthly pay',
      categoryID: salaryID,
    ),
  );
  state.addEntry(
    entry(
      2,
      '500.00',
      DateTime.utc(2026, 10, 3),
      name: 'To savings',
      destinationID: savingsID,
    ),
  );
  state.addEntry(
    entry(
      3,
      '-42.50',
      DateTime.utc(2026, 10, 3),
      name: 'Shop run',
      sourceID: cardID,
      categoryID: groceriesID,
    ),
  );
  state.addEntry(
    entry(
      4,
      '-3.20',
      DateTime.utc(2026, 10, 3),
      name: 'Snack',
      sourceID: cardID,
      categoryID: groceriesID,
    ),
  );
  state.addEntry(
    entry(
      5,
      '-8.00',
      DateTime.utc(2026, 10, 2),
      name: 'Yesterday bite',
      categoryID: groceriesID,
    ),
  );
  state.addEntry(
    entry(
      6,
      '-1200.00',
      DateTime.utc(2026, 11, 3),
      name: 'Rent',
      categoryID: groceriesID,
    ),
  );
  state.addPlan(monthlyPlan('Streaming', '-19.98', DateTime.utc(2026, 10, 20)));
  state.addPlan(monthlyPlan('Wages', '3200.00', DateTime.utc(2026, 10, 25)));
  return state;
}

Future<void> settleAnalysis(ProviderContainer container, Ledger ledger) async {
  final cache = container.read(ledgerSessionProvider)!.analysisCache;
  for (var i = 0; i < 50 && cache.itemsSourceRevision != ledger.revision; i++) {
    await pumpEventQueue();
  }
  await pumpEventQueue();
}

ProviderContainer overviewContainer(
  Ledger ledger, {
  ComputeRunner runner = syncComputeRunner,
}) {
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWithValue(ledger),
      analysisComputeRunnerProvider.overrideWithValue(runner),
      clockProvider.overrideWithValue(() => fixtureToday),
    ],
  );
  addTearDown(container.dispose);
  return container;
}
