import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/settings/display_preferences.dart' as settings;
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/breakdowns/compared_with_usual.dart';
import 'package:spendwise/ledger/analysis/summaries/month_spread.dart';
import 'package:spendwise/ledger/analysis/summaries/year_spread.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/charts/month_bars.dart';
import 'package:spendwise/ui/common/feedback/empty_state.dart';
import 'package:spendwise/ui/common/feedback/loading_skeleton.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_projection.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';

import '../../ledger/analysis_test_support.dart';
import '../../support/ui_test_timeout.dart';
import 'trends_test_support.dart';

final _today = DateTime.utc(2026, 10, 15);
const _scrollStep = 120.0;
const _emptyBody =
    'Record an expense to start your monthly picture and breakdown.';
final _disabledArrow = isSemantics(isButton: true, isEnabled: false);

void _expectControls() {
  for (final label in ['Expense', 'Income', 'Month by month', 'Year by year']) {
    expect(find.text(label), findsOneWidget);
  }
}

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
  AnalysisQueryResult<MonthSpread> Function(AnalysisQueryResult<MonthSpread>)?
  monthSpread;
  AnalysisQueryResult<YearSpread> Function(AnalysisQueryResult<YearSpread>)?
  yearSpread;
  AnalysisQueryResult<ComparedWithUsual> Function(
    AnalysisQueryResult<ComparedWithUsual>,
  )?
  usual;

  @override
  AnalysisQueryResult<MonthSpread> readMonthSpread({
    required DateTime endMonth,
    required CategoryKind kind,
  }) {
    reads.add('month-spread');
    final real = super.readMonthSpread(endMonth: endMonth, kind: kind);
    return monthSpread?.call(real) ?? real;
  }

  @override
  AnalysisQueryResult<YearSpread> readYearSpread({
    required int endYear,
    required CategoryKind kind,
  }) {
    reads.add('year-spread');
    final real = super.readYearSpread(endYear: endYear, kind: kind);
    return yearSpread?.call(real) ?? real;
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

TrendsIntent _yearIntent() {
  return TrendsIntent.initial(
    _today,
  ).withMode(TrendsMode.year, TrendsContext(currentMonth: monthSerial(_today)));
}

AnalysisQueryResult<MonthSpread> _spreadForOtherMonth(
  AnalysisQueryResult<MonthSpread> real,
) {
  final spread = real.value!;
  final other = MonthSpread(
    endMonth: spread.endMonth,
    kind: spread.kind,
    currentMonth: DateTime.utc(2026, 9, 1),
    earliestSpreadEndMonth: spread.earliestSpreadEndMonth,
    slots: spread.slots,
  );
  return _with(real, value: other);
}

AnalysisQueryResult<YearSpread> _spreadForOtherYear(
  AnalysisQueryResult<YearSpread> real,
) {
  final spread = real.value!;
  final other = YearSpread(
    endYear: spread.endYear,
    kind: spread.kind,
    currentYear: 2025,
    earliestSpreadEndYear: spread.earliestSpreadEndYear,
    slots: spread.slots,
  );
  return _with(real, value: other);
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

    test(
      'an older completion while newer work is pending keeps the skeleton',
      () async {
        final runner = ManualRunner();
        final ledger = _populated();
        final harness = _held(ledger, runner);
        await harness.settle();
        addTrendsEntry(ledger, '-10', DateTime.utc(2026, 10, 3));
        await harness.settle();

        runner.pending.first.complete(const <AnalysisItem>[]);
        await harness.settle();

        expect(harness.body, isA<TrendsLoadingBody>());
      },
    );
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

    test('is released when the screen providers are released', () async {
      final runner = ManualRunner();
      final ledger = _populated();
      final harness = _held(ledger, runner);
      await harness.settle();
      harness.viewModel.setMode(TrendsMode.year);

      harness.dispose();
      runner.pending.last.complete(Accounting.analysisItems(ledger.state));
      await pumpEventQueue();

      final fresh = _held(_populated(), ManualRunner());
      expect(fresh.intent.mode, TrendsMode.month);
    });

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
      harness.viewModel.selectSlot(8);
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

    test('a today behind the queries clock shows skeletons until the queries follow', () async {
      final scripted = await _scripted(DateTime.utc(2026, 10, 1));

      expect(
        scripted.project(DateTime.utc(2026, 9, 30)),
        isA<TrendsLoadingBody>(),
      );
      expect(scripted.queries.reads, isEmpty);
      scripted.queries.setToday(DateTime.utc(2026, 9, 30));
      expect(
        scripted.project(DateTime.utc(2026, 9, 30)),
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
    test('a spread without a source revision is loading', () async {
      final scripted = await _scripted(_today);
      scripted.queries.monthSpread = (real) => _with(real, revision: null);

      expect(scripted.project(_today), isA<TrendsLoadingBody>());
    });

    test('a spread from another revision is loading', () async {
      final scripted = await _scripted(_today);
      final stale = scripted.ledger.revision - 1;
      scripted.queries.monthSpread = (real) => _with(real, revision: stale);

      expect(scripted.project(_today), isA<TrendsLoadingBody>());
    });

    test('a ready spread without a payload is an error', () async {
      final scripted = await _scripted(_today);
      scripted.queries.monthSpread = (real) => _with(real, value: null);

      expect(scripted.project(_today), isA<TrendsErrorBody>());
    });

    test('a ready usual without a payload is an error', () async {
      final scripted = await _scripted(_today);
      scripted.queries.usual = (real) => _with(real, value: null);

      expect(scripted.project(_today), isA<TrendsErrorBody>());
    });

    test('a spread built for another current month is loading', () async {
      final scripted = await _scripted(_today);
      scripted.queries.monthSpread = _spreadForOtherMonth;

      expect(scripted.project(_today), isA<TrendsLoadingBody>());
    });

    test('a year spread built for another current year is loading', () async {
      final scripted = await _scripted(_today);
      scripted.queries.yearSpread = _spreadForOtherYear;

      final body = scripted.project(_today, intent: _yearIntent());

      expect(body, isA<TrendsLoadingBody>());
    });

    test('year mode does not read the monthly usual', () async {
      final scripted = await _scripted(_today);
      scripted.project(_today, intent: _yearIntent());

      expect(scripted.queries.reads, ['year-spread']);
    });
  });

  group('classification', () {
    test('an empty ledger is the empty body', () async {
      final harness = await readyHarness(
        ledger: emptyTrendsLedger(),
        today: _today,
      );

      expect(harness.body, isA<TrendsEmptyBody>());
    });

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

  group('frames', () {
    testWidgets(
      'loading keeps the header and both controls over skeletons',
      _loadingFrame,
      timeout: uiTestTimeout,
    );
    testWidgets(
      'failure shows the error copy with a filled Retry that recovers',
      _errorFrame,
      timeout: uiTestTimeout,
    );
    testWidgets(
      'a fresh ledger shows controls, a period row with both arrows off and the empty state',
      _freshFrame,
      timeout: uiTestTimeout,
    );
    testWidgets(
      'controls stay available when the provider has no value',
      _noValueFrame,
      timeout: uiTestTimeout,
    );
    testWidgets(
      'a short phone scrolls to the usual row with controls reachable',
      _shortPhoneScrolls,
      timeout: uiTestTimeout,
    );
    testWidgets(
      'a large total at 320 dp shows every digit of the amount',
      _largeTotalIsFullyShown,
      timeout: uiTestTimeout,
    );
  });
}

Future<void> _loadingFrame(WidgetTester tester) async {
  final runner = ManualRunner();

  await pumpTrends(
    tester,
    ledger: _populated(),
    today: _today,
    runner: runner.call,
    settle: false,
  );

  expect(find.text('Trends'), findsOneWidget);
  _expectControls();
  expect(find.byType(LoadingSkeleton), findsWidgets);
  expect(find.text('Retry'), findsNothing);
  expect(find.byType(MonthBars), findsNothing);
}

Future<void> _errorFrame(WidgetTester tester) async {
  final runner = ManualRunner();
  final ledger = _populated();
  await pumpTrends(
    tester,
    ledger: ledger,
    today: _today,
    runner: runner.call,
    settle: false,
  );
  runner.pending.last.completeError(StateError('compute failed'));
  await tester.pumpAndSettle();

  expect(find.text("Couldn't load your spending"), findsOneWidget);
  expect(find.text('Please try again.'), findsOneWidget);
  expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  _expectControls();

  await tester.tap(find.text('Retry'));
  await tester.pump();
  runner.pending.last.complete(Accounting.analysisItems(ledger.state));
  await tester.pumpAndSettle();

  expect(find.byType(MonthBars), findsOneWidget);
  _expectControls();
}

Future<void> _freshFrame(WidgetTester tester) async {
  final semantics = tester.ensureSemantics();

  await pumpTrends(tester, ledger: emptyTrendsLedger(), today: _today);

  _expectControls();
  expect(find.text('Nov 2025 - Oct 2026'), findsOneWidget);
  expect(find.text('See where your money goes'), findsOneWidget);
  expect(find.text(_emptyBody), findsOneWidget);
  expect(find.byType(EmptyState), findsOneWidget);
  expect(find.byType(MonthBars), findsNothing);
  expect(find.textContaining('Compared with usual'), findsNothing);
  expect(find.textContaining('S\$'), findsNothing);
  final previous = tester.getSemantics(find.bySemanticsLabel('Previous'));
  final next = tester.getSemantics(find.bySemanticsLabel('Next'));
  expect(previous, _disabledArrow);
  expect(next, _disabledArrow);

  await tester.tap(find.text('Year by year'));
  await tester.pumpAndSettle();
  expect(find.text('2024 - 2026'), findsOneWidget);
  semantics.dispose();
}

Future<void> _noValueFrame(WidgetTester tester) async {
  await pumpTrends(tester, ledger: null, today: _today);

  _expectControls();
  expect(find.text("Couldn't load your spending"), findsOneWidget);
  expect(find.byType(MonthBars), findsNothing);
}

Future<void> _shortPhoneScrolls(WidgetTester tester) async {
  await pumpTrends(
    tester,
    ledger: _populated(),
    today: _today,
    size: trendsShortPhoneSize,
  );

  await tester.scrollUntilVisible(
    find.textContaining('Compared with usual'),
    _scrollStep,
    scrollable: find.byType(Scrollable).first,
  );
  expect(find.textContaining('Compared with usual'), findsOneWidget);
  await tester.ensureVisible(find.text('Year by year'));
  await tester.tap(find.text('Year by year'));
  await tester.pumpAndSettle();
  expect(find.textContaining('Compared with usual'), findsNothing);
  expect(find.text('2024 - 2026'), findsOneWidget);
}

Future<void> _largeTotalIsFullyShown(WidgetTester tester) async {
  final ledger = emptyTrendsLedger();
  addTrendsEntry(ledger, '-123456789.12', DateTime.utc(2026, 10, 2));

  await pumpTrends(tester, ledger: ledger, today: _today);

  final amount = find.text('-S\$123,456,789.12');
  expect(amount, findsOneWidget);
  expect(tester.renderObject<RenderParagraph>(amount).didExceedMaxLines, false);
  final page = tester.getRect(find.byType(Scaffold));
  expect(tester.getRect(amount).left, greaterThanOrEqualTo(page.left));
  expect(tester.getRect(amount).right, lessThanOrEqualTo(page.right));
  expect(tester.takeException(), isNull);
}
