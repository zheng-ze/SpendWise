import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/breakdowns/category_breakdown.dart'
    as analysis;
import 'package:spendwise/ledger/analysis/breakdowns/scoped_trend.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_projection.dart';

import 'package:spendwise/settings/display_preferences.dart' as settings;
import 'package:spendwise/settings/display_preferences_providers.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown.dart';

import '../../ledger/analysis_test_support.dart';
import 'trends_test_support.dart';

final _today = DateTime.utc(2026, 10, 3);

void main() {
  test(
    'October categories preserve ranking, Decimal totals and bare signs',
    () async {
      final harness = await readyHarness(
        ledger: seededTrendsLedger(_today),
        today: _today,
      );
      final breakdown = harness.ready.breakdown;
      expect(breakdown.period, DateTime.utc(2026, 10));
      expect(breakdown.total, Decimal.parse('167.40'));
      final nameValues = breakdown.rows.map((row) => row.name);
      expect(nameValues, ['Dining', 'Groceries', 'Transport']);
      final formattedAmountValues = breakdown.rows.map(
        (row) => row.formattedAmount,
      );
      expect(formattedAmountValues, ['-83.90', '-73.50', '-10.00']);
      final formattedShareValues = breakdown.rows.map(
        (row) => row.formattedShare,
      );
      expect(formattedShareValues, ['50.1%', '43.9%', '6.0%']);
      final amountTotal = breakdown.rows.fold(
        Decimal.zero,
        (sum, row) => sum + row.amount,
      );
      final shareTotal = breakdown.rows.fold(
        Decimal.zero,
        (sum, row) => sum + row.sharePercent,
      );
      expect(amountTotal, breakdown.total);
      expect(shareTotal, Decimal.fromInt(100));
      expect(() => breakdown.rows.clear(), throwsUnsupportedError);
    },
  );

  test(
    'subcategory preference resolves child and Direct parent metadata',
    () async {
      final preferences = settings.DisplayPreferences(
        breakdownLevel: settings.BreakdownLevel.subcategories,
        breakdownChart: settings.BreakdownChart.categoryMap,
        chartColours: settings.ChartColours.contrasting,
      );
      final overrides = [
        initialDisplayPreferencesProvider.overrideWithValue(preferences),
      ];
      final harness = TrendsHarness(
        ledger: seededTrendsLedger(_today),
        today: _today,
        overrides: overrides,
      );
      await harness.settle();
      final breakdown = harness.ready.breakdown;
      expect(breakdown.chart, settings.BreakdownChart.categoryMap);
      expect(breakdown.colours, settings.ChartColours.contrasting);
      final nameValues = breakdown.rows.map((row) => row.name);
      expect(nameValues, [
        'Dining',
        'Supermarket',
        'Fresh Market',
        'Direct to Groceries',
        'Transport',
      ]);
      final direct = breakdown.rows.singleWhere((row) => row.isDirect);
      expect(direct.parentContext, 'Groceries');
      expect(direct.savedHex, '#34C759');
      expect(direct.formattedAmount, '-12.40');
      expect(direct.navigationTarget?.mainID, direct.mainBucketID);
      final child = breakdown.rows.singleWhere(
        (row) => row.name == 'Supermarket',
      );
      expect(child.parentContext, 'Groceries');
      expect(child.savedHex, '#30D158');
      expect(child.formattedShare, '25.4%');
    },
  );
  test(
    'income retains its plus sign and successful absence is empty',
    () async {
      final harness = await readyHarness(
        ledger: seededTrendsLedger(_today),
        today: _today,
      );
      harness.viewModel.setKind(TrendsKind.income);
      await harness.settle();
      final row = harness.ready.breakdown.rows.single;
      expect(row.name, 'Salary');
      expect(row.formattedAmount, '+3,200.00');
      expect(row.formattedShare, '100.0%');
      harness.viewModel.selectSlot(9);
      await harness.settle();
      expect(harness.ready.breakdown, isA<TrendsEmptyBreakdown>());
      expect(harness.ready.breakdown.total, Decimal.zero);
    },
  );

  test(
    'year includes after-today and December entries with matching headline',
    () async {
      final ledger = emptyTrendsLedger();
      addTrendsEntry(ledger, '-10', DateTime.utc(2026, 10, 2));
      addTrendsEntry(ledger, '-20', DateTime.utc(2026, 10, 30));
      addTrendsEntry(ledger, '-30', DateTime.utc(2026, 12, 31));
      addTrendsEntry(ledger, '-900', DateTime.utc(2027));
      final harness = await readyHarness(ledger: ledger, today: _today);
      expect(harness.ready.breakdown.total, Decimal.fromInt(30));
      harness.viewModel.setMode(TrendsMode.year);
      await harness.settle();
      final ready = harness.ready;
      expect(ready.breakdown.period, DateTime.utc(2026));
      expect(ready.breakdown.total, Decimal.fromInt(60));
      expect(ready.headline.amount, '-S\$60.00');
      expect(ready.bars[ready.selectedIndex].value, 60);
      expect(ready.usual, isNull);
      expect(ready.breakdown.rows.single.navigationTarget?.isYearRange, isTrue);
    },
  );

  test(
    'preferences update reactively without changing intent or unrelated fields',
    () async {
      SharedPreferences.setMockInitialValues({});
      final harness = await readyHarness(
        ledger: seededTrendsLedger(_today),
        today: _today,
      );
      final before = harness.intent;
      final notifier = harness.container.read(
        displayPreferencesProvider.notifier,
      );
      final preferences = settings.DisplayPreferences(
        breakdownLevel: settings.BreakdownLevel.subcategories,
        breakdownChart: settings.BreakdownChart.categoryMap,
        chartColours: settings.ChartColours.themeShades,
      );
      await notifier.replace(preferences);
      await harness.settle();
      final breakdown = harness.ready.breakdown;
      expect(breakdown.level, settings.BreakdownLevel.subcategories);
      expect(breakdown.chart, settings.BreakdownChart.categoryMap);
      expect(breakdown.colours, settings.ChartColours.themeShades);
      expect(breakdown.rows.length, 5);
      expect(harness.intent, before);
      await notifier.replace(
        preferences.copyWith(appearance: settings.Appearance.dark),
      );
      await harness.settle();
      expect(identical(harness.ready.breakdown, breakdown), isTrue);
    },
  );

  test(
    'metadata snapshot updates names and saved hex after coherent mutation',
    () async {
      final ledger = seededTrendsLedger(_today);
      final harness = await readyHarness(ledger: ledger, today: _today);
      final original = harness.ready.breakdown;
      final dining = ledger.state.categories.values.singleWhere(
        (category) => category.name == 'Dining',
      );
      ledger.updateCategory(
        TransactionCategory(
          id: dining.id,
          name: 'Meals',
          kind: dining.kind,
          colorHex: '#ABCDEF',
          includeInAnalysis: dining.includeInAnalysis,
          parentID: dining.parentID,
          symbol: dining.symbol,
        ),
      );
      await harness.settle();
      expect(harness.ready.breakdown.rows.first.name, 'Meals');
      expect(harness.ready.breakdown.rows.first.savedHex, '#ABCDEF');
      expect(harness.ready.breakdown.sourceRevision, ledger.revision);
      expect(original.rows.first.name, 'Dining');
      expect(original.rows.first.savedHex, '#FF9500');
    },
  );

  test(
    'unresolved IDs, null and synthetic buckets remain separate and ordered',
    () async {
      final setup = setupAnalysis(today: _today);
      final ledger = setup.ledger;
      ledger.addAccount(
        Account(
          id: checkingSourceID,
          name: 'Checking',
          type: AccountType.checking,
        ),
      );
      ledger.addCategory(
        TransactionCategory(
          id: foodCategoryID,
          name: 'Food',
          kind: CategoryKind.expense,
          colorHex: '#000000',
          includeInAnalysis: true,
          parentID: null,
          symbol: 'tag',
        ),
      );
      addTrendsEntry(ledger, '-1', _today);
      const unknownA = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
      const unknownB = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
      const synthetic = 'transfer-expense:savings';
      final items = [
        _item(unknownB, '10'),
        _item(null, '10'),
        _item(unknownA, '10'),
        _item(synthetic, '5'),
      ];
      await settle(setup.runner, ledger, items: items);
      final body = _project(setup.queries, ledger);
      expect(body, isA<TrendsReadyBody>());
      if (body is! TrendsReadyBody) return;
      final rows = body.breakdown.rows;
      final bucketIDValues = rows.map((row) => row.bucketID);
      expect(bucketIDValues, [unknownA, unknownB, null, synthetic]);
      final nameValues = rows.map((row) => row.name);
      expect(nameValues, [
        'Uncategorized',
        'Uncategorized',
        'Uncategorized',
        'Savings transfers',
      ]);
      final savedHexValues = rows.map((row) => row.savedHex);
      expect(savedHexValues, everyElement(isNull));
      final targets = rows.map((row) => row.navigationTarget?.mainID);
      expect(targets, [unknownA, unknownB, null, null]);
      expect(rows.first.mainBucketID, unknownA);
      expect(rows.first.amount, Decimal.fromInt(10));
      expect(rows.first.sharePercent, Decimal.parse('28.6'));
    },
  );

  test('initial, retained refresh, failure and retry preserve truthful body and intent', () async {
    final ledger = emptyTrendsLedger();
    addTrendsEntry(ledger, '-10', _today);
    final runner = ManualRunner();
    final harness = TrendsHarness(
      ledger: ledger,
      today: _today,
      runner: runner.call,
    );
    await harness.settle();
    expect(harness.body, isA<TrendsLoadingBody>());
    await settle(runner, ledger);
    expect(harness.ready.breakdown.total, Decimal.fromInt(10));
    final intent = harness.intent;
    final queries = harness.container.read(analysisQueriesProvider)!;
    final previous = _readBreakdown(queries);
    addTrendsEntry(ledger, '-20', _today);
    await harness.settle();
    expect(_readBreakdown(queries).value, previous.value);
    expect(harness.body, isA<TrendsLoadingBody>());
    runner.pending.last.completeError(StateError('failed'));
    await harness.settle();
    expect(harness.body, isA<TrendsErrorBody>());
    harness.viewModel.retry();
    await harness.settle();
    expect(harness.body, isA<TrendsLoadingBody>());
    await settle(runner, ledger);
    expect(harness.ready.breakdown.total, Decimal.fromInt(30));
    expect(harness.intent, intent);
  });

  test('breakdown alone gates failure, missing and stale revisions, pending and ready-null', () async {
    final fixture = await _scripted();
    final real = _readBreakdown(fixture.queries);
    final revision = fixture.ledger.revision;
    final cases = _gateCases(real.value, revision);
    for (final (read, matcher) in cases) {
      fixture.queries.replacement = read;
      expect(_project(fixture.queries, fixture.ledger), matcher);
    }
    fixture.queries.replacement = null;
    expect(_project(fixture.queries, fixture.ledger), isA<TrendsReadyBody>());
  });

  test(
    'inconsistent breakdown identity, total and empty rows produce errors',
    () async {
      final fixture = await _scripted();
      final real = _readBreakdown(fixture.queries).value!;
      final badValues = _inconsistentPayloads(real);
      for (final value in badValues) {
        fixture.queries.replacement = _result(
          value,
          AnalysisQueryState.ready,
          fixture.ledger.revision,
        );
        expect(
          _project(fixture.queries, fixture.ledger),
          isA<TrendsErrorBody>(),
        );
      }
    },
  );
  test(
    'breakdown reads wait for day alignment and use the effective clamp',
    () async {
      final fixture = await _scripted();
      final tomorrow = DateTime.utc(2026, 10, 4);
      expect(
        _project(fixture.queries, fixture.ledger, today: tomorrow),
        isA<TrendsLoadingBody>(),
      );
      expect(fixture.queries.breakdownReads, isEmpty);
      fixture.queries.setToday(tomorrow);
      final oldMonth = monthSerial(DateTime.utc(2020));
      final intent = TrendsIntent(
        kind: TrendsKind.expense,
        mode: TrendsMode.month,
        spreadEnd: oldMonth,
        selected: oldMonth,
        rememberedMonth: 1,
        followsCurrent: false,
      );
      final body = _project(
        fixture.queries,
        fixture.ledger,
        today: tomorrow,
        intent: intent,
      );
      expect(body, isA<TrendsReadyBody>());
      if (body is! TrendsReadyBody) return;
      final effective = DateTime.utc(2025, 11);
      expect(fixture.queries.breakdownReads, [effective]);
      expect(body.breakdown.period, effective);
      expect(body.breakdown.total, Decimal.zero);
      expect(intent.selected, oldMonth);
    },
  );

  test('empty ledger still requires a coherent non-null breakdown', () async {
    final fixture = await _scripted(empty: true);
    expect(_project(fixture.queries, fixture.ledger), isA<TrendsEmptyBody>());
    final real = _readBreakdown(fixture.queries);
    fixture.queries.replacement = _result(
      null,
      AnalysisQueryState.ready,
      fixture.ledger.revision,
    );
    expect(_project(fixture.queries, fixture.ledger), isA<TrendsErrorBody>());
    fixture.queries.replacement = _result(
      real.value,
      AnalysisQueryState.failed,
      fixture.ledger.revision,
    );
    expect(_project(fixture.queries, fixture.ledger), isA<TrendsErrorBody>());
    fixture.queries.replacement = _result(
      real.value,
      AnalysisQueryState.ready,
      null,
    );
    expect(_project(fixture.queries, fixture.ledger), isA<TrendsLoadingBody>());
  });

  test(
    'deletion to empty and old completion cannot publish mixed revisions',
    () async {
      final ledger = emptyTrendsLedger();
      final id = addTrendsEntry(ledger, '-10', _today);
      final runner = ManualRunner();
      final harness = TrendsHarness(
        ledger: ledger,
        today: _today,
        runner: runner.call,
      );
      await harness.settle();
      await settle(runner, ledger);
      final beforeDelete = runner.pending.length;
      ledger.deleteEntry(id);
      final emptyItems = Accounting.analysisItems(ledger.state);
      await harness.settle();
      expect(harness.body, isA<TrendsLoadingBody>());
      addTrendsEntry(ledger, '-20', _today);
      await harness.settle();
      runner.pending[beforeDelete].complete(emptyItems);
      await harness.settle();
      expect(harness.body, isA<TrendsLoadingBody>());
      await settle(runner, ledger);
      expect(harness.ready.breakdown.total, Decimal.fromInt(20));
      final next = runner.pending.length;
      addTrendsEntry(ledger, '-30', _today);
      final olderItems = Accounting.analysisItems(ledger.state);
      addTrendsEntry(ledger, '-40', _today);
      await settle(runner, ledger);
      expect(harness.ready.breakdown.total, Decimal.fromInt(90));
      runner.pending[next].complete(olderItems);
      await harness.settle();
      expect(harness.ready.breakdown.total, Decimal.fromInt(90));
      expect(harness.ready.breakdown.sourceRevision, ledger.revision);
    },
  );

  test(
    'latest level kind and period win while computation is pending',
    () async {
      SharedPreferences.setMockInitialValues({});
      final ledger = seededTrendsLedger(_today);
      final runner = ManualRunner();
      final harness = TrendsHarness(
        ledger: ledger,
        today: _today,
        runner: runner.call,
      );
      await harness.settle();
      harness.viewModel.setKind(TrendsKind.income);
      harness.viewModel.setMode(TrendsMode.year);
      harness.viewModel.selectSlot(1);
      final preferences = settings.DisplayPreferences(
        breakdownLevel: settings.BreakdownLevel.subcategories,
      );
      await harness.container
          .read(displayPreferencesProvider.notifier)
          .replace(preferences);
      await harness.settle();
      expect(harness.body, isA<TrendsLoadingBody>());
      await settle(runner, ledger);
      final breakdown = harness.ready.breakdown;
      expect(breakdown.kind, CategoryKind.income);
      expect(breakdown.mode, TrendsMode.year);
      expect(breakdown.level, settings.BreakdownLevel.subcategories);
      expect(breakdown.period, DateTime.utc(2025));
      expect(breakdown, isA<TrendsEmptyBreakdown>());
    },
  );
}

AnalysisItem _item(String? id, String amount) => AnalysisItem(
  kind: CategoryKind.expense,
  amount: Decimal.parse(amount),
  date: _today,
  bucketID: id,
);

const _preferences = (
  chart: settings.BreakdownChart.donut,
  level: settings.BreakdownLevel.categories,
  colours: settings.ChartColours.categoryColours,
);

TrendsBody _project(
  AnalysisQueries queries,
  Ledger ledger, {
  DateTime? today,
  TrendsIntent? intent,
}) => projectTrends(
  queries: queries,
  intent: intent ?? TrendsIntent.initial(_today),
  today: today ?? _today,
  ledgerRevision: ledger.revision,
  categories: const {},
  preferences: _preferences,
);

AnalysisQueryResult<analysis.PeriodBreakdown> _readBreakdown(
  AnalysisQueries queries,
) => queries.readCategoryBreakdown(
  period: DateTime.utc(2026, 10),
  mode: AnalysisPeriodMode.month,
  kind: CategoryKind.expense,
  level: analysis.BreakdownLevel.categories,
);

AnalysisQueryResult<analysis.PeriodBreakdown> _result(
  analysis.PeriodBreakdown? value,
  AnalysisQueryState state,
  int? revision,
) => AnalysisQueryResult(value: value, state: state, sourceRevision: revision);

analysis.PeriodBreakdown _payload(
  analysis.PeriodBreakdown real, {
  DateRange? window,
  CategoryKind? kind,
  analysis.BreakdownLevel? level,
  Decimal? total,
  List<analysis.BreakdownRow>? rows,
}) => analysis.PeriodBreakdown(
  window: window ?? real.window,
  kind: kind ?? real.kind,
  level: level ?? real.level,
  total: total ?? real.total,
  rows: rows ?? real.rows,
);

class _BreakdownQueries extends AnalysisQueries {
  _BreakdownQueries({
    required super.ledger,
    required super.cache,
    required super.today,
  });
  AnalysisQueryResult<analysis.PeriodBreakdown>? replacement;
  final List<DateTime> breakdownReads = [];

  @override
  AnalysisQueryResult<analysis.PeriodBreakdown> readCategoryBreakdown({
    required DateTime period,
    required AnalysisPeriodMode mode,
    required CategoryKind kind,
    required analysis.BreakdownLevel level,
  }) {
    breakdownReads.add(period);
    return replacement ??
        super.readCategoryBreakdown(
          period: period,
          mode: mode,
          kind: kind,
          level: level,
        );
  }
}

Future<({Ledger ledger, _BreakdownQueries queries})> _scripted({
  bool empty = false,
}) async {
  final ledger = emptyTrendsLedger();
  if (!empty) addTrendsEntry(ledger, '-10', _today);
  final cache = AnalysisCache(runner: syncComputeRunner)
    ..start(ledger.bus, sourceRevision: () => ledger.revision);
  final queries = _BreakdownQueries(
    ledger: ledger,
    cache: cache,
    today: _today,
  );
  addTearDown(() async {
    queries.dispose();
    await cache.dispose();
  });
  await pumpEventQueue();
  return (ledger: ledger, queries: queries);
}

List<(AnalysisQueryResult<analysis.PeriodBreakdown>, Matcher)> _gateCases(
  analysis.PeriodBreakdown? value,
  int revision,
) {
  return <(AnalysisQueryResult<analysis.PeriodBreakdown>, Matcher)>[
    (
      _result(value, AnalysisQueryState.failed, revision),
      isA<TrendsErrorBody>(),
    ),
    (
      _result(value, AnalysisQueryState.loading, revision),
      isA<TrendsLoadingBody>(),
    ),
    (_result(value, AnalysisQueryState.ready, null), isA<TrendsLoadingBody>()),
    (
      _result(value, AnalysisQueryState.ready, revision - 1),
      isA<TrendsLoadingBody>(),
    ),
    (_result(null, AnalysisQueryState.ready, revision), isA<TrendsErrorBody>()),
  ];
}

List<analysis.PeriodBreakdown> _inconsistentPayloads(
  analysis.PeriodBreakdown real,
) {
  return [
    _payload(
      real,
      window: DateRange(DateTime.utc(2026, 9), DateTime.utc(2026, 10)),
    ),
    _payload(real, kind: CategoryKind.income),
    _payload(real, level: analysis.BreakdownLevel.subcategories),
    _payload(real, total: Decimal.fromInt(999)),
    _payload(real, rows: []),
  ];
}
