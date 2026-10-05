import 'package:domain/domain.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/stats/category_detail/category_scope.dart';
import 'package:spendwise/ui/stats/category_detail/category_trend_card.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  Future<void> pumpCard(WidgetTester tester) async {
    final months = [
      for (var month = 1; month <= 6; month++) DateTime.utc(2026, month),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrendCard(
            scope: const AllScope(),
            mainCategory: null,
            state: LedgerState(),
            detailDate: DateTime.utc(2026, 6),
            isYearRange: false,
            months: months,
            amounts: [
              dec('10'),
              dec('15'),
              dec('12'),
              dec('20'),
              dec('18'),
              dec('25'),
            ],
            color: const Color(0xFF964B44),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the touched indicator uses the selected-mark fill', (
    tester,
  ) async {
    await pumpCard(tester);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final bar = chart.data.lineBarsData.first;
    final indicators = chart.data.lineTouchData.getTouchedSpotIndicator(bar, [
      0,
    ]);
    expect(indicators, hasLength(1));

    final data = indicators.single;
    expect(data, isNotNull);
    final painter = data!.touchedSpotDotData.getDotPainter(
      bar.spots.first,
      0,
      bar,
      0,
    );
    expect(painter, isA<FlDotCirclePainter>());
    final dot = painter as FlDotCirclePainter;
    expect(dot.color, const Color(0xFF8B48A0));
    expect(dot.strokeWidth, 0);
  });
}
