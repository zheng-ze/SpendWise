import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';

import 'overview_fixture.dart';

Future<OverviewViewState> _settled(Ledger ledger) async {
  final container = overviewContainer(ledger);
  container.listen(overviewViewModelProvider, (_, _) {});
  await settleAnalysis(container, ledger);
  return container.read(overviewViewModelProvider);
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

      final viewState = container.read(overviewViewModelProvider);

      expect(viewState.today, isNull);
      expect(viewState.recent, isNotEmpty);
      expect(viewState.upcoming, isNotEmpty);
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

      final viewState = container.read(overviewViewModelProvider);
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
}
