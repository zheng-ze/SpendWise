import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/upcoming.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

const _checkingID = '11111111-1111-1111-1111-111111111111';
const _savingsID = '22222222-2222-2222-2222-222222222222';
const _cardID = '55555555-5555-5555-5555-555555555555';
const _foodID = '33333333-3333-3333-3333-333333333333';
const _payID = '44444444-4444-4444-4444-444444444444';
const _hiddenID = '66666666-6666-6666-6666-666666666666';
const _diningID = '77777777-7777-7777-7777-777777777777';
const _ramenID = '88888888-8888-8888-8888-888888888888';

final _today = DateTime.utc(2027, 4, 7);

DateRange _april() =>
    DateRange(DateTime.utc(2027, 4, 1), DateTime.utc(2027, 5, 1));

LedgerState _baseState() {
  final state = LedgerState();
  state.addAccount(
    Account(id: _checkingID, name: 'Checking', type: AccountType.checking),
  );
  state.addAccount(
    Account(id: _savingsID, name: 'Savings', type: AccountType.savings),
  );
  state.addCategory(
    TransactionCategory(
      id: _foodID,
      name: 'Food',
      kind: CategoryKind.expense,
      colorHex: '#000000',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    ),
  );
  state.addCategory(
    TransactionCategory(
      id: _payID,
      name: 'Pay',
      kind: CategoryKind.income,
      colorHex: '#000000',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    ),
  );
  return state;
}

void _expense(
  LedgerState state,
  String id,
  String amount,
  DateTime date, {
  String? categoryID,
  String sourceID = _checkingID,
  bool includeInAnalysis = true,
  String name = 'expense',
}) {
  state.addEntry(
    Entry(
      id: id,
      amount: Decimal.parse(amount),
      name: name,
      sourceID: sourceID,
      categoryID: categoryID ?? _foodID,
      date: date,
      includeInAnalysis: includeInAnalysis,
    ),
  );
}

void _periodEntries(LedgerState state) {
  _expense(
    state,
    'a0000000-0000-0000-0000-000000000001',
    '-25.25',
    DateTime.utc(2027, 4, 1),
  );
  _expense(
    state,
    'a0000000-0000-0000-0000-000000000002',
    '-9.75',
    DateTime.utc(2027, 4, 4),
  );
  _expense(
    state,
    'a0000000-0000-0000-0000-000000000003',
    '-7.00',
    DateTime.utc(2027, 4, 5),
  );
  _expense(
    state,
    'a0000000-0000-0000-0000-000000000004',
    '-13.50',
    DateTime.utc(2027, 4, 7),
  );
  state.addEntry(
    Entry(
      id: 'a0000000-0000-0000-0000-000000000005',
      amount: Decimal.parse('70.00'),
      name: 'pay',
      sourceID: _checkingID,
      categoryID: _payID,
      date: DateTime.utc(2027, 4, 7),
    ),
  );
  state.addEntry(
    Entry(
      id: 'a0000000-0000-0000-0000-000000000006',
      amount: Decimal.parse('22.00'),
      name: 'save',
      sourceID: _checkingID,
      destinationID: _savingsID,
      date: DateTime.utc(2027, 4, 7),
    ),
  );
  _expense(
    state,
    'a0000000-0000-0000-0000-000000000007',
    '-3.00',
    DateTime.utc(2027, 4, 10),
  );
}

void _addPlan(
  LedgerState state, {
  required String id,
  required DateTime anchor,
  required DateTime lastResolvedDate,
  DateTime? endDate,
  RecurrenceFrequency frequency = RecurrenceFrequency.weekly,
  String sourceID = _checkingID,
  String amount = '-19.98',
  String name = 'plan',
}) {
  state.addPlan(
    RecurringPlan(
      id: id,
      template: EntryTemplate(
        amount: Decimal.parse(amount),
        name: name,
        categoryID: _foodID,
        sourceID: sourceID,
      ),
      frequency: frequency,
      anchor: anchor,
      endDate: endDate,
      lastResolvedDate: lastResolvedDate,
    ),
  );
}

void _addCard(LedgerState state, {int? statementDay = 10}) {
  state.addAccount(
    Account(
      id: _cardID,
      name: 'Card',
      type: AccountType.card,
      statementDay: statementDay,
    ),
  );
}

({Ledger ledger, AnalysisCache cache, AnalysisQueries queries}) _ready(
  LedgerState state, {
  DateTime? today,
}) {
  final ledger = Ledger(state: state);
  final cache = AnalysisCache(runner: syncComputeRunner)
    ..start(ledger.bus, sourceRevision: () => ledger.revision);
  final queries = AnalysisQueries(
    ledger: ledger,
    cache: cache,
    today: today ?? _today,
  );
  addTearDown(() async {
    queries.dispose();
    await cache.dispose();
  });
  return (ledger: ledger, cache: cache, queries: queries);
}

Future<void> _accept(AnalysisCache cache, Ledger ledger) async {
  for (var i = 0; i < 50 && cache.itemsSourceRevision != ledger.revision; i++) {
    await pumpEventQueue();
  }
}

class _ManualRunner {
  final List<Completer<List<AnalysisItem>>> pending = [];

  int calls = 0;

  Future<List<AnalysisItem>> call(LedgerState state) {
    calls++;
    final completer = Completer<List<AnalysisItem>>();
    pending.add(completer);
    return completer.future;
  }
}

void main() {
  test('registerTotalsMatchPeriodFixtureAndHistoryEqualsSelectedDay', () async {
    final state = _baseState();
    _periodEntries(state);
    final setup = _ready(state);
    await _accept(setup.cache, setup.ledger);
    final queries = setup.queries;

    final days = queries.readRegisterDays(window: _april());
    expect(days.state, AnalysisQueryState.ready);
    expect(days.sourceRevision, setup.ledger.revision);
    expect(days.value!.map((day) => day.date), [
      DateTime.utc(2027, 4, 10),
      DateTime.utc(2027, 4, 7),
      DateTime.utc(2027, 4, 5),
      DateTime.utc(2027, 4, 4),
      DateTime.utc(2027, 4, 1),
    ]);

    final seventh = days.value!.firstWhere(
      (day) => day.date == DateTime.utc(2027, 4, 7),
    );
    expect(seventh.income, Decimal.parse('70.00'));
    expect(seventh.expense, Decimal.parse('13.50'));
    expect(seventh.net, Decimal.parse('56.50'));
    expect(seventh.moved, Decimal.parse('22.00'));

    final selected = queries.readRegisterDays(
      window: DateRange(DateTime.utc(2027, 4, 7), DateTime.utc(2027, 4, 8)),
    );
    expect(selected.state, AnalysisQueryState.ready);
    expect(selected.value, hasLength(1));
    expect(selected.value!.single.entries, seventh.entries);
    expect(selected.value!.single.net, seventh.net);

    final empty = queries.readRegisterDays(
      window: DateRange(DateTime.utc(2027, 4, 2), DateTime.utc(2027, 4, 3)),
    );
    expect(empty.state, AnalysisQueryState.ready);
    expect(empty.value, isEmpty);

    final future = queries.readRegisterDays(
      window: DateRange(DateTime.utc(2027, 4, 10), DateTime.utc(2027, 4, 11)),
    );
    expect(future.value, hasLength(1));
    expect(future.value!.single.expense, Decimal.parse('3.00'));

    final scoped = queries.readRegisterDays(
      window: _april(),
      sourceIDs: {_savingsID},
    );
    expect(scoped.value!.map((day) => day.date), [DateTime.utc(2027, 4, 7)]);
    expect(scoped.value!.single.moved, Decimal.parse('22.00'));
    expect(scoped.value!.single.expense, Decimal.zero);
  });

  test('registerPreservesDaySectionsAccounting', () async {
    final state = _baseState();
    _expense(
      state,
      'b0000000-0000-0000-0000-000000000001',
      '-5.00',
      DateTime.utc(2027, 4, 2),
    );
    _expense(
      state,
      'b0000000-0000-0000-0000-000000000002',
      '-10.00',
      DateTime.utc(2027, 4, 2),
      includeInAnalysis: false,
    );
    state.addCategory(
      TransactionCategory(
        id: _hiddenID,
        name: 'Hidden',
        kind: CategoryKind.expense,
        colorHex: '#000000',
        includeInAnalysis: false,
        parentID: null,
        symbol: 'tag',
      ),
    );
    _expense(
      state,
      'b0000000-0000-0000-0000-000000000003',
      '-6.00',
      DateTime.utc(2027, 4, 3),
      categoryID: _hiddenID,
    );
    state.addEntry(
      Entry(
        id: 'b0000000-0000-0000-0000-000000000004',
        amount: Decimal.parse('100.00'),
        name: 'Opening balance',
        sourceID: _checkingID,
        date: DateTime.utc(2027, 4, 3),
        includeInAnalysis: false,
        systemKind: SystemEntryKind.openingBalance,
      ),
    );
    state.addAccount(
      Account(
        id: '99999999-9999-9999-9999-999999999999',
        name: 'Flagged',
        type: AccountType.savings,
        incomingTransfersAsExpenses: true,
      ),
    );
    state.addEntry(
      Entry(
        id: 'b0000000-0000-0000-0000-000000000005',
        amount: Decimal.parse('40.00'),
        name: 'set aside',
        sourceID: _checkingID,
        destinationID: '99999999-9999-9999-9999-999999999999',
        date: DateTime.utc(2027, 4, 4),
      ),
    );
    final setup = _ready(state);
    await _accept(setup.cache, setup.ledger);
    final queries = setup.queries;

    final days = queries.readRegisterDays(window: _april());
    final second = days.value!.firstWhere(
      (day) => day.date == DateTime.utc(2027, 4, 2),
    );
    expect(second.entries, hasLength(2));
    expect(second.expense, Decimal.parse('5.00'));

    final third = days.value!.firstWhere(
      (day) => day.date == DateTime.utc(2027, 4, 3),
    );
    expect(third.entries, hasLength(2));
    expect(third.expense, Decimal.parse('6.00'));
    expect(third.income, Decimal.zero);

    final fourth = days.value!.firstWhere(
      (day) => day.date == DateTime.utc(2027, 4, 4),
    );
    expect(fourth.expense, Decimal.parse('40.00'));
    expect(fourth.moved, Decimal.parse('40.00'));

    final period = queries.readPeriod(window: _april());
    expect(period.value?.spent, Decimal.parse('45.00'));

    final transfers = queries.readRegisterDays(
      window: _april(),
      kind: EntryKind.transfer,
    );
    expect(transfers.value, hasLength(1));
    expect(transfers.value!.single.date, DateTime.utc(2027, 4, 4));
  });

  test('recentOrdersNewestFirstAndAppliesLimit', () async {
    final state = _baseState();
    _expense(
      state,
      'c0000000-0000-0000-0000-000000000001',
      '-25.25',
      DateTime.utc(2027, 4, 1),
    );
    _expense(
      state,
      'c0000000-0000-0000-0000-000000000002',
      '-7.00',
      DateTime.utc(2027, 4, 5),
    );
    _expense(
      state,
      'c0000000-0000-0000-0000-000000000003',
      '-13.50',
      DateTime.utc(2027, 4, 7),
      name: 'first',
    );
    _expense(
      state,
      'c0000000-0000-0000-0000-000000000004',
      '-2.00',
      DateTime.utc(2027, 4, 7),
      name: 'second',
    );
    state.addEntry(
      Entry(
        id: 'c0000000-0000-0000-0000-000000000005',
        amount: Decimal.parse('70.00'),
        name: 'pay',
        sourceID: _checkingID,
        categoryID: _payID,
        date: DateTime.utc(2027, 4, 7),
      ),
    );
    _expense(
      state,
      'c0000000-0000-0000-0000-000000000006',
      '-3.00',
      DateTime.utc(2027, 4, 8),
      name: 'tomorrow',
    );
    final setup = _ready(state);
    await _accept(setup.cache, setup.ledger);
    final queries = setup.queries;

    final recent = queries.readRecent();
    expect(recent.state, AnalysisQueryState.ready);
    expect(recent.value!.map((record) => record.entry.name), [
      'pay',
      'second',
      'first',
      'expense',
    ]);

    final pair = queries.readRecent(limit: 2);
    expect(pair.value!.map((record) => record.entry.name), ['pay', 'second']);

    final all = queries.readRecent(limit: 10);
    expect(all.value, hasLength(5));
    expect(
      all.value!.any((record) => record.entry.name == 'tomorrow'),
      isFalse,
    );

    expect(queries.readRecent(limit: 0).value, isEmpty);

    final negative = queries.readRecent(limit: -1);
    expect(negative.state, AnalysisQueryState.failed);
    expect(queries.readRecent().state, AnalysisQueryState.ready);
  });

  test('searchMatchesNamesAcrossScopes', () async {
    final state = _baseState();
    state.addCategory(
      TransactionCategory(
        id: _diningID,
        name: 'Dining',
        kind: CategoryKind.expense,
        colorHex: '#000000',
        includeInAnalysis: true,
        parentID: null,
        symbol: 'tag',
      ),
    );
    state.addCategory(
      TransactionCategory(
        id: _ramenID,
        name: 'Ramen',
        kind: CategoryKind.expense,
        colorHex: '#000000',
        includeInAnalysis: true,
        parentID: _diningID,
        symbol: 'tag',
      ),
    );
    _expense(
      state,
      'd0000000-0000-0000-0000-000000000001',
      '-18.00',
      DateTime.utc(2027, 4, 7),
      categoryID: _ramenID,
      name: 'Ramen night',
    );
    _expense(
      state,
      'd0000000-0000-0000-0000-000000000002',
      '-30.00',
      DateTime.utc(2027, 4, 6),
      name: 'Groceries',
    );
    state.addEntry(
      Entry(
        id: 'd0000000-0000-0000-0000-000000000003',
        amount: Decimal.parse('2000.00'),
        name: 'Paycheck',
        sourceID: _checkingID,
        categoryID: _payID,
        date: DateTime.utc(2027, 4, 7),
      ),
    );
    state.addEntry(
      Entry(
        id: 'd0000000-0000-0000-0000-000000000004',
        amount: Decimal.parse('100.00'),
        name: 'rent buffer',
        sourceID: _checkingID,
        destinationID: _savingsID,
        date: DateTime.utc(2027, 4, 5),
      ),
    );
    _expense(
      state,
      'd0000000-0000-0000-0000-000000000005',
      '-15.00',
      DateTime.utc(2027, 3, 20),
      categoryID: _ramenID,
      name: 'Old ramen',
    );
    final setup = _ready(state);
    await _accept(setup.cache, setup.ledger);
    final queries = setup.queries;

    final ramen = queries.readSearch(query: 'ramen');
    expect(ramen.state, AnalysisQueryState.ready);
    expect(ramen.value, hasLength(2));
    expect(ramen.value![0].month, const YearMonth(2027, 4));
    expect(ramen.value![1].month, const YearMonth(2027, 3));
    expect(ramen.value![0].expense, Decimal.parse('18.00'));

    final upper = queries.readSearch(query: '  RAMEN ');
    expect(identical(upper, ramen), isTrue);

    final parent = queries.readSearch(query: 'dining');
    expect(
      parent.value!.expand((month) => month.matches).map((r) => r.entry.name),
      containsAll(['Ramen night', 'Old ramen']),
    );

    final source = queries.readSearch(query: 'checking');
    expect(source.value!.expand((month) => month.matches), hasLength(5));

    final destination = queries.readSearch(query: 'savings');
    expect(destination.value!.single.matches.single.entry.name, 'rent buffer');

    final blank = queries.readSearch(query: '   ');
    expect(blank.value!.expand((month) => month.matches), hasLength(5));

    final ranged = queries.readSearch(query: 'ramen', window: _april());
    expect(ranged.value, hasLength(1));
    expect(ranged.value!.single.month, const YearMonth(2027, 4));

    final transfers = queries.readSearch(query: '  ', kind: EntryKind.transfer);
    expect(transfers.value!.single.matches.single.entry.name, 'rent buffer');

    final none = queries.readSearch(query: 'ramen', sourceIDs: {_savingsID});
    expect(none.value, isEmpty);
  });

  test('upcomingMergesKindsWithTieOrderAndCursorRules', () async {
    final state = _baseState();
    _addCard(state);
    _expense(
      state,
      'e0000000-0000-0000-0000-000000000001',
      '-20.00',
      DateTime.utc(2027, 4, 10),
      name: 'concert',
    );
    _expense(
      state,
      'e0000000-0000-0000-0000-000000000002',
      '-13.50',
      DateTime.utc(2027, 4, 7),
      name: 'today entry',
    );
    _addPlan(
      state,
      id: '11111111-aaaa-1111-aaaa-111111111111',
      anchor: DateTime.utc(2027, 4, 12),
      lastResolvedDate: DateTime.utc(2027, 4, 12),
      name: 'cursor at anchor',
    );
    _addPlan(
      state,
      id: '22222222-bbbb-2222-bbbb-222222222222',
      anchor: DateTime.utc(2027, 4, 9),
      lastResolvedDate: DateTime.utc(2027, 4, 2),
      name: 'cursor before anchor',
    );
    _addPlan(
      state,
      id: '44444444-dddd-4444-dddd-444444444444',
      anchor: DateTime.utc(2027, 4, 10),
      lastResolvedDate: DateTime.utc(2027, 4, 3),
      name: 'tie plan',
    );
    final suppressedID = OccurrenceID.make(
      '22222222-bbbb-2222-bbbb-222222222222',
      DateTime.utc(2027, 4, 16),
    );
    state.addEntry(
      Entry(
        id: suppressedID,
        amount: Decimal.parse('-19.98'),
        name: 'recorded occurrence',
        sourceID: _checkingID,
        categoryID: _foodID,
        date: DateTime.utc(2027, 4, 16),
      ),
    );
    _addPlan(
      state,
      id: '33333333-cccc-3333-cccc-333333333333',
      anchor: DateTime.utc(2027, 3, 20),
      lastResolvedDate: DateTime.utc(2027, 3, 20),
      frequency: RecurrenceFrequency.monthly,
      name: 'monthly',
    );
    state.addEntry(
      Entry(
        id: 'e0000000-0000-0000-0000-000000000003',
        amount: Decimal.parse('-1.00'),
        name: 'edge',
        sourceID: _checkingID,
        categoryID: _foodID,
        date: DateTime.utc(2027, 4, 20),
      ),
    );
    final setup = _ready(state);
    await _accept(setup.cache, setup.ledger);
    final queries = setup.queries;

    final window = DateRange(
      DateTime.utc(2027, 4, 7),
      DateTime.utc(2027, 4, 20),
    );
    final upcoming = queries.readUpcoming(window: window);
    expect(upcoming.state, AnalysisQueryState.ready);
    final items = upcoming.value!;

    expect(
      items.any(
        (item) =>
            item is UpcomingEntry && item.record.entry.name == 'today entry',
      ),
      isFalse,
    );

    final plans = items.whereType<UpcomingPlan>().toList();
    expect(
      plans.any((plan) => plan.occurrence.date == DateTime.utc(2027, 4, 12)),
      isFalse,
    );
    expect(
      plans
          .where(
            (plan) =>
                plan.occurrence.planID ==
                '22222222-bbbb-2222-bbbb-222222222222',
          )
          .map((plan) => plan.occurrence.date),
      [DateTime.utc(2027, 4, 9)],
    );
    expect(
      plans
          .where(
            (plan) =>
                plan.occurrence.planID ==
                '11111111-aaaa-1111-aaaa-111111111111',
          )
          .map((plan) => plan.occurrence.date),
      [DateTime.utc(2027, 4, 19)],
    );

    expect(
      plans.any(
        (plan) =>
            plan.occurrence.planID == '22222222-bbbb-2222-bbbb-222222222222' &&
            plan.occurrence.date == DateTime.utc(2027, 4, 16),
      ),
      isFalse,
    );
    expect(
      items.any(
        (item) =>
            item is UpcomingEntry &&
            item.record.entry.name == 'recorded occurrence',
      ),
      isTrue,
    );

    expect(
      items.any(
        (item) =>
            item is UpcomingPlan &&
            item.occurrence.date == DateTime.utc(2027, 4, 20),
      ),
      isFalse,
    );
    expect(
      items.any(
        (item) => item is UpcomingEntry && item.record.entry.name == 'edge',
      ),
      isFalse,
    );

    final widened = queries
        .readUpcoming(
          window: DateRange(
            DateTime.utc(2027, 4, 7),
            DateTime.utc(2027, 4, 21),
          ),
        )
        .value!;
    expect(
      widened.any(
        (item) =>
            item is UpcomingPlan &&
            item.occurrence.planID == '33333333-cccc-3333-cccc-333333333333' &&
            item.occurrence.date == DateTime.utc(2027, 4, 20),
      ),
      isTrue,
    );
    expect(
      widened.any(
        (item) => item is UpcomingEntry && item.record.entry.name == 'edge',
      ),
      isTrue,
    );

    final tenth = items
        .where((item) => item.date == DateTime.utc(2027, 4, 10))
        .toList();
    expect(tenth.map((item) => item.runtimeType), [
      UpcomingStatement,
      UpcomingPlan,
      UpcomingEntry,
    ]);

    final scoped = queries.readUpcoming(
      window: window,
      sourceIDs: {_savingsID},
    );
    expect(scoped.value, isEmpty);
  });

  test('upcomingStatementUsesClosingCycleOnCutDay', () async {
    final state = _baseState();
    _addCard(state);
    state.addEntry(
      Entry(
        id: 'f0000000-0000-0000-0000-000000000001',
        amount: Decimal.parse('-50.00'),
        name: 'card charge',
        sourceID: _cardID,
        categoryID: _foodID,
        date: DateTime.utc(2027, 4, 5),
      ),
    );
    state.addEntry(
      Entry(
        id: 'f0000000-0000-0000-0000-000000000002',
        amount: Decimal.parse('20.00'),
        name: 'repayment',
        sourceID: _checkingID,
        destinationID: _cardID,
        date: DateTime.utc(2027, 4, 6),
      ),
    );
    state.addEntry(
      Entry(
        id: 'f0000000-0000-0000-0000-000000000003',
        amount: Decimal.parse('-5.00'),
        name: 'cut-day charge',
        sourceID: _cardID,
        categoryID: _foodID,
        date: DateTime.utc(2027, 4, 10),
      ),
    );
    state.addAccount(
      Account(
        id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        name: 'Archived',
        type: AccountType.card,
        statementDay: 10,
      ),
    );
    state.deleteAccount('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
    state.addAccount(
      Account(
        id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        name: 'No cut',
        type: AccountType.card,
      ),
    );
    final setup = _ready(state);
    await _accept(setup.cache, setup.ledger);

    final upcoming = setup.queries.readUpcoming();
    final statements = upcoming.value!.whereType<UpcomingStatement>().toList();
    expect(statements, hasLength(1));
    expect(statements.single.date, DateTime.utc(2027, 4, 10));
    expect(statements.single.cycleAmount, Decimal.parse('50.00'));

    final cutDay = _ready(state, today: DateTime.utc(2027, 4, 10));
    await _accept(cutDay.cache, cutDay.ledger);
    final closing = cutDay.queries
        .readUpcoming()
        .value!
        .whereType<UpcomingStatement>()
        .toList();
    expect(closing, hasLength(1));
    expect(closing.single.date, DateTime.utc(2027, 4, 10));
    expect(closing.single.cycleAmount, Decimal.parse('50.00'));

    final cardScoped = setup.queries.readUpcoming(sourceIDs: {_cardID});
    expect(cardScoped.value!.whereType<UpcomingStatement>(), hasLength(1));
    final cardScopedStatement = cardScoped.value!
        .whereType<UpcomingStatement>()
        .single;
    expect(cardScopedStatement.date, DateTime.utc(2027, 4, 10));
    expect(cardScopedStatement.cycleAmount, Decimal.parse('50.00'));
    final emptyScoped = setup.queries.readUpcoming(sourceIDs: <String>{});
    expect(emptyScoped.value!.whereType<UpcomingStatement>(), isEmpty);
    final checkingScoped = setup.queries.readUpcoming(sourceIDs: {_checkingID});
    expect(checkingScoped.value!.whereType<UpcomingStatement>(), isEmpty);
  });

  test('weeksTotalAcrossMonthBoundaryWithCounts', () async {
    final state = _baseState();
    _expense(
      state,
      'g0000000-0000-0000-0000-000000000001',
      '-4.50',
      DateTime.utc(2027, 3, 31),
    );
    _expense(
      state,
      'g0000000-0000-0000-0000-000000000002',
      '-25.25',
      DateTime.utc(2027, 4, 1),
    );
    _expense(
      state,
      'g0000000-0000-0000-0000-000000000003',
      '-9.75',
      DateTime.utc(2027, 4, 4),
    );
    _expense(
      state,
      'g0000000-0000-0000-0000-000000000004',
      '-7.00',
      DateTime.utc(2027, 4, 5),
    );
    _expense(
      state,
      'g0000000-0000-0000-0000-000000000005',
      '-13.50',
      DateTime.utc(2027, 4, 7),
    );
    _expense(
      state,
      'g0000000-0000-0000-0000-000000000006',
      '-3.00',
      DateTime.utc(2027, 4, 10),
    );
    _expense(
      state,
      'g0000000-0000-0000-0000-000000000007',
      '-6.00',
      DateTime.utc(2027, 4, 15),
    );
    _expense(
      state,
      'g0000000-0000-0000-0000-000000000008',
      '-8.00',
      DateTime.utc(2027, 5, 1),
    );
    final setup = _ready(state);
    await _accept(setup.cache, setup.ledger);
    final queries = setup.queries;

    final weeks = queries.readWeeks(window: _april());
    expect(weeks.state, AnalysisQueryState.ready);
    expect(weeks.sourceRevision, setup.ledger.revision);
    expect(weeks.value!.map((week) => week.range), [
      DateRange(DateTime.utc(2027, 3, 29), DateTime.utc(2027, 4, 5)),
      DateRange(DateTime.utc(2027, 4, 5), DateTime.utc(2027, 4, 12)),
      DateRange(DateTime.utc(2027, 4, 12), DateTime.utc(2027, 4, 19)),
      DateRange(DateTime.utc(2027, 4, 19), DateTime.utc(2027, 4, 26)),
      DateRange(DateTime.utc(2027, 4, 26), DateTime.utc(2027, 5, 3)),
    ]);

    final first = weeks.value![0];
    expect(first.spent, Decimal.parse('39.50'));
    expect(first.expenseItemCount, 3);
    expect(
      first.effectiveWindow,
      DateRange(DateTime.utc(2027, 3, 29), DateTime.utc(2027, 4, 5)),
    );

    final second = weeks.value![1];
    expect(second.spent, Decimal.parse('23.50'));
    expect(second.expenseItemCount, 3);
    expect(
      second.effectiveWindow,
      DateRange(DateTime.utc(2027, 4, 5), DateTime.utc(2027, 4, 12)),
    );

    final future = weeks.value![2];
    expect(future.spent, Decimal.parse('6.00'));
    expect(future.expenseItemCount, 1);
    expect(
      future.effectiveWindow,
      DateRange(DateTime.utc(2027, 4, 12), DateTime.utc(2027, 4, 19)),
    );

    final closing = weeks.value![4];
    expect(closing.spent, Decimal.parse('8.00'));
    expect(closing.expenseItemCount, 1);
    expect(
      closing.effectiveWindow,
      DateRange(DateTime.utc(2027, 4, 26), DateTime.utc(2027, 5, 3)),
    );

    final period = queries.readPeriod(window: _april());
    expect(period.state, AnalysisQueryState.ready);
    expect(period.value!.spent, Decimal.parse('64.50'));

    final scoped = queries.readWeeks(window: _april(), sourceIDs: {_savingsID});
    expect(scoped.value![0].spent, Decimal.zero);
    expect(scoped.value![0].expenseItemCount, 0);

    final none = queries.readWeeks(window: _april(), sourceIDs: {});
    expect(none.value!.every((week) => week.spent == Decimal.zero), isTrue);

    final yearWeeks = queries.readWeeks(
      window: DateRange(DateTime.utc(2026, 12, 28), DateTime.utc(2027, 1, 11)),
    );
    expect(yearWeeks.value!.map((week) => week.range), [
      DateRange(DateTime.utc(2026, 12, 28), DateTime.utc(2027, 1, 4)),
      DateRange(DateTime.utc(2027, 1, 4), DateTime.utc(2027, 1, 11)),
    ]);
  });

  test('boundaryWeeksMatchAcrossAdjacentMonthReads', () async {
    final state = _baseState();
    _expense(
      state,
      'b0000000-0000-0000-0000-000000000001',
      '-4.50',
      DateTime.utc(2027, 3, 31),
    );
    _expense(
      state,
      'b0000000-0000-0000-0000-000000000002',
      '-5.00',
      DateTime.utc(2027, 4, 2),
    );
    _expense(
      state,
      'b0000000-0000-0000-0000-000000000003',
      '-11.00',
      DateTime.utc(2027, 4, 28),
    );
    _expense(
      state,
      'b0000000-0000-0000-0000-000000000004',
      '-8.00',
      DateTime.utc(2027, 5, 1),
    );
    final setup = _ready(state);
    await _accept(setup.cache, setup.ledger);
    final queries = setup.queries;

    final april = queries.readWeeks(window: _april());
    expect(april.state, AnalysisQueryState.ready);
    final opening = april.value!.firstWhere(
      (week) => week.range.start == DateTime.utc(2027, 3, 29),
    );
    expect(opening.spent, Decimal.parse('9.50'));
    expect(opening.expenseItemCount, 2);
    final closing = april.value!.firstWhere(
      (week) => week.range.start == DateTime.utc(2027, 4, 26),
    );
    expect(closing.spent, Decimal.parse('19.00'));
    expect(closing.expenseItemCount, 2);

    final march = queries.readWeeks(
      window: DateRange(DateTime.utc(2027, 3, 1), DateTime.utc(2027, 4, 1)),
    );
    expect(march.state, AnalysisQueryState.ready);
    final marchClosing = march.value!.last;
    expect(marchClosing.range, opening.range);
    expect(marchClosing.effectiveWindow, opening.effectiveWindow);
    expect(marchClosing.spent, opening.spent);
    expect(marchClosing.expenseItemCount, opening.expenseItemCount);

    final may = queries.readWeeks(
      window: DateRange(DateTime.utc(2027, 5, 1), DateTime.utc(2027, 6, 1)),
    );
    expect(may.state, AnalysisQueryState.ready);
    final mayOpening = may.value!.first;
    expect(mayOpening.range, closing.range);
    expect(mayOpening.effectiveWindow, closing.effectiveWindow);
    expect(mayOpening.spent, closing.spent);
    expect(mayOpening.expenseItemCount, closing.expenseItemCount);
  });

  test('calendarMarksRecordedAndPlannedDays', () async {
    final state = _baseState();
    _expense(
      state,
      'h0000000-0000-0000-0000-000000000001',
      '-25.25',
      DateTime.utc(2027, 4, 1),
    );
    _expense(
      state,
      'h0000000-0000-0000-0000-000000000002',
      '-13.50',
      DateTime.utc(2027, 4, 7),
      name: 'first',
    );
    _expense(
      state,
      'h0000000-0000-0000-0000-000000000003',
      '-2.00',
      DateTime.utc(2027, 4, 7),
      name: 'second',
    );
    _expense(
      state,
      'h0000000-0000-0000-0000-000000000004',
      '-3.00',
      DateTime.utc(2027, 4, 10),
      name: 'future',
    );
    _addPlan(
      state,
      id: '11111111-aaaa-1111-aaaa-111111111111',
      anchor: DateTime.utc(2027, 4, 7),
      lastResolvedDate: DateTime.utc(2027, 4, 1),
      name: 'weekly',
    );
    _addPlan(
      state,
      id: '22222222-bbbb-2222-bbbb-222222222222',
      anchor: DateTime.utc(2027, 4, 7),
      lastResolvedDate: DateTime.utc(2027, 4, 1),
      name: 'second weekly',
    );
    _addPlan(
      state,
      id: '33333333-cccc-3333-cccc-333333333333',
      anchor: DateTime.utc(2027, 3, 1),
      lastResolvedDate: DateTime.utc(2027, 3, 1),
      endDate: DateTime.utc(2027, 4, 2),
      name: 'ended',
    );
    final suppressedID = OccurrenceID.make(
      '11111111-aaaa-1111-aaaa-111111111111',
      DateTime.utc(2027, 4, 14),
    );
    state.addEntry(
      Entry(
        id: suppressedID,
        amount: Decimal.parse('-19.98'),
        name: 'recorded occurrence',
        sourceID: _checkingID,
        categoryID: _foodID,
        date: DateTime.utc(2027, 4, 14),
      ),
    );
    final setup = _ready(state);
    await _accept(setup.cache, setup.ledger);
    final queries = setup.queries;

    final calendar = queries.readCalendarDays(window: _april());
    expect(calendar.state, AnalysisQueryState.ready);
    final dates = calendar.value!.map((day) => day.date).toList();
    expect(dates, [
      DateTime.utc(2027, 4, 1),
      DateTime.utc(2027, 4, 7),
      DateTime.utc(2027, 4, 10),
      DateTime.utc(2027, 4, 14),
      DateTime.utc(2027, 4, 21),
      DateTime.utc(2027, 4, 28),
    ]);

    final seventh = calendar.value!.firstWhere(
      (day) => day.date == DateTime.utc(2027, 4, 7),
    );
    expect(seventh.entries, hasLength(2));
    expect(seventh.entries.first.entry.name, 'second');
    expect(seventh.plans, hasLength(2));
    expect(seventh.plans.map((plan) => plan.planID), [
      '11111111-aaaa-1111-aaaa-111111111111',
      '22222222-bbbb-2222-bbbb-222222222222',
    ]);

    final tenth = calendar.value!.firstWhere(
      (day) => day.date == DateTime.utc(2027, 4, 10),
    );
    expect(tenth.entries.single.entry.name, 'future');

    final fourteenth = calendar.value!.firstWhere(
      (day) => day.date == DateTime.utc(2027, 4, 14),
    );
    expect(fourteenth.entries.single.entry.name, 'recorded occurrence');
    expect(
      fourteenth.plans.where(
        (plan) => plan.planID == '11111111-aaaa-1111-aaaa-111111111111',
      ),
      isEmpty,
    );

    expect(
      calendar.value!
          .expand((day) => day.plans)
          .any((plan) => plan.planID == '33333333-cccc-3333-cccc-333333333333'),
      isFalse,
    );
  });

  test('resultsAreImmutableAndResolveMetadata', () async {
    final state = _baseState();
    _periodEntries(state);
    final setup = _ready(state);
    await _accept(setup.cache, setup.ledger);
    final queries = setup.queries;

    final days = queries.readRegisterDays(window: _april());
    expect(
      () => days.value!.first.entries.add(days.value!.first.entries.single),
      throwsUnsupportedError,
    );
    final record = days.value!.first.entries.single;
    expect(record.category?.name, 'Food');
    expect(record.sourceName, 'Checking');

    final recent = queries.readRecent();
    expect(
      () => recent.value!.add(recent.value!.first),
      throwsUnsupportedError,
    );

    final search = queries.readSearch(query: 'pay');
    expect(search.value!.single.matches.single.destinationName, isNull);

    final weeks = queries.readWeeks(window: _april());
    expect(() => weeks.value!.clear(), throwsUnsupportedError);

    final calendar = queries.readCalendarDays(window: _april());
    expect(() => calendar.value!.clear(), throwsUnsupportedError);
  });

  test('equivalentReadsReuseAcrossNormalizedScopes', () async {
    final state = _baseState();
    _periodEntries(state);
    final setup = _ready(state);
    await _accept(setup.cache, setup.ledger);
    final queries = setup.queries;

    final first = queries.readRegisterDays(window: _april());
    expect(
      identical(
        queries.readRegisterDays(
          window: DateRange(DateTime.utc(2027, 4, 1), DateTime.utc(2027, 5, 1)),
        ),
        first,
      ),
      isTrue,
    );

    final scoped = queries.readRegisterDays(
      window: _april(),
      sourceIDs: {_checkingID},
    );
    expect(
      identical(
        queries.readRegisterDays(
          window: _april(),
          sourceIDs: {_checkingID.toUpperCase(), _checkingID},
        ),
        scoped,
      ),
      isTrue,
    );
    expect(
      identical(
        queries.readRegisterDays(window: _april(), kind: EntryKind.expense),
        queries.readRegisterDays(window: _april()),
      ),
      isFalse,
    );

    final scope = {_checkingID, _savingsID};
    final weeksFirst = queries.readWeeks(window: _april(), sourceIDs: scope);
    scope.remove(_savingsID);
    scope.add('99999999-9999-9999-9999-999999999999');
    expect(
      identical(
        queries.readWeeks(
          window: _april(),
          sourceIDs: {_checkingID, _savingsID},
        ),
        weeksFirst,
      ),
      isTrue,
    );

    final recentFirst = queries.readRecent(limit: 2);
    expect(identical(queries.readRecent(limit: 2), recentFirst), isTrue);
    expect(identical(queries.readRecent(limit: 3), recentFirst), isFalse);

    final cardFirst = queries.readCardStatement(accountID: _checkingID);
    expect(
      identical(
        queries.readCardStatement(accountID: _checkingID.toUpperCase()),
        cardFirst,
      ),
      isTrue,
    );
    expect(
      identical(queries.readCardStatement(accountID: _savingsID), cardFirst),
      isFalse,
    );

    final window = DateRange(_today, _today.add(const Duration(days: 42)));
    expect(
      identical(queries.readUpcoming(), queries.readUpcoming(window: window)),
      isTrue,
    );
  });

  test('ledgerOnlyReadsComputeWhileMixedReadsStayPending', () async {
    final ledger = Ledger();
    ledger.addAccount(
      Account(id: _checkingID, name: 'Checking', type: AccountType.checking),
    );
    ledger.addCategory(
      TransactionCategory(
        id: _foodID,
        name: 'Food',
        kind: CategoryKind.expense,
        colorHex: '#000000',
        includeInAnalysis: true,
        parentID: null,
        symbol: 'tag',
      ),
    );
    final runner = _ManualRunner();
    final cache = AnalysisCache(runner: runner.call)
      ..start(ledger.bus, sourceRevision: () => ledger.revision);
    final queries = AnalysisQueries(
      ledger: ledger,
      cache: cache,
      today: _today,
    );
    addTearDown(() async {
      queries.dispose();
      await cache.dispose();
    });

    runner.pending.last.complete(const []);
    await pumpEventQueue();
    final settled = queries.readPeriod(window: _april());
    expect(settled.state, AnalysisQueryState.ready);

    ledger.addEntry(
      Entry(
        id: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
        amount: Decimal.parse('-13.50'),
        name: 'lunch',
        sourceID: _checkingID,
        categoryID: _foodID,
        date: _today,
      ),
    );

    final pendingPeriod = queries.readPeriod(window: _april());
    expect(pendingPeriod.state, AnalysisQueryState.loading);
    expect(pendingPeriod.value, settled.value);

    final pendingWeeks = queries.readWeeks(window: _april());
    expect(pendingWeeks.state, AnalysisQueryState.loading);
    expect(pendingWeeks.value, isNull);

    final register = queries.readRegisterDays(window: _april());
    expect(register.state, AnalysisQueryState.ready);
    expect(register.sourceRevision, ledger.revision);
    expect(register.value, hasLength(1));
    expect(register.value!.single.expense, Decimal.parse('13.50'));

    expect(queries.readRecent().state, AnalysisQueryState.ready);
    expect(queries.readRecent().value, hasLength(1));

    runner.pending.last.complete(Accounting.analysisItems(ledger.state));
    await pumpEventQueue();

    final updated = queries.readPeriod(window: _april());
    expect(updated.state, AnalysisQueryState.ready);
    expect(updated.value?.spent, Decimal.parse('13.50'));
  });

  test('todayRolloverMovesDefaultReadsWithoutRunnerCall', () async {
    final state = _baseState();
    _expense(
      state,
      'f0000000-0000-0000-0000-000000000001',
      '-13.50',
      DateTime.utc(2027, 4, 7),
    );
    _expense(
      state,
      'f0000000-0000-0000-0000-000000000002',
      '-5.00',
      DateTime.utc(2027, 4, 9),
    );
    _addPlan(
      state,
      id: '11111111-aaaa-1111-aaaa-111111111111',
      anchor: DateTime.utc(2027, 4, 7),
      lastResolvedDate: DateTime.utc(2027, 3, 31),
      name: 'weekly',
    );
    final ledger = Ledger(state: state);
    final runner = _ManualRunner();
    final cache = AnalysisCache(runner: runner.call)
      ..start(ledger.bus, sourceRevision: () => ledger.revision);
    final queries = AnalysisQueries(
      ledger: ledger,
      cache: cache,
      today: _today,
    );
    addTearDown(() async {
      queries.dispose();
      await cache.dispose();
    });
    var notifications = 0;
    queries.addListener(() => notifications++);

    runner.pending.last.complete(Accounting.analysisItems(ledger.state));
    await pumpEventQueue();
    expect(notifications, 1);

    final before = queries.readUpcoming();
    expect(
      before.value!.any(
        (item) =>
            item is UpcomingPlan &&
            item.occurrence.date == DateTime.utc(2027, 4, 7),
      ),
      isTrue,
    );
    final calendarBefore = queries.readCalendarDays(window: _april());
    expect(
      calendarBefore.value!.any(
        (day) => day.date == DateTime.utc(2027, 4, 7) && day.plans.isNotEmpty,
      ),
      isTrue,
    );
    final weeksBefore = queries.readWeeks(window: _april());
    final focusBefore = weeksBefore.value!.firstWhere(
      (week) => week.range.start == DateTime.utc(2027, 4, 5),
    );
    expect(
      focusBefore.effectiveWindow,
      DateRange(DateTime.utc(2027, 4, 5), DateTime.utc(2027, 4, 12)),
    );
    expect(focusBefore.spent, Decimal.parse('18.50'));
    expect(focusBefore.expenseItemCount, 2);

    queries.setToday(DateTime.utc(2027, 4, 8));
    expect(runner.calls, 1);
    expect(notifications, 2);

    final after = queries.readUpcoming();
    expect(after.state, AnalysisQueryState.ready);
    expect(
      after.value!.any(
        (item) =>
            item is UpcomingEntry &&
            item.record.entry.date == DateTime.utc(2027, 4, 7),
      ),
      isFalse,
    );
    expect(
      after.value!.any(
        (item) =>
            item is UpcomingPlan &&
            item.occurrence.date == DateTime.utc(2027, 4, 7),
      ),
      isFalse,
    );

    final calendarAfter = queries.readCalendarDays(window: _april());
    expect(
      calendarAfter.value!.any(
        (day) => day.date == DateTime.utc(2027, 4, 7) && day.plans.isNotEmpty,
      ),
      isFalse,
    );

    final weeksAfter = queries.readWeeks(window: _april());
    final focusAfter = weeksAfter.value!.firstWhere(
      (week) => week.range.start == DateTime.utc(2027, 4, 5),
    );
    expect(
      focusAfter.effectiveWindow,
      DateRange(DateTime.utc(2027, 4, 5), DateTime.utc(2027, 4, 12)),
    );
    expect(focusAfter.spent, focusBefore.spent);
    expect(focusAfter.expenseItemCount, focusBefore.expenseItemCount);

    final register = queries.readRegisterDays(window: _april());
    expect(
      identical(register, queries.readRegisterDays(window: _april())),
      isTrue,
    );
  });

  test('queryFailuresAreIsolatedAndRetryRecovers', () async {
    final state = _baseState();
    _periodEntries(state);
    final setup = _ready(state);
    await _accept(setup.cache, setup.ledger);
    final queries = setup.queries;

    final reversed = DateRange(
      DateTime.utc(2027, 5, 1),
      DateTime.utc(2027, 4, 1),
    );
    final failed = queries.readRegisterDays(window: reversed);
    expect(failed.state, AnalysisQueryState.failed);
    expect(failed.value, isNull);

    expect(
      queries.readPeriod(window: _april()).state,
      AnalysisQueryState.ready,
    );
    expect(queries.readRecent().state, AnalysisQueryState.ready);
    expect(queries.readWeeks(window: _april()).state, AnalysisQueryState.ready);

    await queries.retry();
    expect(
      queries.readRegisterDays(window: reversed).state,
      AnalysisQueryState.failed,
    );

    final recovered = queries.readRegisterDays(window: _april());
    expect(recovered.state, AnalysisQueryState.ready);
    expect(recovered.value, hasLength(5));

    final failedSearch = queries.readSearch(query: 'ramen', window: reversed);
    expect(failedSearch.state, AnalysisQueryState.failed);
    expect(queries.readSearch(query: 'ramen').state, AnalysisQueryState.ready);
  });

  test('negativeTransferPlanProjectsAsResolved', () async {
    final state = _baseState();
    const planID = '99999999-aaaa-4444-aaaa-aaaaaaaaaaaa';
    final occurrence = DateTime.utc(2027, 4, 9);
    state.addPlan(
      RecurringPlan(
        id: planID,
        template: EntryTemplate(
          amount: Decimal.parse('-10'),
          name: 'sweep',
          sourceID: _checkingID,
          destinationID: _savingsID,
        ),
        frequency: RecurrenceFrequency.weekly,
        anchor: occurrence,
        lastResolvedDate: DateTime.utc(2027, 4, 2),
      ),
    );
    final setup = _ready(state);
    await _accept(setup.cache, setup.ledger);
    final queries = setup.queries;

    final window = DateRange(
      DateTime.utc(2027, 4, 7),
      DateTime.utc(2027, 4, 20),
    );
    final upcoming = queries
        .readUpcoming(window: window)
        .value!
        .whereType<UpcomingPlan>()
        .singleWhere(
          (item) =>
              item.occurrence.planID == planID &&
              item.occurrence.date == occurrence,
        );
    final projected = upcoming.occurrence.projected.entry;
    expect(projected.sourceID, _savingsID);
    expect(projected.destinationID, _checkingID);
    expect(projected.amount, Decimal.parse('10'));

    final calendar = queries.readCalendarDays(window: _april()).value!;
    final day = calendar.firstWhere((item) => item.date == occurrence);
    final planned = day.plans.singleWhere((item) => item.planID == planID);
    expect(planned.projected.entry, projected);

    setup.ledger.resolvePlans(DateTime.utc(2027, 4, 10));
    final materialized = state.entries[OccurrenceID.make(planID, occurrence)]!;
    expect(materialized.sourceID, projected.sourceID);
    expect(materialized.destinationID, projected.destinationID);
    expect(materialized.amount, projected.amount);
    expect(materialized, projected);
  });

  test('ineligibleCardIsReadyNullWithRevision', () async {
    final state = _baseState();
    _periodEntries(state);
    _addCard(state, statementDay: null);
    final setup = _ready(state);
    await _accept(setup.cache, setup.ledger);
    final queries = setup.queries;

    final checking = queries.readCardStatement(accountID: _checkingID);
    expect(checking.state, AnalysisQueryState.ready);
    expect(checking.value, isNull);
    expect(checking.sourceRevision, setup.ledger.revision);

    final unknown = queries.readCardStatement(
      accountID: '00000000-0000-0000-0000-000000000000',
    );
    expect(unknown.state, AnalysisQueryState.ready);
    expect(unknown.value, isNull);
    expect(unknown.sourceRevision, setup.ledger.revision);

    final noCut = queries.readCardStatement(accountID: _cardID);
    expect(noCut.state, AnalysisQueryState.ready);
    expect(noCut.value, isNull);
  });
}
