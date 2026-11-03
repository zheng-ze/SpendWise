import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';

import 'overview_fixture.dart';

Future<OverviewProjection> _settled(Ledger ledger) async {
  final container = overviewContainer(ledger);
  container.listen(overviewProjectionProvider, (_, _) {});
  await settleAnalysis(container, ledger);
  return container.read(overviewProjectionProvider).requireValue;
}

void main() {
  group('Today', () {
    test('maps spent and the daily guide from the unscoped budget', () async {
      final projection = await _settled(Ledger(state: defaultState()));

      final today = projection.today!;
      expect(today.spent, Decimal.parse('45.70'));
      expect(today.monthlyCap, Decimal.parse('1200'));
      expect(today.dailyGuide, Decimal.parse('39'));
      expect(projection.recordedToday, isTrue);
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
      container.listen(overviewProjectionProvider, (_, _) {});
      await pumpEventQueue();

      final projection = container
          .read(overviewProjectionProvider)
          .requireValue;

      expect(projection.today, isNull);
      expect(projection.recent, isNotEmpty);
      expect(projection.upcoming, isNotEmpty);
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
        container.listen(overviewProjectionProvider, (_, _) {});
        await settleAnalysis(container, ledger);

        ledger.addEntry(
          entry(1, '-5.00', fixtureToday, categoryID: groceriesID),
        );
        await pumpEventQueue();

        final projection = container
            .read(overviewProjectionProvider)
            .requireValue;
        expect(projection.recent, hasLength(1));
        expect(projection.today, isNull);
      },
    );
  });

  group('Recent entries', () {
    test('lists at most four, newest first', () async {
      final projection = await _settled(Ledger(state: defaultState()));

      expect(projection.recent!.map((row) => row.title), [
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

      final projection = await _settled(Ledger(state: state));

      expect(projection.recent!.map((row) => row.title), ['Older']);
      expect(projection.recent!.single.caption, startsWith('2 Oct / '));
      expect(projection.recordedToday, isFalse);
    });

    test('maps caption, signed amount and kind for each entry shape', () async {
      final projection = await _settled(Ledger(state: defaultState()));
      final byTitle = {for (final row in projection.recent!) row.title: row};

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
      container.listen(overviewProjectionProvider, (_, _) {});
      await settleAnalysis(container, ledger);

      ledger.addEntry(entry(9, '-1.00', fixtureToday, name: 'Newest'));
      await settleAnalysis(container, ledger);

      final projection = container
          .read(overviewProjectionProvider)
          .requireValue;
      expect(projection.recent!.first.title, 'Newest');
      expect(projection.today!.spent, Decimal.parse('46.70'));
    });
  });

  group('Coming up', () {
    test('merges statement, plans and dated-ahead entries by date', () async {
      final projection = await _settled(Ledger(state: defaultState()));

      expect(
        projection.upcoming!.map(
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
      final projection = await _settled(Ledger(state: LedgerState()));

      expect(projection.recent, isEmpty);
      expect(projection.upcoming, isEmpty);
      expect(projection.today, isNotNull);
      expect(projection.today!.spent, Decimal.zero);
      expect(projection.recordedToday, isFalse);
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
      container.listen(overviewProjectionProvider, (_, _) {});

      now = DateTime.utc(2026, 10, 4);
      container.invalidate(todayProvider);

      final projection = container
          .read(overviewProjectionProvider)
          .requireValue;
      expect(projection.day, DateTime.utc(2026, 10, 4));
    });
  });
}
