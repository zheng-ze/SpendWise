import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/period_summary.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';

const _checkingID = '11111111-1111-1111-1111-111111111111';
const _savingsID = '22222222-2222-2222-2222-222222222222';
const _foodID = '33333333-3333-3333-3333-333333333333';
const _payID = '44444444-4444-4444-4444-444444444444';

final _today = DateTime.utc(2027, 4, 7);

DateRange _april() =>
    DateRange(DateTime.utc(2027, 4, 1), DateTime.utc(2027, 5, 1));

LedgerState _state() {
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
  bool includeInAnalysis = true,
}) {
  state.addEntry(
    Entry(
      id: id,
      amount: Decimal.parse(amount),
      name: 'expense',
      sourceID: _checkingID,
      categoryID: categoryID ?? _foodID,
      date: date,
      includeInAnalysis: includeInAnalysis,
    ),
  );
}

({AnalysisQueries queries, AnalysisCache cache}) _readyQueries(Ledger ledger) {
  final cache = AnalysisCache(runner: syncComputeRunner)
    ..start(ledger.bus, sourceRevision: () => ledger.revision);
  final queries = AnalysisQueries(ledger: ledger, cache: cache, today: _today);
  addTearDown(() async {
    queries.dispose();
    await cache.dispose();
  });
  return (queries: queries, cache: cache);
}

Future<void> _accept(AnalysisCache cache, Ledger ledger) async {
  for (var i = 0; i < 50 && cache.itemsSourceRevision != ledger.revision; i++) {
    await pumpEventQueue();
  }
}

void main() {
  test('periodTotalsExcludeTransfersAndReportThemAsMoved', () async {
    final state = _state();
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
    final ledger = Ledger(state: state);
    final ready = _readyQueries(ledger);
    await _accept(ready.cache, ledger);

    final result = ready.queries.readPeriod(window: _april());

    expect(result.state, AnalysisQueryState.ready);
    expect(result.sourceRevision, ledger.revision);
    expect(result.value?.spent, Decimal.parse('55.50'));
    expect(result.value?.income, Decimal.parse('70.00'));
    expect(result.value?.net, Decimal.parse('14.50'));
    expect(result.value?.moved, Decimal.parse('22.00'));
  });

  test('todayReportsOnlyTodaysSpending', () async {
    final state = _state();
    _expense(
      state,
      'b0000000-0000-0000-0000-000000000001',
      '-25.25',
      DateTime.utc(2027, 4, 1),
    );
    _expense(
      state,
      'b0000000-0000-0000-0000-000000000002',
      '-13.50',
      DateTime.utc(2027, 4, 7),
    );
    state.addEntry(
      Entry(
        id: 'b0000000-0000-0000-0000-000000000003',
        amount: Decimal.parse('70.00'),
        name: 'pay',
        sourceID: _checkingID,
        categoryID: _payID,
        date: DateTime.utc(2027, 4, 7),
      ),
    );
    final ledger = Ledger(state: state);
    final ready = _readyQueries(ledger);
    await _accept(ready.cache, ledger);

    final result = ready.queries.readToday();

    expect(result.state, AnalysisQueryState.ready);
    expect(result.value?.day, _today);
    expect(result.value?.spent, Decimal.parse('13.50'));
  });

  test('windowBoundariesAreHalfOpenAndCountTheWholeWindow', () async {
    final state = _state();
    _expense(
      state,
      'c0000000-0000-0000-0000-000000000001',
      '-25.25',
      DateTime.utc(2027, 4, 1),
    );
    _expense(
      state,
      'c0000000-0000-0000-0000-000000000002',
      '-13.50',
      DateTime.utc(2027, 4, 7),
    );
    _expense(
      state,
      'c0000000-0000-0000-0000-000000000003',
      '-3.00',
      DateTime.utc(2027, 4, 8),
    );
    _expense(
      state,
      'c0000000-0000-0000-0000-000000000004',
      '-5.00',
      DateTime.utc(2027, 5, 1),
    );
    final ledger = Ledger(state: state);
    final ready = _readyQueries(ledger);
    await _accept(ready.cache, ledger);

    final result = ready.queries.readPeriod(window: _april());

    expect(result.value?.spent, Decimal.parse('41.75'));
    expect(
      result.value?.effectiveWindow,
      DateRange(DateTime.utc(2027, 4, 1), DateTime.utc(2027, 5, 1)),
    );
  });

  test('entriesAfterTodayCountTowardIncomeNetAndMoved', () async {
    final state = _state();
    _expense(
      state,
      '10000000-0000-0000-0000-000000000001',
      '-25.25',
      DateTime.utc(2027, 4, 1),
    );
    state.addEntry(
      Entry(
        id: '10000000-0000-0000-0000-000000000002',
        amount: Decimal.parse('70.00'),
        name: 'pay',
        sourceID: _checkingID,
        categoryID: _payID,
        date: DateTime.utc(2027, 4, 8),
      ),
    );
    state.addEntry(
      Entry(
        id: '10000000-0000-0000-0000-000000000003',
        amount: Decimal.parse('22.00'),
        name: 'save',
        sourceID: _checkingID,
        destinationID: _savingsID,
        date: DateTime.utc(2027, 4, 8),
      ),
    );
    final ledger = Ledger(state: state);
    final ready = _readyQueries(ledger);
    await _accept(ready.cache, ledger);

    final result = ready.queries.readPeriod(window: _april());
    expect(result.value?.spent, Decimal.parse('25.25'));
    expect(result.value?.income, Decimal.parse('70.00'));
    expect(result.value?.net, Decimal.parse('44.75'));
    expect(result.value?.moved, Decimal.parse('22.00'));

    final scoped = ready.queries.readPeriod(
      window: _april(),
      sourceIDs: {_checkingID},
    );
    expect(scoped.value?.income, Decimal.parse('70.00'));
    expect(scoped.value?.net, Decimal.parse('44.75'));
    expect(scoped.value?.moved, Decimal.parse('22.00'));

    final destinationOnly = ready.queries.readPeriod(
      window: _april(),
      sourceIDs: {_savingsID},
    );
    expect(destinationOnly.value?.income, Decimal.zero);
    expect(destinationOnly.value?.moved, Decimal.parse('22.00'));
  });

  test('whollyFutureWindowCountsCommittedEntries', () async {
    final state = _state();
    _expense(
      state,
      '20000000-0000-0000-0000-000000000001',
      '-12.00',
      DateTime.utc(2027, 6, 5),
    );
    final ledger = Ledger(state: state);
    final ready = _readyQueries(ledger);
    await _accept(ready.cache, ledger);

    final window = DateRange(
      DateTime.utc(2027, 6, 1),
      DateTime.utc(2027, 7, 1),
    );
    final result = ready.queries.readPeriod(window: window);
    expect(result.state, AnalysisQueryState.ready);
    expect(result.value?.window, window);
    expect(result.value?.effectiveWindow, window);
    expect(result.value?.spent, Decimal.parse('12.00'));
  });

  test('emptyWindowTotalsZeroAndReversedWindowThrows', () async {
    final state = _state();
    _expense(
      state,
      'd0000000-0000-0000-0000-000000000001',
      '-13.50',
      DateTime.utc(2027, 4, 7),
    );
    final ledger = Ledger(state: state);
    final ready = _readyQueries(ledger);
    await _accept(ready.cache, ledger);

    final empty = ready.queries.readPeriod(
      window: DateRange(DateTime.utc(2027, 4, 7), DateTime.utc(2027, 4, 7)),
    );

    expect(empty.state, AnalysisQueryState.ready);
    expect(empty.value?.spent, Decimal.zero);
    expect(empty.value?.income, Decimal.zero);
    expect(empty.value?.net, Decimal.zero);
    expect(empty.value?.moved, Decimal.zero);

    final reversed = DateRange(
      DateTime.utc(2027, 5, 1),
      DateTime.utc(2027, 4, 1),
    );
    expect(
      () => periodSummary(
        ledger: ledger.state,
        items: const [],
        window: reversed,
      ),
      throwsArgumentError,
    );
    final failed = ready.queries.readPeriod(window: reversed);
    expect(failed.state, AnalysisQueryState.failed);
    expect(failed.value, isNull);
  });

  test('sourceScopeIntersectsAndEmptyScopeMeansNone', () async {
    final state = _state();
    _expense(
      state,
      'e0000000-0000-0000-0000-000000000001',
      '-25.25',
      DateTime.utc(2027, 4, 1),
    );
    _expense(
      state,
      'e0000000-0000-0000-0000-000000000002',
      '-13.50',
      DateTime.utc(2027, 4, 7),
    );
    state.addEntry(
      Entry(
        id: 'e0000000-0000-0000-0000-000000000003',
        amount: Decimal.parse('22.00'),
        name: 'save',
        sourceID: _checkingID,
        destinationID: _savingsID,
        date: DateTime.utc(2027, 4, 7),
      ),
    );
    final ledger = Ledger(state: state);
    final ready = _readyQueries(ledger);
    await _accept(ready.cache, ledger);

    final checkingOnly = ready.queries.readPeriod(
      window: _april(),
      sourceIDs: {_checkingID},
    );
    expect(checkingOnly.value?.spent, Decimal.parse('38.75'));
    expect(checkingOnly.value?.moved, Decimal.parse('22.00'));

    final destinationOnly = ready.queries.readPeriod(
      window: _april(),
      sourceIDs: {_savingsID},
    );
    expect(destinationOnly.value?.spent, Decimal.zero);
    expect(destinationOnly.value?.moved, Decimal.parse('22.00'));

    final both = ready.queries.readPeriod(
      window: _april(),
      sourceIDs: {_checkingID, _savingsID},
    );
    expect(both.value?.spent, Decimal.parse('38.75'));
    expect(both.value?.moved, Decimal.parse('22.00'));

    final none = ready.queries.readPeriod(window: _april(), sourceIDs: {});
    expect(none.value?.spent, Decimal.zero);
    expect(none.value?.income, Decimal.zero);
    expect(none.value?.moved, Decimal.zero);
  });

  test('excludedEntriesAndCategoriesLeaveTotals', () async {
    final state = _state();
    _expense(
      state,
      'f0000000-0000-0000-0000-000000000001',
      '-25.25',
      DateTime.utc(2027, 4, 1),
    );
    _expense(
      state,
      'f0000000-0000-0000-0000-000000000002',
      '-10.00',
      DateTime.utc(2027, 4, 2),
      includeInAnalysis: false,
    );
    state.addCategory(
      TransactionCategory(
        id: 'f0000000-0000-0000-0000-000000000010',
        name: 'Hidden',
        kind: CategoryKind.expense,
        colorHex: '#000000',
        includeInAnalysis: false,
        parentID: null,
        symbol: 'tag',
      ),
    );
    state.addEntry(
      Entry(
        id: 'f0000000-0000-0000-0000-000000000003',
        amount: Decimal.parse('-6.00'),
        name: 'hidden',
        sourceID: _checkingID,
        categoryID: 'f0000000-0000-0000-0000-000000000010',
        date: DateTime.utc(2027, 4, 3),
      ),
    );
    final ledger = Ledger(state: state);
    final ready = _readyQueries(ledger);
    await _accept(ready.cache, ledger);

    final unscoped = ready.queries.readPeriod(window: _april());
    expect(unscoped.value?.spent, Decimal.parse('25.25'));

    final scoped = ready.queries.readPeriod(
      window: _april(),
      sourceIDs: {_checkingID, _savingsID},
    );
    expect(scoped.value?.spent, Decimal.parse('25.25'));

    final today = ready.queries.readToday();
    expect(today.value?.spent, Decimal.zero);
  });

  test('treatAsExpenseTransfersCountAsSpendingAndStillMove', () async {
    final state = _state();
    state.addAccount(
      Account(
        id: '77777777-7777-7777-7777-777777777777',
        name: 'Flagged',
        type: AccountType.savings,
        incomingTransfersAsExpenses: true,
      ),
    );
    _expense(
      state,
      'g0000000-0000-0000-0000-000000000001',
      '-25.25',
      DateTime.utc(2027, 4, 1),
    );
    state.addEntry(
      Entry(
        id: 'g0000000-0000-0000-0000-000000000002',
        amount: Decimal.parse('40.00'),
        name: 'set aside',
        sourceID: _checkingID,
        destinationID: '77777777-7777-7777-7777-777777777777',
        date: DateTime.utc(2027, 4, 2),
      ),
    );
    state.addEntry(
      Entry(
        id: 'g0000000-0000-0000-0000-000000000003',
        amount: Decimal.parse('22.00'),
        name: 'plain',
        sourceID: _checkingID,
        destinationID: _savingsID,
        date: DateTime.utc(2027, 4, 3),
      ),
    );
    final ledger = Ledger(state: state);
    final ready = _readyQueries(ledger);
    await _accept(ready.cache, ledger);

    final result = ready.queries.readPeriod(window: _april());
    expect(result.value?.spent, Decimal.parse('65.25'));
    expect(result.value?.income, Decimal.zero);
    expect(result.value?.moved, Decimal.parse('62.00'));

    final fromSourceScope = ready.queries.readPeriod(
      window: _april(),
      sourceIDs: {_checkingID},
    );
    expect(fromSourceScope.value?.spent, Decimal.parse('65.25'));
    expect(fromSourceScope.value?.moved, Decimal.parse('62.00'));

    final flaggedOnly = ready.queries.readPeriod(
      window: _april(),
      sourceIDs: {'77777777-7777-7777-7777-777777777777'},
    );
    expect(flaggedOnly.value?.spent, Decimal.parse('40.00'));
    expect(flaggedOnly.value?.moved, Decimal.parse('40.00'));
  });

  test('dailyGuideUsesOverrideAndWholeDollarHalfUpRounding', () async {
    final state = _state();
    state.addBudget(null, Decimal.parse('300'), now: DateTime.utc(2027, 4, 2));
    final budgetID = state.budgets.values.single.id;
    state.setBudgetMonthOverride(
      budgetID,
      const YearMonth(2027, 4),
      Decimal.parse('315'),
    );
    final ledger = Ledger(state: state);
    final ready = _readyQueries(ledger);
    await _accept(ready.cache, ledger);

    expect(ready.queries.readToday().value?.dailyGuide, Decimal.parse('11'));
  });

  test('dailyGuideIsNullWithoutAnApplicableBudget', () async {
    final withoutBudget = Ledger(state: _state());
    final readyWithout = _readyQueries(withoutBudget);
    await _accept(readyWithout.cache, withoutBudget);
    expect(readyWithout.queries.readToday().value?.dailyGuide, isNull);

    final mayState = _state();
    mayState.addBudget(
      null,
      Decimal.parse('300'),
      now: DateTime.utc(2027, 5, 2),
    );
    final mayLedger = Ledger(state: mayState);
    final readyMay = _readyQueries(mayLedger);
    await _accept(readyMay.cache, mayLedger);
    expect(readyMay.queries.readToday().value?.dailyGuide, isNull);
  });
}
