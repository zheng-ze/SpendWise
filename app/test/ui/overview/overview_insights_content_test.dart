import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/seed_data.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/overview/overview_insights_mapping.dart';
import 'package:spendwise/ui/overview/overview_slots.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';

import 'overview_fixture.dart';

const _diningID = '66666666-6666-4666-8666-666666666666';

final _today = DateTime.utc(2026, 11, 18);
final _observedDay = DateTime.utc(2026, 11, 16);
final _laterDay = DateTime.utc(2026, 11, 17);
final _monthStarts = [
  DateTime.utc(2026, 8, 5),
  DateTime.utc(2026, 9, 5),
  DateTime.utc(2026, 10, 5),
];

int _entryCount = 0;

typedef _RowLine = (String, String, String, AmountKind);

class _GatedRunner {
  bool holding = false;
  bool failing = false;
  final _never = Completer<List<AnalysisItem>>();

  Future<List<AnalysisItem>> call(LedgerState state) {
    if (failing) return Future.error(StateError('boom'));
    if (holding) return _never.future;
    return syncComputeRunner(state);
  }
}

Entry _expense(String amount, DateTime date, {String? categoryID}) =>
    entry(++_entryCount, '-$amount', date, categoryID: categoryID);

LedgerState _stateWithDining() {
  final state = emptyState();
  state.addCategory(
    TransactionCategory(
      id: _diningID,
      name: 'Dining',
      kind: CategoryKind.expense,
      colorHex: '#AA5500',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    ),
  );
  return state;
}

void _addMonthHistory(LedgerState state, String? categoryID, String amount) {
  for (final day in _monthStarts) {
    state.addEntry(_expense(amount, day, categoryID: categoryID));
    state.addEntry(_expense(amount, day, categoryID: categoryID));
  }
}

void _addObserved(LedgerState state, String? categoryID, String amount) {
  state.addEntry(_expense(amount, _observedDay, categoryID: categoryID));
}

LedgerState _weekHistoryState() {
  final state = emptyState();
  final days = [
    (DateTime.utc(2026, 10, 26), '10.00'),
    (DateTime.utc(2026, 10, 27), '10.00'),
    (DateTime.utc(2026, 11, 2), '15.00'),
    (DateTime.utc(2026, 11, 3), '15.00'),
    (DateTime.utc(2026, 11, 9), '20.00'),
    (DateTime.utc(2026, 11, 10), '20.00'),
  ];
  for (final (day, amount) in days) {
    state.addEntry(_expense(amount, day));
  }
  return state;
}

LedgerState _emptyBaselineState() {
  final state = _stateWithDining();
  _addMonthHistory(state, groceriesID, '10.00');
  _addObserved(state, groceriesID, '20.00');
  return state;
}

ProviderContainer _listen(
  Ledger ledger, {
  ComputeRunner runner = syncComputeRunner,
  DateTime? today,
}) {
  final container = overviewContainer(
    ledger,
    runner: runner,
    clock: () => today ?? _today,
  );
  container.listen(overviewViewModelProvider, (_, _) {});
  return container;
}

Future<ProviderContainer> _open(
  Ledger ledger, {
  ComputeRunner runner = syncComputeRunner,
  DateTime? today,
}) async {
  final container = _listen(ledger, runner: runner, today: today);
  await settleAnalysis(container, ledger);
  return container;
}

OverviewViewState _view(ProviderContainer container) =>
    container.read(overviewViewModelProvider).requireValue;

Future<OverviewViewState> _settled(LedgerState state, {DateTime? today}) async {
  final container = await _open(Ledger(state: state), today: today);
  return _view(container);
}

Widget? _insightsSlot(ProviderContainer container) => overviewSlotFor(
  OverviewWidgetKind.insights,
  viewState: _view(container),
  viewModel: container.read(overviewViewModelProvider.notifier),
);

List<_RowLine> _lines(OverviewViewState viewState) {
  final insights = viewState.insights;
  if (insights is! OverviewInsightsAvailable) {
    throw StateError('Insights are not available: $insights');
  }
  return [
    for (final row in insights.rows)
      (row.lead, row.amount, row.tail, row.amountKind),
  ];
}

OverviewWeekAvailable _week(OverviewViewState viewState) {
  final week = viewState.weekSoFar;
  if (week is! OverviewWeekAvailable) {
    throw StateError('Week so far is not available: $week');
  }
  return week;
}

Future<ProviderContainer> _settledEmpty(
  Ledger ledger,
  _GatedRunner runner,
) async {
  final container = await _open(ledger, runner: runner.call);
  final viewState = _view(container);
  expect(viewState.insights, isA<OverviewInsightsAvailable>());
  expect(viewState.insightsSettledEmpty, isTrue);
  return container;
}

void main() {
  group('Insights', () {
    test('a higher and a lower change give exact rows and kinds', () async {
      final state = _stateWithDining();
      _addMonthHistory(state, groceriesID, '10.00');
      _addMonthHistory(state, _diningID, '40.00');
      _addObserved(state, groceriesID, '120.00');
      _addObserved(state, _diningID, '60.00');

      final viewState = await _settled(state);

      expect(_lines(viewState), [
        (
          'Groceries is ',
          r'S$100.00',
          ' higher than your usual start.',
          AmountKind.expense,
        ),
        (
          'Dining is ',
          r'S$20.00',
          ' lower than your usual start.',
          AmountKind.income,
        ),
      ]);
      expect(viewState.insightsSettledEmpty, isFalse);
    });

    test(
      'three qualifying buckets keep the top two incl. Uncategorized',
      () async {
        final state = _stateWithDining();
        _addMonthHistory(state, groceriesID, '10.00');
        _addMonthHistory(state, _diningID, '40.00');
        _addMonthHistory(state, null, '30.00');
        _addObserved(state, groceriesID, '120.00');
        _addObserved(state, _diningID, '60.00');
        _addObserved(state, null, '330.00');

        final viewState = await _settled(state);

        expect(_lines(viewState), [
          (
            'Uncategorized is ',
            r'S$270.00',
            ' higher than your usual start.',
            AmountKind.expense,
          ),
          (
            'Groceries is ',
            r'S$100.00',
            ' higher than your usual start.',
            AmountKind.expense,
          ),
        ]);
      },
    );

    test('a complete baseline with nothing qualifying has no rows', () async {
      final container = await _open(Ledger(state: _emptyBaselineState()));
      final viewState = _view(container);

      expect(viewState.insights, isA<OverviewInsightsAvailable>());
      expect(_lines(viewState), isEmpty);
      expect(viewState.insightsSettledEmpty, isTrue);
      expect(viewState.insightsFailed, isFalse);
      expect(_insightsSlot(container), isNull);
    });
  });

  group('Week so far', () {
    test('qualifying week gives range, total, comparison and note', () async {
      final state = _weekHistoryState();
      state.addEntry(_expense('150.00', _observedDay));

      final week = _week(await _settled(state));

      expect(week.range, '16 Nov - 18 Nov / 3 days');
      expect(week.total, r'S$150.00');
      expect(week.comparison, r'S$120.00 more than usual');
      expect(week.totalTone, AmountKind.expense);
      expect(
        week.usualNote,
        r'Usual is S$30.00, the average of S$20.00, S$30.00 and S$40.00 '
        'over the same days of the last three weeks.',
      );
    });

    test('a week close to usual has no comparison', () async {
      final state = _weekHistoryState();
      state.addEntry(_expense('30.00', _observedDay));

      final week = _week(await _settled(state));

      expect(week.total, r'S$30.00');
      expect(week.comparison, isNull);
      expect(week.totalTone, isNull);
    });

    test('fewer than three complete prior weeks needs history', () async {
      final state = emptyState();
      state.addEntry(_expense('30.00', DateTime.utc(2026, 11, 10)));
      state.addEntry(_expense('30.00', _observedDay));

      final viewState = await _settled(state);

      expect(viewState.weekSoFar, isA<OverviewWeekHistoryNeeded>());
    });
  });

  group('Seed ledger', () {
    test('needs history for both cards', () async {
      final state = LedgerState();
      buildSeed(state, today: fixtureToday);

      final container = await _open(Ledger(state: state), today: fixtureToday);
      final viewState = _view(container);

      expect(viewState.insights, isA<OverviewInsightsHistoryNeeded>());
      expect(viewState.insightsSettledEmpty, isFalse);
      expect(_insightsSlot(container), isNotNull);
      expect(viewState.weekSoFar, isA<OverviewWeekHistoryNeeded>());
    });
  });

  group('Insights settled-empty (D5)', () {
    test('stays settled-empty while a refresh is pending', () async {
      final ledger = Ledger(state: _emptyBaselineState());
      final runner = _GatedRunner();
      final container = await _settledEmpty(ledger, runner);

      runner.holding = true;
      ledger.addEntry(_expense('5.00', _laterDay));
      await pumpEventQueue();

      final viewState = _view(container);
      expect(viewState.insights, isNull);
      expect(viewState.insightsSettledEmpty, isTrue);
      expect(_insightsSlot(container), isNull);
    });

    test('is not settled-empty when nothing has ever settled', () async {
      final runner = _GatedRunner()..holding = true;
      final container = _listen(
        Ledger(state: _emptyBaselineState()),
        runner: runner.call,
      );
      await pumpEventQueue();

      final viewState = _view(container);

      expect(viewState.insights, isNull);
      expect(viewState.insightsSettledEmpty, isFalse);
      expect(_insightsSlot(container), isNotNull);
    });

    test('a failed refresh shows failure, not settled-empty', () async {
      final ledger = Ledger(state: _emptyBaselineState());
      final runner = _GatedRunner();
      final container = await _settledEmpty(ledger, runner);

      runner.failing = true;
      ledger.addEntry(_expense('5.00', _laterDay));
      await pumpEventQueue();

      final viewState = _view(container);
      expect(viewState.insightsFailed, isTrue);
      expect(viewState.insightsSettledEmpty, isFalse);
      expect(_insightsSlot(container), isNotNull);
    });
  });
}
