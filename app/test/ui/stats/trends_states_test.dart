import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/settings/display_preferences.dart' as settings;
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/breakdowns/category_breakdown.dart'
    as analysis;
import 'package:spendwise/ledger/analysis/breakdowns/compared_with_usual.dart';
import 'package:spendwise/ledger/analysis/breakdowns/scoped_trend.dart';
import 'package:spendwise/ledger/analysis/summaries/trends_period.dart';
import 'package:spendwise/ledger/analysis/summaries/year_spread.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_projection.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';

import '../../ledger/analysis_test_support.dart';
import 'trends_test_support.dart';

final _today = DateTime.utc(2026, 10, 15);

Ledger _populated() {
  final ledger = emptyTrendsLedger();
  addTrendsEntry(ledger, '-40', DateTime.utc(2026, 7, 4));
  addTrendsEntry(ledger, '-25', DateTime.utc(2026, 10, 2));
  return ledger;
}

TrendsHarness _held(Ledger ledger, ManualRunner runner, {DateTime? today}) {
  return TrendsHarness(
    ledger: ledger,
    today: today ?? _today,
    runner: runner.call,
  );
}

Future<void> _finish(ManualRunner runner, Ledger ledger) =>
    settle(runner, ledger);

Future<void> _failLatest(ManualRunner runner) async {
  runner.pending.last.completeError(StateError('compute failed'));
  await pumpEventQueue();
}

class _ScriptedQueries extends AnalysisQueries {
  _ScriptedQueries({
    required super.ledger,
    required super.cache,
    required super.today,
  });

  final List<String> reads = [];
  AnalysisQueryResult<TrendsPeriod> Function(AnalysisQueryResult<TrendsPeriod>)?
  trendsPeriod;
  AnalysisQueryResult<ComparedWithUsual> Function(
    AnalysisQueryResult<ComparedWithUsual>,
  )?
  usual;

  @override
  AnalysisQueryResult<TrendsPeriod> readTrendsPeriod({
    required DateTime endPeriod,
    required AnalysisPeriodMode mode,
    required CategoryKind kind,
    required analysis.BreakdownLevel level,
  }) {
    reads.add('trends-period');
    final real = super.readTrendsPeriod(
      endPeriod: endPeriod,
      mode: mode,
      kind: kind,
      level: level,
    );
    return trendsPeriod?.call(real) ?? real;
  }

  @override
  AnalysisQueryResult<ComparedWithUsual> readComparedWithUsual({
    required DateTime month,
    required CategoryKind kind,
  }) {
    reads.add('usual');
    final real = super.readComparedWithUsual(month: month, kind: kind);
    return usual?.call(real) ?? real;
  }
}

class _Scripted {
  _Scripted(this.ledger, this.queries);

  final Ledger ledger;
  final _ScriptedQueries queries;

  TrendsBody project(DateTime today, {TrendsIntent? intent}) {
    return projectTrends(
      queries: queries,
      intent: intent ?? TrendsIntent.initial(today),
      today: today,
      ledgerRevision: ledger.revision,
      categories: const {},
      preferences: (
        chart: settings.BreakdownChart.donut,
        level: settings.BreakdownLevel.categories,
        colours: settings.ChartColours.categoryColours,
      ),
    );
  }
}

Future<_Scripted> _scripted(DateTime queriesToday) async {
  final ledger = _populated();
  final cache = AnalysisCache(runner: syncComputeRunner)
    ..start(ledger.bus, sourceRevision: () => ledger.revision);
  final queries = _ScriptedQueries(
    ledger: ledger,
    cache: cache,
    today: queriesToday,
  );
  addTearDown(() async {
    queries.dispose();
    await cache.dispose();
  });
  await pumpEventQueue();
  return _Scripted(ledger, queries);
}

AnalysisQueryResult<T> _with<T>(
  AnalysisQueryResult<T> real, {
  Object? value = _keep,
  int? revision = -1,
}) {
  return AnalysisQueryResult<T>(
    value: identical(value, _keep) ? real.value : value as T?,
    state: AnalysisQueryState.ready,
    sourceRevision: revision == -1 ? real.sourceRevision : revision,
  );
}

const _keep = Object();

AnalysisQueryResult<TrendsPeriod> _summaryForOtherYear(
  AnalysisQueryResult<TrendsPeriod> real,
) {
  final summary = real.value! as YearTrendsPeriod;
  final spread = summary.spread;
  final otherSpread = YearSpread(
    endYear: spread.endYear,
    kind: spread.kind,
    currentYear: 2025,
    earliestSpreadEndYear: spread.earliestSpreadEndYear,
    slots: spread.slots,
  );
  final other = YearTrendsPeriod(
    today: summary.today,
    firstRecordMonth: summary.firstRecordMonth,
    breakdown: summary.breakdown,
    averages: summary.averages,
    spread: otherSpread,
    highestYear: summary.highestYear,
  );
  return _with(real, value: other);
}

TrendsIntent _yearIntent() {
  return TrendsIntent.initial(
    _today,
  ).withMode(TrendsMode.year, TrendsContext(currentMonth: monthSerial(_today)));
}

void main() {
  group('loading and refresh', () {
    test('initial computation shows the skeleton body', () async {
      final runner = ManualRunner();
      final harness = _held(_populated(), runner);
      await harness.settle();

      expect(harness.body, isA<TrendsLoadingBody>());
    });

    test('a mutation drops the previous content until the new revision is computed', () async {
      final runner = ManualRunner();
      final ledger = _populated();
      final harness = _held(ledger, runner);
      await _finish(runner, ledger);
      expect(harness.body, isA<TrendsReadyBody>());

      addTrendsEntry(ledger, '-10', DateTime.utc(2026, 10, 3));
      await harness.settle();
      expect(harness.body, isA<TrendsLoadingBody>());

      await _finish(runner, ledger);
      expect(harness.ready.headline.amount, '-S\$35.00');
    });

    test('deleting the last record never shows the empty ledger before the refresh lands', () async {
      final runner = ManualRunner();
      final ledger = emptyTrendsLedger();
      final id = addTrendsEntry(ledger, '-10', DateTime.utc(2026, 10, 3));
      final harness = _held(ledger, runner);
      await _finish(runner, ledger);
      expect(harness.body, isA<TrendsReadyBody>());

      ledger.archiveEntry(id);
      await harness.settle();
      expect(harness.body, isA<TrendsLoadingBody>());

      await _finish(runner, ledger);
      expect(harness.body, isA<TrendsEmptyBody>());
    });

    test('a newer result is not overwritten by an older completion', () async {
      final runner = ManualRunner();
      final ledger = _populated();
      final harness = _held(ledger, runner);
      await harness.settle();
      addTrendsEntry(ledger, '-10', DateTime.utc(2026, 10, 3));
      await harness.settle();

      runner.pending.last.complete(Accounting.analysisItems(ledger.state));
      await harness.settle();
      final newer = harness.ready.headline.amount;
      runner.pending.first.complete(const <AnalysisItem>[]);
      await harness.settle();

      expect(newer, '-S\$35.00');
      expect(harness.ready.headline.amount, '-S\$35.00');
    });
  });

  group('failure and retry', () {
    test('a failed computation shows the error body and Retry recovers without changing intent', () async {
      final runner = ManualRunner();
      final ledger = _populated();
      final harness = _held(ledger, runner);
      await harness.settle();
      harness.viewModel.setKind(TrendsKind.income);
      await _failLatest(runner);
      final before = harness.intent;
      expect(harness.body, isA<TrendsErrorBody>());

      harness.viewModel.retry();
      await harness.settle();
      expect(harness.body, isA<TrendsLoadingBody>());
      await _finish(runner, ledger);

      expect(harness.body, isA<TrendsReadyBody>());
      expect(harness.intent, before);
    });
  });

  group('intent', () {
    test(
      'survives mutations, refreshes, retry and a same-month day change',
      () async {
        final runner = ManualRunner();
        final ledger = _populated();
        final harness = _held(ledger, runner);
        await _finish(runner, ledger);
        harness.viewModel.selectSlot(8);
        harness.viewModel.previousPage();
        harness.viewModel.setKind(TrendsKind.income);
        harness.viewModel.setMode(TrendsMode.year);
        await harness.settle();
        final snapshot = harness.intent;

        addTrendsEntry(ledger, '5', DateTime.utc(2026, 10, 4));
        await _finish(runner, ledger);
        harness.viewModel.retry();
        await harness.setToday(DateTime.utc(2026, 10, 16));

        expect(harness.intent, snapshot);
      },
    );

    test(
      'a kind or mode change while loading is what the refreshed body presents',
      () async {
        final runner = ManualRunner();
        final ledger = _populated();
        final harness = _held(ledger, runner);
        await harness.settle();

        harness.viewModel.setMode(TrendsMode.year);
        harness.viewModel.setKind(TrendsKind.income);
        await harness.settle();
        harness.viewModel.setKind(TrendsKind.expense);
        await _finish(runner, ledger);

        expect(harness.ready.headline.title, '2026');
        expect(harness.ready.headline.sublabel, 'Spent');
      },
    );

    test(
      'a retired session completing later does not reach a new screen',
      () async {
        final oldRunner = ManualRunner();
        final oldLedger = _populated();
        final old = _held(oldLedger, oldRunner);
        await old.settle();
        old.dispose();

        final newRunner = ManualRunner();
        final newLedger = _populated();
        final current = _held(newLedger, newRunner);
        await current.settle();
        oldRunner.pending.last.complete(
          Accounting.analysisItems(oldLedger.state),
        );
        await pumpEventQueue();

        expect(current.body, isA<TrendsLoadingBody>());
        await _finish(newRunner, newLedger);
        expect(current.body, isA<TrendsReadyBody>());
      },
    );
  });

  group('day alignment', () {
    test('followsCurrent advances the displayed period at rollover without rewriting intent', () async {
      final ledger = _populated();
      final harness = await readyHarness(ledger: ledger, today: _today);
      final before = harness.intent;

      await harness.setToday(DateTime.utc(2026, 11, 2));

      expect(harness.ready.headline.title, 'November 2026');
      expect(harness.intent, before);
    });

    test('a pinned selection stays on its month through rollover', () async {
      final ledger = _populated();
      final harness = await readyHarness(ledger: ledger, today: _today);
      harness.viewModel.selectSlot(6);
      await harness.settle();

      await harness.setToday(DateTime.utc(2026, 11, 2));

      expect(harness.ready.headline.title, 'July 2026');
    });

    test('a today ahead of the queries clock shows skeletons and reads nothing future-sensitive', () async {
      final scripted = await _scripted(DateTime.utc(2026, 9, 30));

      final body = scripted.project(DateTime.utc(2026, 10, 1));

      expect(body, isA<TrendsLoadingBody>());
      expect(scripted.queries.reads, isEmpty);
      scripted.queries.setToday(DateTime.utc(2026, 10, 1));
      expect(
        scripted.project(DateTime.utc(2026, 10, 1)),
        isA<TrendsReadyBody>(),
      );
    });

    test('a year boundary mismatch is loading, not an error', () async {
      final scripted = await _scripted(DateTime.utc(2026, 12, 31));

      final body = scripted.project(DateTime.utc(2027, 1, 1));

      expect(body, isA<TrendsLoadingBody>());
    });
  });

  group('coherence', () {
    test('a ready usual without a payload is an error', () async {
      final scripted = await _scripted(_today);
      scripted.queries.usual = (real) => _with(real, value: null);

      expect(scripted.project(_today), isA<TrendsErrorBody>());
    });

    test('a year spread built for another current year is loading', () async {
      final scripted = await _scripted(_today);
      scripted.queries.trendsPeriod = _summaryForOtherYear;

      final body = scripted.project(_today, intent: _yearIntent());

      expect(body, isA<TrendsLoadingBody>());
    });

    test('year mode does not read the monthly usual', () async {
      final scripted = await _scripted(_today);
      scripted.project(_today, intent: _yearIntent());

      expect(scripted.queries.reads, ['trends-period']);
    });
  });

  group('classification', () {
    test(
      'an empty ledger month carries selectable zero data and navigation',
      () async {
        final harness = await readyHarness(
          ledger: emptyTrendsLedger(),
          today: _today,
        );

        final body = harness.body as TrendsEmptyBody;
        expect(body.bars, hasLength(12));
        expect(body.selectedIndex, 9);
        expect(body.headline?.title, 'October 2026');
        expect(body.headline?.emptyMessage, 'No expenses recorded');
        expect(body.usual?.body, 'Not enough data');
        expect(body.period.previousEnabled, isTrue);
        expect(body.period.nextEnabled, isTrue);

        harness.viewModel.selectSlot(11);
        await harness.settle();
        final selectedBody = harness.body as TrendsEmptyBody;
        expect(harness.intent.selected, monthSerial(DateTime.utc(2026, 12)));
        expect(selectedBody.headline?.emptyMessage, 'No expenses recorded');

        harness.viewModel.nextPage();
        await harness.settle();
        expect(harness.intent.selected, monthSerial(DateTime.utc(2027, 12)));
      },
    );

    test('a selected kind with no records is a normal period view', () async {
      final harness = await readyHarness(ledger: _populated(), today: _today);

      harness.viewModel.setKind(TrendsKind.income);
      await harness.settle();

      expect(harness.ready.headline.emptyMessage, 'No income recorded');
    });

    test('a missing session surfaces the ledger-backed StateError', () async {
      final container = ProviderContainer(
        overrides: [ledgerProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      container.listen(trendsViewModelProvider, (_, _) {});

      final state = container.read(trendsViewModelProvider);

      expect(state.hasError, isTrue);
      expect(state.error, isA<StateError>());
    });
  });
}
