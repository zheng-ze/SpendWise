import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/stats/slices.dart';
import 'package:spendwise/ui/stats/stats_donut.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final state = LedgerState();

  testWidgets(
    'multi-slice donut renders the ring with gaps and leader-line labels',
    (tester) async {
      tester.view.physicalSize = const Size(320, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final slices = [
        Slice(
          bucketID: 'a0000000-0000-0000-0000-000000000001',
          amount: dec('60'),
          fraction: dec('0.6'),
          symbolName: 'restaurant',
          color: const Color(0xFFE53935),
        ),
        Slice(
          bucketID: 'a0000000-0000-0000-0000-000000000002',
          amount: dec('30'),
          fraction: dec('0.3'),
          symbolName: 'directions_bus',
          color: const Color(0xFF1E88E5),
        ),
        Slice(
          bucketID: null,
          amount: dec('10'),
          fraction: dec('0.1'),
          symbolName: 'help_outline',
          color: const Color(0xFF8E8E93),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatsDonut(slices: slices, state: state),
          ),
        ),
      );

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/stats_donut_multi.png'),
      );
    },
  );

  testWidgets('single-slice donut renders the ring without a gap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final slices = [
      Slice(
        bucketID: 'a0000000-0000-0000-0000-000000000001',
        amount: dec('100'),
        fraction: dec('1'),
        symbolName: 'restaurant',
        color: const Color(0xFFE53935),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatsDonut(slices: slices, state: state),
        ),
      ),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/stats_donut_single.png'),
    );
  });
}
