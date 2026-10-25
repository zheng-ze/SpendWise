import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/breakdowns/category_breakdown.dart';
import 'package:spendwise/ledger/analysis/breakdowns/scoped_trend.dart';
import 'package:spendwise/ledger/analysis/summaries/register.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/format/analysis_bucket_name.dart';
import 'package:spendwise/ui/stats/helpers/stats_window.dart';
import 'package:spendwise/ui/symbol_map.dart';
import 'package:spendwise/ui/transactions/top_categories_view_model.dart';
import 'package:spendwise/ui/transactions/top_categories_view_state.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

const _readyTimeout = Duration(seconds: 5);
const _pollInterval = Duration(milliseconds: 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('history key normalizes by named calendar period and mode', () {
    final local = TopCategoriesKey.forHistory(
      selectedDate: DateTime(2026, 3, 31, 23),
      mode: TransactionsScreenMode.daily,
    );
    final utc = TopCategoriesKey.forHistory(
      selectedDate: DateTime.utc(2026, 3, 2),
      mode: TransactionsScreenMode.daily,
    );
    final year = TopCategoriesKey.forHistory(
      selectedDate: DateTime(2026, 3, 2),
      mode: TransactionsScreenMode.monthly,
    );

    expect(local, utc);
    expect(local.period, DateTime.utc(2026, 3, 1));
    expect(year.period, DateTime.utc(2026, 1, 1));
    expect(local, isNot(year));
  });

  test(
    'ready rows keep query ranking and shares over the full window',
    () async {
      final fixture = _fixture();
      final container = _container(fixture.ledger);
      addTearDown(container.dispose);
      final key = TopCategoriesKey.forHistory(
        selectedDate: DateTime.utc(2026, 3, 17),
        mode: TransactionsScreenMode.daily,
      );
      final body = await _bodyFor(container, key);

      expect(body, isA<TopCategoriesReadyBody>());
      final ready = body as TopCategoriesReadyBody;
      expect(ready.total, Decimal.fromInt(100));
      expect(
        ready.rows.map((row) => row.bucketID),
        fixture.categoryIDs.take(3),
      );
      expect(ready.rows.map((row) => row.amount), [
        Decimal.fromInt(70),
        Decimal.fromInt(20),
        Decimal.fromInt(9),
      ]);
      expect(
        ready.rows.fold(Decimal.zero, (sum, row) => sum + row.sharePercent),
        Decimal.fromInt(99),
      );
      expect(ready.rows.first.name, 'Category 1');
      expect(ready.rows.first.icon, symbolIcon('restaurant'));
      expect(() => ready.rows.add(ready.rows.first), throwsUnsupportedError);
    },
  );

  test('confirmed empty register exposes compact state', () async {
    final container = _container(Ledger(state: LedgerState()));
    addTearDown(container.dispose);
    final key = TopCategoriesKey.forHistory(
      selectedDate: DateTime.utc(2026, 3, 17),
      mode: TransactionsScreenMode.daily,
    );

    expect(await _bodyFor(container, key), isA<TopCategoriesCompactBody>());
  });

  test(
    'ready zero-spend period stays compact when the register has income',
    () async {
      final container = _container(_incomeLedger());
      addTearDown(container.dispose);
      final key = TopCategoriesKey.forHistory(
        selectedDate: DateTime.utc(2026, 3, 17),
        mode: TransactionsScreenMode.daily,
      );

      expect(await _bodyFor(container, key), isA<TopCategoriesCompactBody>());
    },
  );

  test('monthly History reads the selected calendar year', () async {
    final fixture = _fixture();
    final fake = _RetainedFailureQueries(
      ledger: fixture.ledger,
      cache: AnalysisCache(runner: syncComputeRunner),
      today: DateTime.utc(2026, 10, 1),
      oldBreakdown: _breakdown(fixture.categoryIDs.first, revision: -1),
      registerResult: AnalysisQueryResult(
        value: const [],
        state: AnalysisQueryState.ready,
        sourceRevision: fixture.ledger.revision,
      ),
    );
    final container = _container(fixture.ledger, queryOverride: (ref) => fake);
    addTearDown(container.dispose);
    final key = TopCategoriesKey.forHistory(
      selectedDate: DateTime(2026, 12, 19),
      mode: TransactionsScreenMode.monthly,
    );

    await _bodyFor(container, key);

    expect(fake.requestedPeriod, DateTime.utc(2026, 1, 1));
    expect(fake.requestedMode, AnalysisPeriodMode.year);
    expect(fake.requestedWindow, yearWindow(DateTime.utc(2026, 1, 1)));
  });

  test(
    'real queries use half-open windows, roll up parents and keep tie order',
    () async {
      final ledger = _boundaryLedger();
      final container = _container(ledger);
      addTearDown(container.dispose);
      final dailyKey = TopCategoriesKey.forHistory(
        selectedDate: DateTime.utc(2026, 3, 15),
        mode: TransactionsScreenMode.daily,
      );
      final daily =
          await _bodyFor(container, dailyKey) as TopCategoriesReadyBody;

      expect(daily.total, Decimal.fromInt(110));
      expect(daily.rows.map((row) => row.bucketID), [
        'c0000000-0000-0000-0000-000000000001',
        'c0000000-0000-0000-0000-000000000002',
        'c0000000-0000-0000-0000-000000000003',
      ]);
      expect(daily.rows.map((row) => row.amount), [
        Decimal.fromInt(70),
        Decimal.fromInt(20),
        Decimal.fromInt(10),
      ]);

      final yearlyKey = TopCategoriesKey.forHistory(
        selectedDate: DateTime.utc(2026, 12, 1),
        mode: TransactionsScreenMode.monthly,
      );
      final yearly =
          await _bodyFor(container, yearlyKey) as TopCategoriesReadyBody;
      expect(yearly.total, Decimal.fromInt(218));
      expect(yearly.rows.map((row) => row.amount), [
        Decimal.fromInt(170),
        Decimal.fromInt(25),
        Decimal.fromInt(12),
      ]);
    },
  );

  test('one and two available rows remain unpadded', () async {
    for (final count in [1, 2]) {
      final ledger = _smallExpenseLedger(count);
      final container = _container(ledger);
      final key = TopCategoriesKey.forHistory(
        selectedDate: DateTime.utc(2026, 3),
        mode: TransactionsScreenMode.daily,
      );

      final body = await _bodyFor(container, key) as TopCategoriesReadyBody;

      expect(body.rows, hasLength(count));
      container.dispose();
    }
  });

  test(
    'ready loading failure retry and recovery use real query revisions',
    () async {
      final ledger = _fixture().ledger;
      final runner = _ControlledRunner();
      final container = _container(ledger, runner: runner.run);
      addTearDown(container.dispose);
      final key = TopCategoriesKey.forHistory(
        selectedDate: DateTime.utc(2026, 3),
        mode: TransactionsScreenMode.daily,
      );
      final provider = topCategoriesViewModelProvider(key);
      final emissions = <TopCategoriesBody?>[];
      final subscription = container.listen(provider, (_, next) {
        emissions.add(next.value?.body);
      });
      addTearDown(subscription.close);

      await _waitForRunnerCalls(runner, 1);
      await runner.completeNext();
      final firstReady = await _waitForBody(
        container,
        key,
        (body) => body is TopCategoriesReadyBody,
      ) as TopCategoriesReadyBody;
      expect(firstReady.sourceRevision, 0);

      ledger.addEntry(
        _expenseEntry(
          'c0000000-0000-0000-0000-000000000001',
          amount: 5,
          date: DateTime.utc(2026, 3, 20),
        ),
      );
      await _waitForRunnerCalls(runner, 2);
      expect(
        container.read(provider).value?.body,
        isA<TopCategoriesLoadingBody>(),
      );
      runner.failNext(StateError('controlled analysis failure'));
      final failed = await _waitForBody(
        container,
        key,
        (body) => body is TopCategoriesErrorBody,
      );
      expect(failed, isA<TopCategoriesErrorBody>());

      final notifier =
          container.read(provider.notifier) as TopCategoriesViewModel;
      notifier.retry();
      await _waitForRunnerCalls(runner, 3);
      notifier.retry();
      notifier.retry();
      await Future<void>.delayed(_pollInterval);
      expect(runner.calls, 3);
      expect(
        container.read(provider).value?.body,
        isA<TopCategoriesLoadingBody>(),
      );
      await runner.completeNext();
      final recovered = await _waitForBody(
        container,
        key,
        (body) => body is TopCategoriesReadyBody && body.sourceRevision == 1,
      ) as TopCategoriesReadyBody;

      expect(recovered.total, Decimal.fromInt(105));
      expect(emissions, contains(isA<TopCategoriesErrorBody>()));
    },
  );

  test('first real computation failure has no retained value', () async {
    final runner = _ControlledRunner();
    final container = _container(_fixture().ledger, runner: runner.run);
    addTearDown(container.dispose);
    final key = TopCategoriesKey.forHistory(
      selectedDate: DateTime.utc(2026, 3),
      mode: TransactionsScreenMode.daily,
    );
    final provider = topCategoriesViewModelProvider(key);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    await _waitForRunnerCalls(runner, 1);
    runner.failNext(StateError('initial computation failure'));
    final body = await _waitForBody(
      container,
      key,
      (body) => body is TopCategoriesErrorBody,
    );
    final queries = container.read(analysisQueriesProvider)!;
    final result = queries.readCategoryBreakdown(
      period: key.period,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );

    expect(body, isA<TopCategoriesErrorBody>());
    expect(result.state, AnalysisQueryState.failed);
    expect(result.value, isNull);
    expect(result.sourceRevision, isNull);
  });

  test('period switch while work is pending never carries old rows', () async {
    final runner = _ControlledRunner();
    final container = _container(_fixture().ledger, runner: runner.run);
    addTearDown(container.dispose);
    final oldKey = TopCategoriesKey.forHistory(
      selectedDate: DateTime.utc(2026, 3),
      mode: TransactionsScreenMode.daily,
    );
    final oldSubscription = container.listen(
      topCategoriesViewModelProvider(oldKey),
      (_, _) {},
    );
    addTearDown(oldSubscription.close);
    await _waitForRunnerCalls(runner, 1);
    final newKey = TopCategoriesKey.forHistory(
      selectedDate: DateTime.utc(2025, 8),
      mode: TransactionsScreenMode.monthly,
    );
    final newProvider = topCategoriesViewModelProvider(newKey);
    final newEmissions = <TopCategoriesBody?>[];
    final newSubscription = container.listen(newProvider, (_, next) {
      newEmissions.add(next.value?.body);
    });
    addTearDown(newSubscription.close);

    expect(
      container.read(newProvider).value?.body,
      isA<TopCategoriesLoadingBody>(),
    );
    await runner.completeNext();
    final current = await _waitForBody(
      container,
      newKey,
      (body) => body is TopCategoriesCompactBody,
    );
    expect(current, isA<TopCategoriesCompactBody>());
    expect(newEmissions.whereType<TopCategoriesReadyBody>(), isEmpty);
  });

  test('disposing a pending family leaves shared queries usable', () async {
    final runner = _ControlledRunner();
    final container = _container(_fixture().ledger, runner: runner.run);
    addTearDown(container.dispose);
    final key = TopCategoriesKey.forHistory(
      selectedDate: DateTime.utc(2026, 3),
      mode: TransactionsScreenMode.daily,
    );
    final provider = topCategoriesViewModelProvider(key);
    final subscription = container.listen(provider, (_, _) {});
    final viewModel =
        container.read(provider.notifier) as TopCategoriesViewModel;
    final session = container.read(ledgerSessionProvider);
    await _waitForRunnerCalls(runner, 1);
    subscription.close();
    await Future<void>.delayed(_pollInterval);
    viewModel.retry();
    await runner.completeNext();

    expect(container.read(ledgerSessionProvider), same(session));
    final queries = container.read(analysisQueriesProvider)!;
    AnalysisQueryState currentState() => queries
        .readCategoryBreakdown(
          period: key.period,
          mode: AnalysisPeriodMode.month,
          kind: CategoryKind.expense,
          level: BreakdownLevel.categories,
        )
        .state;
    final timer = Stopwatch()..start();
    while (currentState() != AnalysisQueryState.ready &&
        timer.elapsed < _readyTimeout) {
      await Future<void>.delayed(_pollInterval);
    }
    expect(currentState(), AnalysisQueryState.ready);
    final reopened = await _bodyFor(container, key);
    expect(reopened, isA<TopCategoriesReadyBody>());
  });

  test(
    'session replacement with the same revision projects only new metadata',
    () async {
      final firstLedger = _singleCategoryLedger(name: 'Outgoing', amount: 10);
      final nextLedger = _singleCategoryLedger(name: 'Current', amount: 25);
      final replaceableLedgerProvider = StateProvider<Ledger?>(
        (ref) => firstLedger,
      );
      final container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWith(
            (ref) => ref.watch(replaceableLedgerProvider),
          ),
          clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 1)),
          analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
        ],
      );
      addTearDown(container.dispose);
      final key = TopCategoriesKey.forHistory(
        selectedDate: DateTime.utc(2026, 3),
        mode: TransactionsScreenMode.daily,
      );
      final provider = topCategoriesViewModelProvider(key);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final emissions = <TopCategoriesBody?>[];
      final recordingSubscription = container.listen(provider, (_, next) {
        emissions.add(next.value?.body);
      });
      addTearDown(recordingSubscription.close);
      final before = await _bodyFor(container, key) as TopCategoriesReadyBody;
      expect(before.rows.single.name, 'Outgoing');
      expect(before.sourceRevision, 0);

      final replacementEmissionStart = emissions.length;
      container.read(replaceableLedgerProvider.notifier).state = nextLedger;
      final after = await _bodyNamed(container, key, 'Current');

      expect(after.total, Decimal.fromInt(25));
      expect(after.rows.single.name, 'Current');
      expect(after.sourceRevision, 0);
      expect(
        emissions
            .skip(replacementEmissionStart)
            .whereType<TopCategoriesReadyBody>()
            .map((body) => body.rows.single.name),
        isNot(contains('Outgoing')),
      );
    },
  );

  test('failed retained breakdown wins over its old revision', () async {
    final fixture = _fixture();
    final fake = _RetainedFailureQueries(
      ledger: fixture.ledger,
      cache: AnalysisCache(runner: syncComputeRunner),
      today: DateTime.utc(2026, 10, 1),
      oldBreakdown: _breakdown(fixture.categoryIDs.first, revision: -1),
      registerResult: AnalysisQueryResult(
        value: const [],
        state: AnalysisQueryState.loading,
        sourceRevision: -1,
      ),
    );
    final container = _container(fixture.ledger, queryOverride: (ref) => fake);
    addTearDown(container.dispose);
    final key = TopCategoriesKey.forHistory(
      selectedDate: DateTime.utc(2026, 3),
      mode: TransactionsScreenMode.daily,
    );
    final body = await _bodyFor(container, key);

    expect(body, isA<TopCategoriesErrorBody>());
  });

  test('failed register query wins over pending analysis', () async {
    final fixture = _fixture();
    final fake = _RetainedFailureQueries(
      ledger: fixture.ledger,
      cache: AnalysisCache(runner: syncComputeRunner),
      today: DateTime.utc(2026, 10, 1),
      oldBreakdown: _breakdown(
        fixture.categoryIDs.first,
        revision: -1,
        state: AnalysisQueryState.loading,
      ),
      registerResult: AnalysisQueryResult(
        value: const [],
        state: AnalysisQueryState.failed,
        sourceRevision: -1,
      ),
    );
    final container = _container(fixture.ledger, queryOverride: (ref) => fake);
    addTearDown(container.dispose);
    final key = TopCategoriesKey.forHistory(
      selectedDate: DateTime.utc(2026, 3),
      mode: TransactionsScreenMode.daily,
    );

    expect(await _bodyFor(container, key), isA<TopCategoriesErrorBody>());
  });

  test('ready breakdown for another window exposes local error', () async {
    final fixture = _fixture();
    final fake = _RetainedFailureQueries(
      ledger: fixture.ledger,
      cache: AnalysisCache(runner: syncComputeRunner),
      today: DateTime.utc(2026, 10, 1),
      oldBreakdown: _breakdown(
        fixture.categoryIDs.first,
        revision: fixture.ledger.revision,
        state: AnalysisQueryState.ready,
        window: DateRange(DateTime.utc(2026, 4), DateTime.utc(2026, 5)),
      ),
      registerResult: AnalysisQueryResult(
        value: const [],
        state: AnalysisQueryState.ready,
        sourceRevision: fixture.ledger.revision,
      ),
    );
    final container = _container(fixture.ledger, queryOverride: (ref) => fake);
    addTearDown(container.dispose);
    final key = TopCategoriesKey.forHistory(
      selectedDate: DateTime.utc(2026, 3),
      mode: TransactionsScreenMode.daily,
    );

    expect(await _bodyFor(container, key), isA<TopCategoriesErrorBody>());
  });

  test('retry delegates while mounted and is inert after disposal', () async {
    final fixture = _fixture();
    final fake = _RetainedFailureQueries(
      ledger: fixture.ledger,
      cache: AnalysisCache(runner: syncComputeRunner),
      today: DateTime.utc(2026, 10, 1),
      oldBreakdown: _breakdown(fixture.categoryIDs.first, revision: -1),
      registerResult: AnalysisQueryResult(
        value: const [],
        state: AnalysisQueryState.ready,
        sourceRevision: fixture.ledger.revision,
      ),
    );
    final container = _container(fixture.ledger, queryOverride: (ref) => fake);
    final key = TopCategoriesKey.forHistory(
      selectedDate: DateTime.utc(2026, 3),
      mode: TransactionsScreenMode.daily,
    );
    final subscription = container.listen(
      topCategoriesViewModelProvider(key),
      (_, _) {},
    );
    final viewModel = container.read(
      topCategoriesViewModelProvider(key).notifier,
    );

    viewModel.retry();
    expect(fake.retryCount, 1);
    subscription.close();
    await Future<void>.delayed(_pollInterval);
    viewModel.retry();
    expect(fake.retryCount, 1);
    container.dispose();
  });

  test('row metadata uses saved values and existing fallbacks', () async {
    final category = _category(
      id: 'c0000000-0000-0000-0000-000000000001',
      name: 'Saved name',
      colorHex: 'malformed',
      symbol: 'unknown_symbol',
    );
    final ledger = _ledgerWith(
      [category],
      [_expenseEntry(category.id, amount: 1, date: DateTime.utc(2026, 3, 1))],
    );
    final query = _readyQueries(ledger, [
      category.id,
      null,
      syntheticTransferExpenseBucketID(AccountType.savings),
      'c0000000-0000-0000-0000-000000000099',
    ]);
    final container = _container(ledger, queryOverride: (ref) => query);
    addTearDown(container.dispose);
    final key = TopCategoriesKey.forHistory(
      selectedDate: DateTime.utc(2026, 3, 1),
      mode: TransactionsScreenMode.daily,
    );
    final body = await _bodyFor(container, key);
    final rows = (body as TopCategoriesReadyBody).rows;

    expect(rows[0].name, 'Saved name');
    expect(rows[0].icon, fallbackSymbolIcon);
    expect(rows[1].name, uncategorizedName);
    expect(rows[1].icon, symbolIcon('help_outline'));
    expect(rows[2].name, 'Savings transfers');
    expect(rows[2].icon, symbolIcon('swap_horiz'));
  });

  test('unresolved bucket metadata uses the uncategorized fallback', () async {
    final fixture = _fixture();
    final query = _readyQueries(fixture.ledger, [
      'c0000000-0000-0000-0000-000000000099',
    ]);
    final container = _container(fixture.ledger, queryOverride: (ref) => query);
    addTearDown(container.dispose);
    final key = TopCategoriesKey.forHistory(
      selectedDate: DateTime.utc(2026, 3),
      mode: TransactionsScreenMode.daily,
    );

    final body = await _bodyFor(container, key);
    final row = (body as TopCategoriesReadyBody).rows.single;

    expect(row.name, uncategorizedName);
    expect(row.icon, symbolIcon('help_outline'));
  });
}

Future<TopCategoriesBody> _bodyFor(
  ProviderContainer container,
  TopCategoriesKey key,
) async {
  final provider = topCategoriesViewModelProvider(key);
  final subscription = container.listen(provider, (_, _) {});
  try {
    final timer = Stopwatch()..start();
    while (timer.elapsed < _readyTimeout) {
      final body = container.read(provider).value?.body;
      if (body case final TopCategoriesBody current
          when current is! TopCategoriesLoadingBody) {
        return current;
      }
      await Future<void>.delayed(_pollInterval);
    }
    throw TimeoutException('Top categories did not settle', _readyTimeout);
  } finally {
    subscription.close();
  }
}

Future<TopCategoriesReadyBody> _bodyNamed(
  ProviderContainer container,
  TopCategoriesKey key,
  String categoryName,
) async {
  final timer = Stopwatch()..start();
  while (timer.elapsed < _readyTimeout) {
    final body = container
        .read(topCategoriesViewModelProvider(key))
        .value
        ?.body;
    if (body is TopCategoriesReadyBody &&
        body.rows.any((row) => row.name == categoryName)) {
      return body;
    }
    await Future<void>.delayed(_pollInterval);
  }
  throw TimeoutException('Top categories did not update', _readyTimeout);
}

ProviderContainer _container(
  Ledger ledger, {
  AnalysisQueries Function(Ref ref)? queryOverride,
  ComputeRunner? runner,
}) {
  final overrides = [
    ledgerProvider.overrideWithValue(ledger),
    clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 1)),
    analysisComputeRunnerProvider.overrideWithValue(
      runner ?? syncComputeRunner,
    ),
  ];
  if (queryOverride != null) {
    overrides.add(analysisQueriesProvider.overrideWith(queryOverride));
  }
  return ProviderContainer(overrides: overrides);
}

_Fixture _fixture() {
  final categories = <TransactionCategory>[
    for (var index = 1; index <= 4; index++)
      _category(
        id: 'c0000000-0000-0000-0000-${index.toString().padLeft(12, '0')}',
        name: 'Category $index',
        colorHex: index == 1 ? '#123456' : '#AABBCC',
        symbol: index == 1 ? 'restaurant' : 'payments_outlined',
      ),
  ];
  final amounts = [70, 20, 9, 1];
  final entries = [
    for (var index = 0; index < categories.length; index++)
      _expenseEntry(
        categories[index].id,
        amount: amounts[index],
        date: DateTime.utc(2026, 3, 4 + index),
      ),
  ];
  return _Fixture(_ledgerWith(categories, entries), [
    for (final category in categories) category.id,
  ]);
}

Ledger _singleCategoryLedger({required String name, required int amount}) {
  const categoryID = 'c0000000-0000-0000-0000-000000000001';
  final category = _category(
    id: categoryID,
    name: name,
    colorHex: '#123456',
    symbol: 'restaurant',
  );
  return _ledgerWith(
    [category],
    [_expenseEntry(categoryID, amount: amount, date: DateTime.utc(2026, 3, 4))],
  );
}

Ledger _incomeLedger() {
  const categoryID = 'c0000000-0000-0000-0000-000000000001';
  final category = _category(
    id: categoryID,
    name: 'Salary',
    kind: CategoryKind.income,
    colorHex: '#123456',
    symbol: 'payments_outlined',
  );
  return _ledgerWith(
    [category],
    [_entry(categoryID, amount: 10, date: DateTime.utc(2026, 3, 4))],
  );
}

TransactionCategory _category({
  required String id,
  required String name,
  CategoryKind kind = CategoryKind.expense,
  required String colorHex,
  String? parentID,
  required String symbol,
}) => TransactionCategory(
  id: id,
  name: name,
  kind: kind,
  colorHex: colorHex,
  includeInAnalysis: true,
  parentID: parentID,
  symbol: symbol,
);

Ledger _ledgerWith(List<TransactionCategory> categories, List<Entry> entries) {
  const accountID = 'a0000000-0000-0000-0000-000000000001';
  final account = Account(
    id: accountID,
    name: 'Checking',
    type: AccountType.checking,
  );
  final source = MoneySource.account(account);
  final state = LedgerState(
    moneySources: {accountID: source},
    categories: {for (final category in categories) category.id: category},
    entries: {for (final entry in entries) entry.id: entry},
  );
  return Ledger(state: state);
}

Entry _expenseEntry(
  String categoryID, {
  required int amount,
  required DateTime date,
}) => _entry(categoryID, amount: -amount, date: date);

Entry _entry(
  String? categoryID, {
  required int amount,
  required DateTime date,
  String? id,
}) {
  final entryID =
      id ??
      'e0000000-0000-0000-0000-${(_nextEntryID++).toString().padLeft(12, '0')}';
  return Entry(
    id: entryID,
    amount: Decimal.fromInt(amount),
    name: 'Entry $entryID',
    sourceID: 'a0000000-0000-0000-0000-000000000001',
    categoryID: categoryID,
    date: date,
  );
}

var _nextEntryID = 100;

Ledger _boundaryLedger() {
  const firstID = 'c0000000-0000-0000-0000-000000000001';
  const secondID = 'c0000000-0000-0000-0000-000000000002';
  const thirdID = 'c0000000-0000-0000-0000-000000000003';
  const fourthID = 'c0000000-0000-0000-0000-000000000004';
  final categories = [
    _category(
      id: firstID,
      name: 'Parent one',
      colorHex: '#123456',
      symbol: 'restaurant',
    ),
    _category(
      id: secondID,
      name: 'Parent two',
      colorHex: '#123456',
      symbol: 'restaurant',
    ),
    _category(
      id: thirdID,
      name: 'Parent three',
      colorHex: '#123456',
      symbol: 'restaurant',
    ),
    _category(
      id: fourthID,
      name: 'Parent four',
      colorHex: '#123456',
      symbol: 'restaurant',
    ),
    _category(
      id: 'c0000000-0000-0000-0000-000000000005',
      name: 'Child one',
      parentID: firstID,
      colorHex: '#123456',
      symbol: 'restaurant',
    ),
    _category(
      id: 'c0000000-0000-0000-0000-000000000006',
      name: 'Salary',
      kind: CategoryKind.income,
      colorHex: '#123456',
      symbol: 'payments_outlined',
    ),
  ];
  final entries = [
    _expenseEntry(firstID, amount: 30, date: DateTime.utc(2026, 3, 1)),
    _expenseEntry(
      'c0000000-0000-0000-0000-000000000005',
      amount: 40,
      date: DateTime.utc(2026, 3, 31, 23, 59),
    ),
    _expenseEntry(secondID, amount: 20, date: DateTime.utc(2026, 3, 12)),
    _expenseEntry(thirdID, amount: 10, date: DateTime.utc(2026, 3, 13)),
    _expenseEntry(fourthID, amount: 10, date: DateTime.utc(2026, 3, 14)),
    _expenseEntry(firstID, amount: 100, date: DateTime.utc(2026, 4, 1)),
    _entry(
      'c0000000-0000-0000-0000-000000000006',
      amount: 500,
      date: DateTime.utc(2026, 3, 15),
    ),
    _expenseEntry(fourthID, amount: 1, date: DateTime.utc(2026, 1, 1)),
    _expenseEntry(secondID, amount: 5, date: DateTime.utc(2026, 11, 15)),
    _expenseEntry(thirdID, amount: 2, date: DateTime.utc(2026, 12, 31, 23, 59)),
    _expenseEntry(firstID, amount: 99, date: DateTime.utc(2027, 1, 1)),
  ];
  return _ledgerWith(categories, entries);
}

Ledger _smallExpenseLedger(int rowCount) {
  final categories = [
    for (var index = 1; index <= rowCount; index++)
      _category(
        id: 'c0000000-0000-0000-0000-${index.toString().padLeft(12, '0')}',
        name: 'Category $index',
        colorHex: '#123456',
        symbol: 'restaurant',
      ),
  ];
  final entries = [
    for (var index = 0; index < categories.length; index++)
      _expenseEntry(
        categories[index].id,
        amount: index + 1,
        date: DateTime.utc(2026, 3, index + 1),
      ),
  ];
  return _ledgerWith(categories, entries);
}

Future<TopCategoriesBody> _waitForBody(
  ProviderContainer container,
  TopCategoriesKey key,
  bool Function(TopCategoriesBody) matches,
) async {
  final timer = Stopwatch()..start();
  while (timer.elapsed < _readyTimeout) {
    final body = container
        .read(topCategoriesViewModelProvider(key))
        .value
        ?.body;
    if (body != null && matches(body)) return body;
    await Future<void>.delayed(_pollInterval);
  }
  throw TimeoutException('Top categories state did not match', _readyTimeout);
}

Future<void> _waitForRunnerCalls(_ControlledRunner runner, int expected) async {
  final timer = Stopwatch()..start();
  while (timer.elapsed < _readyTimeout) {
    if (runner.calls >= expected) return;
    await Future<void>.delayed(_pollInterval);
  }
  throw TimeoutException('Compute runner was not called', _readyTimeout);
}

class _ControlledRunner {
  final List<_PendingCompute> _pending = [];

  int calls = 0;

  Future<List<AnalysisItem>> run(LedgerState state) {
    calls++;
    final completer = Completer<List<AnalysisItem>>();
    _pending.add(_PendingCompute(state, completer));
    return completer.future;
  }

  Future<void> completeNext() async {
    final pending = _pending.removeAt(0);
    pending.completer.complete(await syncComputeRunner(pending.state));
  }

  void failNext(Object error) {
    _pending.removeAt(0).completer.completeError(error, StackTrace.current);
  }
}

class _PendingCompute {
  const _PendingCompute(this.state, this.completer);

  final LedgerState state;
  final Completer<List<AnalysisItem>> completer;
}

AnalysisQueryResult<PeriodBreakdown> _breakdown(
  String bucketID, {
  required int revision,
  AnalysisQueryState state = AnalysisQueryState.failed,
  DateRange? window,
}) {
  final selectedWindow =
      window ?? DateRange(DateTime.utc(2026, 3), DateTime.utc(2026, 4));
  final row = BreakdownRow(
    bucketID: bucketID,
    mainBucketID: bucketID,
    isDirect: false,
    amount: Decimal.fromInt(1),
    sharePercent: Decimal.fromInt(100),
  );
  final value = PeriodBreakdown(
    window: selectedWindow,
    kind: CategoryKind.expense,
    level: BreakdownLevel.categories,
    total: Decimal.fromInt(1),
    rows: [row],
  );
  return AnalysisQueryResult(
    value: value,
    state: state,
    sourceRevision: revision,
  );
}

class _RetainedFailureQueries extends AnalysisQueries {
  _RetainedFailureQueries({
    required super.ledger,
    required super.cache,
    required super.today,
    required this.oldBreakdown,
    required this.registerResult,
  });

  final AnalysisQueryResult<PeriodBreakdown> oldBreakdown;
  final AnalysisQueryResult<List<RegisterDay>> registerResult;
  var retryCount = 0;
  DateTime? requestedPeriod;
  AnalysisPeriodMode? requestedMode;
  DateRange? requestedWindow;

  @override
  AnalysisQueryResult<PeriodBreakdown> readCategoryBreakdown({
    required DateTime period,
    required AnalysisPeriodMode mode,
    required CategoryKind kind,
    required BreakdownLevel level,
  }) {
    requestedPeriod = period;
    requestedMode = mode;
    return oldBreakdown;
  }

  @override
  AnalysisQueryResult<List<RegisterDay>> readRegisterDays({
    required DateRange window,
    Set<String>? sourceIDs,
    EntryKind? kind,
  }) {
    requestedWindow = window;
    return registerResult;
  }

  @override
  Future<void> retry() async => retryCount++;
}

_RetainedFailureQueries _readyQueries(Ledger ledger, List<String?> bucketIDs) {
  final window = monthWindow(DateTime.utc(2026, 3));
  final rows = [
    for (final bucketID in bucketIDs)
      BreakdownRow(
        bucketID: bucketID,
        mainBucketID: bucketID,
        isDirect: false,
        amount: Decimal.one,
        sharePercent: Decimal.parse('25.0'),
      ),
  ];
  final revision = ledger.revision;
  return _RetainedFailureQueries(
    ledger: ledger,
    cache: AnalysisCache(runner: syncComputeRunner),
    today: DateTime.utc(2026, 10, 1),
    oldBreakdown: AnalysisQueryResult(
      value: PeriodBreakdown(
        window: window,
        kind: CategoryKind.expense,
        level: BreakdownLevel.categories,
        total: Decimal.fromInt(bucketIDs.length),
        rows: rows,
      ),
      state: AnalysisQueryState.ready,
      sourceRevision: revision,
    ),
    registerResult: AnalysisQueryResult(
      value: [
        RegisterDay(
          date: DateTime.utc(2026, 3, 1),
          entries: const [],
          income: Decimal.zero,
          expense: Decimal.zero,
          net: Decimal.zero,
          moved: Decimal.zero,
        ),
      ],
      state: AnalysisQueryState.ready,
      sourceRevision: revision,
    ),
  );
}

class _Fixture {
  const _Fixture(this.ledger, this.categoryIDs);

  final Ledger ledger;
  final List<String> categoryIDs;
}
