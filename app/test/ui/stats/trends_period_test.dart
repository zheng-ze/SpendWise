import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';

import 'trends_test_support.dart';

final _today = DateTime.utc(2026, 10, 15);

class _History {
  const _History(this.ledger, this.firstEntryID);

  final Ledger ledger;
  final String firstEntryID;
}

_History _history({DateTime? first}) {
  final ledger = emptyTrendsLedger();
  final firstID = addTrendsEntry(
    ledger,
    '-100',
    first ?? DateTime.utc(2024, 1, 10),
  );
  addTrendsEntry(ledger, '-250', DateTime.utc(2025, 7, 5));
  addTrendsEntry(ledger, '-30', DateTime.utc(2025, 12, 31));
  addTrendsEntry(ledger, '-900', DateTime.utc(2026, 7, 10));
  addTrendsEntry(
    ledger,
    '-77',
    DateTime.utc(2026, 8, 12),
    categoryID: hiddenCategoryID,
  );
  addTrendsEntry(ledger, '-40', DateTime.utc(2026, 10, 2));
  addTrendsEntry(ledger, '-60', DateTime.utc(2026, 10, 28));
  addTrendsEntry(ledger, '3200', DateTime.utc(2026, 10, 3));
  return _History(ledger, firstID);
}

Future<TrendsHarness> _open({_History? history, DateTime? today}) {
  return readyHarness(
    ledger: (history ?? _history()).ledger,
    today: today ?? _today,
  );
}

Future<void> _select(TrendsHarness harness, String semanticLabel) async {
  final bars = harness.ready.bars;
  harness.viewModel.selectSlot(
    bars.indexWhere((bar) => bar.semanticLabel == semanticLabel),
  );
  await harness.settle();
}

Future<void> _page(TrendsHarness harness, {required int back}) async {
  for (var i = 0; i < back; i++) {
    harness.viewModel.previousPage();
  }
  await harness.settle();
}

List<String> _labels(TrendsReadyBody body) => [
  for (final bar in body.bars) bar.label,
];

void main() {
  group('opening', () {
    test(
      'starts on expense, month by month, ending at the current month',
      () async {
        final harness = await _open();

        final intent = harness.intent;
        expect(intent.kind, TrendsKind.expense);
        expect(intent.mode, TrendsMode.month);
        expect(intent.followsCurrent, isTrue);
        expect(harness.ready.period.rangeLabel, 'Nov 2025 - Oct 2026');
        expect(harness.ready.selectedIndex, 11);
        expect(harness.ready.headline.title, 'October 2026');
        expect(harness.ready.headline.sublabel, 'Spent');
        expect(harness.ready.headline.amount, '-S\$100.00');
      },
    );

    test('ignores the month History has selected', () async {
      final harness = TrendsHarness(ledger: _history().ledger, today: _today);
      harness.container.read(selectedMonthProvider.notifier).state =
          DateTime.utc(2025, 3, 1);
      await harness.settle();

      expect(harness.ready.headline.title, 'October 2026');
    });

    test('shows twelve chronological months', () async {
      final harness = await _open();

      expect(_labels(harness.ready), [
        'N', 'D', 'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', //
      ]);
      expect(harness.ready.bars.first.semanticLabel, 'November 2025');
      expect(harness.ready.bars.last.semanticLabel, 'October 2026');
    });

    test('shows three calendar years in year mode', () async {
      final harness = await _open();

      harness.viewModel.setMode(TrendsMode.year);
      await harness.settle();

      expect(_labels(harness.ready), ['2024', '2025', '2026']);
      expect(harness.ready.period.rangeLabel, '2024 - 2026');
      expect(harness.ready.headline.title, '2026');
      expect(harness.ready.headline.amount, '-S\$1,000.00');
    });
  });

  group('committed totals', () {
    test('bars count after-today and December entries', () async {
      final harness = await _open();

      final values = [for (final bar in harness.ready.bars) bar.value];
      expect(values[1], 30);
      expect(values[11], 100);
    });

    test('year bars are plain calendar-year sums', () async {
      final harness = await _open();

      harness.viewModel.setMode(TrendsMode.year);
      await harness.settle();

      final values = [for (final bar in harness.ready.bars) bar.value];
      expect(values, [100, 280, 1000]);
    });
  });

  group('selection and paging', () {
    test(
      'selecting a slot updates the headline and keeps the spread',
      () async {
        final harness = await _open();

        await _select(harness, 'July 2026');

        expect(harness.ready.headline.title, 'July 2026');
        expect(harness.ready.headline.amount, '-S\$900.00');
        expect(harness.ready.period.rangeLabel, 'Nov 2025 - Oct 2026');
        expect(harness.intent.followsCurrent, isFalse);
      },
    );

    test(
      'previous turns July 2026 into July 2025 in the earlier spread',
      () async {
        final harness = await _open();
        await _select(harness, 'July 2026');

        harness.viewModel.previousPage();
        await harness.settle();

        expect(harness.ready.headline.title, 'July 2025');
        expect(harness.ready.headline.amount, '-S\$250.00');
        expect(harness.ready.period.rangeLabel, 'Nov 2024 - Oct 2025');
        expect(harness.ready.selectedIndex, 8);
      },
    );

    test(
      'paging stops at the earliest spread and at the current month',
      () async {
        final harness = await _open();

        await _page(harness, back: 5);

        expect(harness.ready.period.rangeLabel, 'Nov 2023 - Oct 2024');
        expect(harness.ready.period.previousEnabled, isFalse);
        expect(harness.ready.period.nextEnabled, isTrue);
        harness.viewModel.nextPage();
        harness.viewModel.nextPage();
        harness.viewModel.nextPage();
        await harness.settle();
        expect(harness.ready.period.rangeLabel, 'Nov 2025 - Oct 2026');
        expect(harness.ready.period.nextEnabled, isFalse);
      },
    );

    test(
      'year paging has both arrows off when every year fits one page',
      () async {
        final harness = await _open();

        harness.viewModel.setMode(TrendsMode.year);
        await harness.settle();

        expect(harness.ready.period.previousEnabled, isFalse);
        expect(harness.ready.period.nextEnabled, isFalse);
      },
    );
  });

  group('kind and mode', () {
    test('changing kind keeps the selected month and mode', () async {
      final harness = await _open();
      await _select(harness, 'July 2026');

      harness.viewModel.setKind(TrendsKind.income);
      await harness.settle();

      expect(harness.intent.mode, TrendsMode.month);
      expect(harness.ready.headline.title, 'July 2026');
      expect(harness.ready.headline.sublabel, 'Earned');
      expect(harness.ready.headline.emptyMessage, 'No income recorded');
    });

    test('month to year selects the containing year and year to month returns to the month', () async {
      final harness = await _open();
      await _select(harness, 'July 2026');

      harness.viewModel.setMode(TrendsMode.year);
      await harness.settle();
      expect(harness.ready.headline.title, '2026');
      harness.viewModel.selectSlot(1);
      await harness.settle();
      expect(harness.ready.headline.title, '2025');
      harness.viewModel.setMode(TrendsMode.month);
      await harness.settle();

      expect(harness.ready.headline.title, 'July 2025');
      expect(harness.ready.headline.amount, '-S\$250.00');
    });

    test(
      'year to month clamps a remembered future month to the current month',
      () async {
        final harness = await _open();
        await _select(harness, 'December 2025');

        harness.viewModel.setMode(TrendsMode.year);
        await harness.settle();
        harness.viewModel.selectSlot(2);
        await harness.settle();
        harness.viewModel.setMode(TrendsMode.month);
        await harness.settle();

        expect(harness.ready.headline.title, 'October 2026');
      },
    );

    test('month to year clamps to the earliest yearly slot', () async {
      final harness = await _open();
      await _page(harness, back: 2);
      await _select(harness, 'November 2023');

      harness.viewModel.setMode(TrendsMode.year);
      await harness.settle();

      expect(harness.ready.headline.title, '2024');
    });

    test('year to month clamps to the earliest monthly slot', () async {
      final late = _history(first: DateTime.utc(2024, 12, 5));
      final harness = await _open(history: late);
      harness.viewModel.setMode(TrendsMode.year);
      await harness.settle();
      harness.viewModel.selectSlot(0);
      await harness.settle();

      harness.viewModel.setMode(TrendsMode.month);
      await harness.settle();

      expect(harness.ready.headline.title, 'November 2024');
    });
  });

  group('history changes', () {
    test(
      'contraction clamps the display and restoration brings the request back',
      () async {
        final history = _history();
        final harness = await _open(history: history);
        await _page(harness, back: 2);
        final requested = harness.intent;

        history.ledger.archiveEntry(history.firstEntryID);
        await harness.settle();
        expect(harness.ready.period.rangeLabel, 'Nov 2024 - Oct 2025');
        expect(harness.intent, requested);

        history.ledger.restoreEntry(history.firstEntryID);
        await harness.settle();
        expect(harness.ready.period.rangeLabel, 'Nov 2023 - Oct 2024');
      },
    );

    test('paging from the clamped page steps exactly twelve months and keeps that choice', () async {
      final history = _history();
      final harness = await _open(history: history);
      await _page(harness, back: 2);
      history.ledger.archiveEntry(history.firstEntryID);
      await harness.settle();
      expect(harness.ready.period.previousEnabled, isFalse);

      harness.viewModel.nextPage();
      await harness.settle();
      history.ledger.restoreEntry(history.firstEntryID);
      await harness.settle();

      expect(harness.ready.period.rangeLabel, 'Nov 2025 - Oct 2026');
    });

    test('retry and re-selecting the active controls leave the stored request alone', () async {
      final history = _history();
      final harness = await _open(history: history);
      await _page(harness, back: 2);
      final requested = harness.intent;
      history.ledger.archiveEntry(history.firstEntryID);
      await harness.settle();

      harness.viewModel.retry();
      harness.viewModel.setKind(TrendsKind.expense);
      harness.viewModel.setMode(TrendsMode.month);
      await harness.settle();

      expect(harness.intent, requested);
    });
  });

  group('no records', () {
    test('an empty month shows the no-record message and no amount', () async {
      final harness = await _open();

      await _select(harness, 'June 2026');

      expect(harness.ready.headline.emptyMessage, 'No expenses recorded');
      expect(harness.ready.headline.amount, isNull);
      expect(harness.ready.headline.sublabel, 'Spent');
      expect(harness.ready.bars[harness.ready.selectedIndex].value, 0);
    });

    test('a month holding only entries excluded from analysis shows the no-record message', () async {
      final harness = await _open();

      await _select(harness, 'August 2026');

      expect(harness.ready.headline.emptyMessage, 'No expenses recorded');
      expect(harness.ready.headline.amount, isNull);
    });
  });
}
