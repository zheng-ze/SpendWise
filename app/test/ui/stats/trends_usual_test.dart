import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';

import 'trends_test_support.dart';

const _usualTitle = 'Compared with usual';

typedef _Spend = (DateTime, String);

_Spend _on(int year, int month, int day, String amount) =>
    (DateTime.utc(year, month, day), amount);

Future<TrendsHarness> _open(List<_Spend> spends, {required DateTime today}) {
  final ledger = emptyTrendsLedger();
  addTrendsEntry(ledger, '5', DateTime.utc(2026, 1, 5));
  for (final (date, amount) in spends) {
    addTrendsEntry(ledger, amount, date);
  }
  return readyHarness(ledger: ledger, today: today);
}

Future<TrendsUsual> _usualFor(TrendsHarness harness, String month) async {
  final bars = harness.ready.bars;
  harness.viewModel.selectSlot(
    bars.indexWhere((bar) => bar.semanticLabel == month),
  );
  await harness.settle();
  return harness.ready.usual!;
}

final _october = DateTime.utc(2026, 10, 15);

List<_Spend> _springBaseline(String april, String may, String june) => [
  _on(2026, 4, 10, april),
  _on(2026, 5, 10, may),
  _on(2026, 6, 10, june),
];

void main() {
  group('seed figures', () {
    test(
      'October 2026 shows expense and income totals with usual unavailable',
      () async {
        final today = DateTime.utc(2026, 10, 3);
        final harness = await readyHarness(
          ledger: seededTrendsLedger(today),
          today: today,
        );

        expect(harness.ready.headline.amount, '-S\$167.40');
        expect(harness.ready.usual?.title, _usualTitle);
        expect(harness.ready.usual?.body, 'Not enough data');
        harness.viewModel.setKind(TrendsKind.income);
        await harness.settle();
        expect(harness.ready.headline.amount, '+S\$3,200.00');
        expect(harness.ready.usual?.body, 'Not enough data');
      },
    );
  });

  group('past month', () {
    test(
      'a month above its three-month usual reads higher with the average range',
      () async {
        final spends = [
          ..._springBaseline('-875', '-860', '-940'),
          _on(2026, 7, 10, '-900'),
        ];
        final harness = await _open(spends, today: _october);

        final usual = await _usualFor(harness, 'July 2026');

        expect(usual.title, 'Compared with usual: 0.9% higher');
        expect(usual.body, 'Usual is S\$891.67, the April to June average.');
      },
    );

    test('a month below its usual reads lower', () async {
      final spends = [
        ..._springBaseline('-1000', '-1000', '-1000'),
        _on(2026, 7, 10, '-900'),
      ];
      final harness = await _open(spends, today: _october);

      final usual = await _usualFor(harness, 'July 2026');

      expect(usual.title, 'Compared with usual: 10.0% lower');
    });

    test('a month matching its usual reads the same', () async {
      final spends = [
        ..._springBaseline('-900', '-900', '-900'),
        _on(2026, 7, 10, '-900'),
      ];
      final harness = await _open(spends, today: _october);

      final usual = await _usualFor(harness, 'July 2026');

      expect(usual.title, 'Compared with usual: Same as usual');
      expect(usual.body, 'Usual is S\$900.00, the April to June average.');
    });

    test('a tie between tenths rounds to the even tenth', () async {
      final spends = [
        ..._springBaseline('-2000', '-2000', '-2000'),
        _on(2026, 7, 10, '-2005'),
      ];
      final harness = await _open(spends, today: _october);

      final usual = await _usualFor(harness, 'July 2026');

      expect(usual.title, 'Compared with usual: 0.2% higher');
    });

    test('a zero baseline shows the amount without a percentage', () async {
      final harness = await _open([_on(2026, 7, 10, '-50')], today: _october);

      final usual = await _usualFor(harness, 'July 2026');

      expect(usual.title, _usualTitle);
      expect(usual.body, 'Usual is S\$0.00.');
    });

    test('a baseline spanning a year boundary names both years', () async {
      final spends = [
        _on(2026, 11, 10, '-100'),
        _on(2026, 12, 10, '-100'),
        _on(2027, 1, 10, '-100'),
        _on(2027, 2, 10, '-90'),
      ];
      final harness = await _open(spends, today: DateTime.utc(2027, 3, 20));

      final usual = await _usualFor(harness, 'February 2027');

      expect(usual.title, 'Compared with usual: 10.0% lower');
      expect(
        usual.body,
        'Usual is S\$100.00, the November 2026 to January 2027 average.',
      );
    });
  });

  group('current month', () {
    List<_Spend> pace() => [
      _on(2026, 7, 5, '-100'),
      _on(2026, 7, 28, '-999'),
      _on(2026, 8, 5, '-100'),
      _on(2026, 9, 5, '-100'),
      _on(2026, 10, 2, '-100'),
      _on(2026, 10, 28, '-900'),
    ];

    test(
      'compares the pace so far while the headline keeps later booked entries',
      () async {
        final harness = await _open(pace(), today: _october);

        expect(harness.ready.headline.amount, '-S\$1,000.00');
        expect(
          harness.ready.usual?.title,
          'Compared with usual: Same as usual',
        );
        expect(
          harness.ready.usual?.body,
          "Usual is S\$100.00, the day 1 to 15 average for July to September, "
          "clipped to each month's length.",
        );
      },
    );

    test('rereads the pace when the day advances within the month', () async {
      final harness = await _open(pace(), today: _october);

      await harness.setToday(DateTime.utc(2026, 10, 16));

      expect(harness.ready.usual?.body, contains('day 1 to 16 average'));
    });
  });

  group('year mode', () {
    test('has no usual row', () async {
      final harness = await _open(const [], today: _october);

      harness.viewModel.setMode(TrendsMode.year);
      await harness.settle();

      expect(harness.ready.usual, isNull);
    });
  });
}
