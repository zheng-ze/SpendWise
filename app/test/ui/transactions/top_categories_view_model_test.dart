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
import 'package:spendwise/ui/format/color_hex.dart';
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
      expect(ready.rows.first.color, parseColorHex('#123456'));
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
      final before = await _bodyFor(container, key) as TopCategoriesReadyBody;
      expect(before.rows.single.name, 'Outgoing');
      expect(before.sourceRevision, 0);

      container.read(replaceableLedgerProvider.notifier).state = nextLedger;
      final after = await _bodyNamed(container, key, 'Current');

      expect(after.total, Decimal.fromInt(25));
      expect(after.rows.single.name, 'Current');
      expect(after.sourceRevision, 0);
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
    const accountID = 'a0000000-0000-0000-0000-000000000001';
    final category = TransactionCategory(
      id: 'c0000000-0000-0000-0000-000000000001',
      name: 'Saved name',
      kind: CategoryKind.expense,
      colorHex: 'malformed',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'unknown_symbol',
    );
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {
          accountID: MoneySource.account(
            Account(
              id: accountID,
              name: 'Checking',
              type: AccountType.checking,
            ),
          ),
        },
        categories: {category.id: category},
        entries: {
          'e0000000-0000-0000-0000-000000000001': Entry(
            id: 'e0000000-0000-0000-0000-000000000001',
            amount: Decimal.fromInt(-1),
            name: 'Active entry',
            sourceID: accountID,
            categoryID: category.id,
            date: DateTime.utc(2026, 3, 1),
          ),
        },
      ),
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
    expect(rows[0].color, colorHexFallback);
    expect(rows[0].icon, fallbackSymbolIcon);
    expect(rows[1].name, uncategorizedName);
    expect(rows[1].icon, symbolIcon('help_outline'));
    expect(rows[1].color, colorHexFallback);
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
    expect(row.color, colorHexFallback);
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
}) {
  final overrides = [
    ledgerProvider.overrideWithValue(ledger),
    clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 1)),
    analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
  ];
  if (queryOverride != null) {
    overrides.add(analysisQueriesProvider.overrideWith(queryOverride));
  }
  return ProviderContainer(overrides: overrides);
}

_Fixture _fixture() {
  const accountID = 'a0000000-0000-0000-0000-000000000001';
  final categories = <TransactionCategory>[
    for (var index = 1; index <= 4; index++)
      TransactionCategory(
        id: 'c0000000-0000-0000-0000-${index.toString().padLeft(12, '0')}',
        name: 'Category $index',
        kind: CategoryKind.expense,
        colorHex: index == 1 ? '#123456' : '#AABBCC',
        includeInAnalysis: true,
        parentID: null,
        symbol: index == 1 ? 'restaurant' : 'payments_outlined',
      ),
  ];
  final amounts = [70, 20, 9, 1];
  final state = LedgerState(
    moneySources: {
      accountID: MoneySource.account(
        Account(id: accountID, name: 'Checking', type: AccountType.checking),
      ),
    },
    categories: {for (final category in categories) category.id: category},
    entries: {
      for (var index = 0; index < categories.length; index++)
        'e0000000-0000-0000-0000-${(index + 1).toString().padLeft(12, '0')}': Entry(
          id: 'e0000000-0000-0000-0000-${(index + 1).toString().padLeft(12, '0')}',
          amount: Decimal.fromInt(-amounts[index]),
          name: 'Entry ${index + 1}',
          sourceID: accountID,
          categoryID: categories[index].id,
          date: DateTime.utc(2026, 3, 4 + index),
        ),
    },
  );
  return _Fixture(Ledger(state: state), [
    for (final category in categories) category.id,
  ]);
}

Ledger _singleCategoryLedger({required String name, required int amount}) {
  const accountID = 'a0000000-0000-0000-0000-000000000001';
  const categoryID = 'c0000000-0000-0000-0000-000000000001';
  const entryID = 'e0000000-0000-0000-0000-000000000001';
  final category = TransactionCategory(
    id: categoryID,
    name: name,
    kind: CategoryKind.expense,
    colorHex: '#123456',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'restaurant',
  );
  return Ledger(
    state: LedgerState(
      moneySources: {
        accountID: MoneySource.account(
          Account(id: accountID, name: 'Checking', type: AccountType.checking),
        ),
      },
      categories: {categoryID: category},
      entries: {
        entryID: Entry(
          id: entryID,
          amount: Decimal.fromInt(-amount),
          name: 'Entry',
          sourceID: accountID,
          categoryID: categoryID,
          date: DateTime.utc(2026, 3, 4),
        ),
      },
    ),
  );
}

Ledger _incomeLedger() {
  const accountID = 'a0000000-0000-0000-0000-000000000001';
  const categoryID = 'c0000000-0000-0000-0000-000000000001';
  const entryID = 'e0000000-0000-0000-0000-000000000001';
  final category = TransactionCategory(
    id: categoryID,
    name: 'Salary',
    kind: CategoryKind.income,
    colorHex: '#123456',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'payments_outlined',
  );
  return Ledger(
    state: LedgerState(
      moneySources: {
        accountID: MoneySource.account(
          Account(id: accountID, name: 'Checking', type: AccountType.checking),
        ),
      },
      categories: {categoryID: category},
      entries: {
        entryID: Entry(
          id: entryID,
          amount: Decimal.fromInt(10),
          name: 'Salary',
          sourceID: accountID,
          categoryID: categoryID,
          date: DateTime.utc(2026, 3, 4),
        ),
      },
    ),
  );
}

AnalysisQueryResult<PeriodBreakdown> _breakdown(
  String bucketID, {
  required int revision,
  AnalysisQueryState state = AnalysisQueryState.failed,
  DateRange? window,
}) => AnalysisQueryResult(
  value: PeriodBreakdown(
    window: window ?? DateRange(DateTime.utc(2026, 3), DateTime.utc(2026, 4)),
    kind: CategoryKind.expense,
    level: BreakdownLevel.categories,
    total: Decimal.fromInt(1),
    rows: [
      BreakdownRow(
        bucketID: bucketID,
        mainBucketID: bucketID,
        isDirect: false,
        amount: Decimal.fromInt(1),
        sharePercent: Decimal.fromInt(100),
      ),
    ],
  ),
  state: state,
  sourceRevision: revision,
);

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
