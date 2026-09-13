import 'package:domain/domain.dart';

/// Stable UUID strings used by the sync engine and codec tests.
const uuidAccounts = 'aaaaaaaa-0000-1111-2222-333333333333';
const uuidPockets = 'bbbbbbbb-0000-1111-2222-444444444444';
const uuidCategories = 'cccccccc-0000-1111-2222-555555555555';
const uuidParent = 'dddddddd-0000-1111-2222-666666666666';
const uuidEntries = 'eeeeeeee-0000-1111-2222-777777777777';
const uuidPlans = 'ffffffff-0000-1111-2222-888888888888';
const uuidBudgets = '12345678-0000-1111-2222-999999999999';

final anchorDate = DateTime.utc(2024, 1, 1);
final endDate = DateTime.utc(2024, 12, 31);
final resolvedDate = DateTime.utc(2024, 6, 1);

Account testAccount({String? id, int? statementDay}) => Account(
      id: id ?? uuidAccounts,
      name: 'Checking',
      type: AccountType.checking,
      subPocketIDs: const {},
      incomingTransfersAsExpenses: false,
      includeInNetWorth: true,
      statementDay: statementDay,
    );

SubPocket testSubPocket({String? id}) => SubPocket(
      id: id ?? uuidPockets,
      name: 'Travel',
      incomingTransfersAsExpenses: false,
    );

TransactionCategory testCategory({String? id, String? parentID}) =>
    TransactionCategory(
      id: id ?? uuidCategories,
      name: 'Groceries',
      kind: CategoryKind.expense,
      colorHex: '#44AA55',
      includeInAnalysis: true,
      parentID: parentID ?? uuidParent,
      symbol: 'food',
    );

Entry testEntry({String? id, DateTime? date}) => Entry(
      id: id ?? uuidEntries,
      date: date ?? DateTime.utc(2024, 3, 15),
      amount: Decimal.parse('-12.50'),
      name: 'Coffee',
      categoryID: uuidCategories,
      sourceID: uuidAccounts,
      destinationID: null,
      includeInAnalysis: true,
    );

EntryTemplate testTemplate() => EntryTemplate(
      amount: Decimal.parse('50.00'),
      name: 'Rent',
      categoryID: null,
      sourceID: uuidAccounts,
      destinationID: null,
      includeInAnalysis: true,
    );

RecurringPlan testPlan({DateTime? end}) => RecurringPlan(
      id: uuidPlans,
      template: testTemplate(),
      frequency: RecurrenceFrequency.monthly,
      anchor: anchorDate,
      endDate: end ?? endDate,
      lastResolvedDate: resolvedDate,
    );

Budget testBudget({String? id}) => Budget(
      id: id ?? uuidBudgets,
      categoryID: uuidCategories,
      limitEvents: <LimitEvent>[
        LimitEvent(
          effectiveFromMonth: const YearMonth(2024, 1),
          value: Decimal.parse('100.00'),
          kind: LimitEventKind.defaultLimit,
        ),
        LimitEvent(
          effectiveFromMonth: null,
          value: Decimal.parse('250.00'),
          kind: LimitEventKind.override,
        ),
      ],
      createdAtMonth: const YearMonth(2024, 1),
    );

/// Every upsert [LedgerChange] the codec must round-trip, keyed by label.
Map<String, LedgerChange> allUpserts() => <String, LedgerChange>{
      'account': UpsertAccount(testAccount()),
      'account_statement_day': UpsertAccount(
        testAccount(statementDay: 20),
      ),
      'sub_pocket': UpsertPocket(testSubPocket()),
      'category': UpsertCategory(testCategory()),
      'entry': UpsertEntry(testEntry()),
      'plan': UpsertPlan(testPlan()),
      'budget': UpsertBudget(testBudget()),
    };
