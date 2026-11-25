import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/boot/seed_data.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_month.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';

import 'overview_fixture.dart';

Future<OverviewViewState> _settled(Ledger ledger) async {
  final container = overviewContainer(ledger);
  container.listen(overviewViewModelProvider, (_, _) {});
  await settleAnalysis(container, ledger);
  return container.read(overviewViewModelProvider).requireValue;
}

const _unscopedLimit = '1200';
const _budgetWatchRowCount = 3;
final _seedLimits = {'Dining': '350', 'Groceries': '450', 'Transport': '120'};

String _categoryID(LedgerState state, String name) =>
    state.categories.values.firstWhere((c) => c.name == name).id;

LedgerState _seedWithBudgets(Map<String, String> limits) {
  final state = LedgerState();
  buildSeed(state, today: fixtureToday);
  for (final MapEntry(:key, :value) in limits.entries) {
    state.addBudget(_categoryID(state, key), Decimal.parse(value));
  }
  return state;
}

Future<List<String>> _watchNames(LedgerState state) async {
  final watch = (await _settled(Ledger(state: state))).budgetWatch!;
  return [for (final card in watch) card.name];
}

void main() {
  group('Today', () {
    test('maps spent and the daily guide from the unscoped budget', () async {
      final viewState = await _settled(Ledger(state: defaultState()));

      final today = viewState.today!;
      expect(today.spent, Decimal.parse('45.70'));
      expect(today.monthlyCap, Decimal.parse('1200'));
      expect(today.dailyGuide, Decimal.parse('39'));
      expect(viewState.recordedToday, isTrue);
    });

    test('has no cap or guide without an unscoped budget', () async {
      final state = emptyState();
      state.addEntry(entry(1, '-5.00', fixtureToday, categoryID: groceriesID));

      final today = (await _settled(Ledger(state: state))).today!;

      expect(today.monthlyCap, isNull);
      expect(today.dailyGuide, isNull);
    });

    test('stays pending while analysis computes and rows still show', () async {
      final ledger = Ledger(state: defaultState());
      final pending = Completer<List<AnalysisItem>>();
      final container = overviewContainer(
        ledger,
        runner: (_) => pending.future,
      );
      container.listen(overviewViewModelProvider, (_, _) {});
      await pumpEventQueue();

      final viewState = container.read(overviewViewModelProvider).requireValue;

      expect(viewState.today, isNull);
      expect(viewState.thisMonth, isNull);
      expect(viewState.budgetWatch, isNull);
      expect(viewState.recent, isNotEmpty);
      expect(viewState.upcoming, isNotEmpty);
    });
  });

  group('Budget watch', () {
    test('lists category budgets with the Budgets list strings', () async {
      final state = _seedWithBudgets(_seedLimits);
      state.addBudget(null, Decimal.parse(_unscopedLimit));

      final watch = (await _settled(Ledger(state: state))).budgetWatch!;

      expect(
        [for (final card in watch) card.name],
        ['Dining', 'Groceries', 'Transport'],
      );
      expect(watch[0].amounts, 'S\$83.90 of S\$350.00');
      expect(watch[0].status, 'S\$266.10 left / 24.0% used');
      expect(watch[1].status, endsWith('16.3% used'));
      expect(watch[2].status, endsWith('8.3% used'));
    });

    test('keeps only the top three category budgets', () async {
      final state = _seedWithBudgets({..._seedLimits, 'Salary': '5000'});

      final names = await _watchNames(state);

      expect(names, hasLength(_budgetWatchRowCount));
      expect(names, isNot(contains('Salary')));
    });

    test('reads today month even when the Budgets month is changed', () async {
      final ledger = Ledger(state: _seedWithBudgets(_seedLimits));
      final container = overviewContainer(ledger);
      container.listen(overviewViewModelProvider, (_, _) {});
      container.listen(budgetsMonthChoiceProvider, (_, _) {});
      container.read(budgetsMonthChoiceProvider.notifier).state = DateTime.utc(
        2026,
        3,
      );
      await settleAnalysis(container, ledger);

      final watch = container
          .read(overviewViewModelProvider)
          .requireValue
          .budgetWatch!;

      expect(watch.first.amounts, 'S\$83.90 of S\$350.00');
    });

    test('an unscoped budget alone yields an empty list', () async {
      final state = _seedWithBudgets({});
      state.addBudget(null, Decimal.parse(_unscopedLimit));

      expect(await _watchNames(state), isEmpty);
    });

    test('no budgets yields an empty list', () async {
      expect(await _watchNames(_seedWithBudgets({})), isEmpty);
    });
  });

  group('Today freshness', () {
    test(
      'shows Today as loading until it catches up with the ledger',
      () async {
        final ledger = Ledger(state: emptyState());
        final pending = Completer<List<AnalysisItem>>();
        var calls = 0;
        final container = overviewContainer(
          ledger,
          runner: (state) =>
              ++calls == 1 ? syncComputeRunner(state) : pending.future,
        );
        container.listen(overviewViewModelProvider, (_, _) {});
        await settleAnalysis(container, ledger);

        ledger.addEntry(
          entry(1, '-5.00', fixtureToday, categoryID: groceriesID),
        );
        await pumpEventQueue();

        final viewState = container
            .read(overviewViewModelProvider)
            .requireValue;
        expect(viewState.recent, hasLength(1));
        expect(viewState.today, isNull);
        expect(viewState.thisMonth, isNull);
      },
    );
  });

  group('This month', () {
    test('sums the seed month into caption and signed figures', () async {
      final state = LedgerState();
      buildSeed(state, today: fixtureToday);

      final month = (await _settled(Ledger(state: state))).thisMonth!;

      expect(month.caption, 'October');
      expect(month.figures!.spent, '-167.40');
      expect(month.figures!.income, '+3,200.00');
      expect(month.figures!.net, '+3,032.60');
      expect(month.figures!.netKind, AmountKind.income);
    });

    test('counts only the current month, dated ahead included', () async {
      final state = emptyState();
      state.addEntry(entry(1, '-10.00', DateTime.utc(2026, 9, 30)));
      state.addEntry(entry(2, '-25.00', DateTime.utc(2026, 10, 20)));
      state.addEntry(entry(3, '-7.00', DateTime.utc(2026, 11, 1)));
      state.addEntry(
        entry(
          4,
          '500.00',
          DateTime.utc(2026, 10, 12),
          destinationID: savingsID,
        ),
      );
      state.addEntry(
        entry(5, '-1200.00', DateTime.utc(2026, 11, 3), name: 'Rent'),
      );

      final figures = (await _settled(Ledger(state: state)))
          .thisMonth!
          .figures!;

      expect(figures.spent, '-25.00');
      expect(figures.income, '0.00');
      expect(figures.net, '-25.00');
    });

    test('an empty month has a caption and no figures', () async {
      final month = (await _settled(Ledger(state: emptyState()))).thisMonth!;

      expect(month.caption, 'October');
      expect(month.figures, isNull);
    });

    test('a transfer-only month still shows zero figures', () async {
      final state = emptyState();
      state.addEntry(
        entry(
          1,
          '500.00',
          DateTime.utc(2026, 10, 12),
          destinationID: savingsID,
        ),
      );

      final figures = (await _settled(Ledger(state: state)))
          .thisMonth!
          .figures!;

      expect(figures.spent, '0.00');
      expect(figures.income, '0.00');
      expect(figures.net, '0.00');
      expect(figures.netKind, AmountKind.transfer);
    });
  });

  group('Recent entries', () {
    test('lists at most four, newest first', () async {
      final viewState = await _settled(Ledger(state: defaultState()));

      expect(viewState.recent!.map((row) => row.title), [
        'Snack',
        'Shop run',
        'To savings',
        'Monthly pay',
      ]);
    });

    test('excludes entries dated after today and keeps older ones', () async {
      final state = emptyState();
      state.addEntry(
        entry(1, '-8.00', DateTime.utc(2026, 10, 2), name: 'Older'),
      );
      state.addEntry(
        entry(2, '-9.00', DateTime.utc(2026, 10, 4), name: 'Ahead'),
      );

      final viewState = await _settled(Ledger(state: state));

      expect(viewState.recent!.map((row) => row.title), ['Older']);
      expect(viewState.recent!.single.caption, startsWith('2 Oct / '));
      expect(viewState.recordedToday, isFalse);
    });

    test('maps caption, signed amount and kind for each entry shape', () async {
      final viewState = await _settled(Ledger(state: defaultState()));
      final byTitle = {for (final row in viewState.recent!) row.title: row};

      final pay = byTitle['Monthly pay']!;
      expect(pay.caption, 'Today / Salary / Checking');
      expect(pay.amountKind, AmountKind.income);
      expect(pay.amount, Decimal.parse('3200.00'));
      final transfer = byTitle['To savings']!;
      expect(transfer.caption, 'Today / Transfer / Checking > Savings');
      expect(transfer.amountKind, AmountKind.transfer);
      final spend = byTitle['Shop run']!;
      expect(spend.caption, 'Today / Groceries / Amex Card');
      expect(spend.amountKind, AmountKind.expense);
      expect(spend.amount, Decimal.parse('-42.50'));
    });

    test('follows ledger changes', () async {
      final ledger = Ledger(state: defaultState());
      final container = overviewContainer(ledger);
      container.listen(overviewViewModelProvider, (_, _) {});
      await settleAnalysis(container, ledger);

      ledger.addEntry(entry(9, '-1.00', fixtureToday, name: 'Newest'));
      await settleAnalysis(container, ledger);

      final viewState = container.read(overviewViewModelProvider).requireValue;
      expect(viewState.recent!.first.title, 'Newest');
      expect(viewState.today!.spent, Decimal.parse('46.70'));
    });
  });

  group('Coming up', () {
    test('merges statement, plans and dated-ahead entries by date', () async {
      final viewState = await _settled(Ledger(state: defaultState()));

      expect(
        viewState.upcoming!.map(
          (row) => (row.day, row.month, row.title, row.caption),
        ),
        [
          (
            '15',
            'Oct',
            'Amex Card statement closes',
            'This cycle so far: S\$45.70',
          ),
          ('20', 'Oct', 'Streaming', 'Plan / Amex Card'),
          ('25', 'Oct', 'Wages', 'Plan / Checking'),
          ('3', 'Nov', 'Rent', 'Dated ahead / Checking'),
        ],
      );
    });

    test(
      'statement rows carry no amount and plans carry a signed one',
      () async {
        final rows = (await _settled(Ledger(state: defaultState()))).upcoming!;

        expect(rows.first.amount, isNull);
        expect(rows[1].amount, Decimal.parse('-19.98'));
        expect(rows[1].amountKind, AmountKind.expense);
        expect(rows[2].amountKind, AmountKind.income);
      },
    );

    test('omits items at or beyond forty-two days', () async {
      final state = LedgerState();
      state.addAccount(
        Account(id: checkingID, name: 'Checking', type: AccountType.checking),
      );
      state.addEntry(
        entry(1, '-5.00', DateTime.utc(2026, 11, 13), name: 'Inside'),
      );
      state.addEntry(
        entry(2, '-6.00', DateTime.utc(2026, 11, 14), name: 'Outside'),
      );

      final rows = (await _settled(Ledger(state: state))).upcoming!;

      expect(rows.map((row) => row.title), ['Inside']);
    });
  });

  group('Never empty', () {
    test('a fresh ledger still reads empty sections, not null ones', () async {
      final viewState = await _settled(Ledger(state: LedgerState()));

      expect(viewState.recent, isEmpty);
      expect(viewState.upcoming, isEmpty);
      expect(viewState.today, isNotNull);
      expect(viewState.today!.spent, Decimal.zero);
      expect(viewState.recordedToday, isFalse);
    });
  });

  group('Day', () {
    test('advancing today refreshes the projected day', () {
      var now = fixtureToday;
      final ledger = Ledger(state: defaultState());
      final container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWithValue(ledger),
          analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      container.listen(overviewViewModelProvider, (_, _) {});

      now = DateTime.utc(2026, 10, 4);
      container.invalidate(todayProvider);

      final viewState = container.read(overviewViewModelProvider).requireValue;
      expect(viewState.day, DateTime.utc(2026, 10, 4));
    });
  });
}
