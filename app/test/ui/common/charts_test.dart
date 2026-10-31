import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/charts/donut_chart.dart';
import 'package:spendwise/ui/common/charts/month_bars.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

import '../../support/ui_test_timeout.dart';

Widget _host(Widget child) => MaterialApp(
  theme: buildSpendWiseTheme(Brightness.light),
  home: Scaffold(body: child),
);

List<MonthBarSlot> _twelveMonths() => [
  for (var index = 0; index < 12; index++)
    MonthBarSlot(value: 40 + index * 10, status: MonthBarStatus.value),
];

void main() {
  testWidgets('month bars select only on a completed tap', (tester) async {
    final selections = <int>[];
    await tester.pumpWidget(
      _host(MonthBars(slots: _twelveMonths(), onSelect: selections.add)),
    );
    await tester.pumpAndSettle();

    final chartRect = tester.getRect(find.byType(BarChart));
    Offset barCentre(int index) => Offset(
      chartRect.left + chartRect.width * (index + 0.5) / 12,
      chartRect.bottom - 20,
    );
    await tester.tapAt(barCentre(3));
    await tester.pumpAndSettle();
    expect(selections, [3]);

    final gesture = await tester.startGesture(barCentre(1));
    for (var index = 2; index <= 8; index++) {
      await gesture.moveTo(barCentre(index));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selections, [3]);
  }, timeout: uiTestTimeout);

  testWidgets('month bars select a gap or blank slot and tolerate a limit', (
    tester,
  ) async {
    final selections = <int>[];
    final slots = [
      const MonthBarSlot(value: 50),
      const MonthBarSlot(status: MonthBarStatus.gap),
      const MonthBarSlot(status: MonthBarStatus.blank),
      const MonthBarSlot(value: 30, status: MonthBarStatus.incomplete),
    ];
    final months = [for (var m = 1; m <= 4; m++) DateTime.utc(2026, m)];
    await tester.pumpWidget(
      _host(
        MonthBars(
          slots: slots,
          months: months,
          limit: 40,
          touchFullHeight: true,
          maxValue: 60,
          selectedIndex: 1,
          onSelect: selections.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final chartRect = tester.getRect(find.byType(BarChart));
    Offset column(int index) => Offset(
      chartRect.left + chartRect.width * (index + 0.5) / slots.length,
      chartRect.bottom - 40,
    );
    await tester.tapAt(column(1));
    await tester.pumpAndSettle();
    await tester.tapAt(column(2));
    await tester.pumpAndSettle();
    expect(selections, [1, 2]);
  }, timeout: uiTestTimeout);

  testWidgets('donut slices select only on a completed tap', (tester) async {
    final selections = <int>[];
    final donut = DonutChart(
      segments: const [
        DonutSegment(label: 'Groceries', value: 1, color: Color(0xFF29755E)),
        DonutSegment(label: 'Dining', value: 1, color: Color(0xFF986421)),
      ],
      onSelect: selections.add,
    );
    await tester.pumpWidget(_host(Center(child: donut)));
    await tester.pumpAndSettle();

    final centre = tester.getCenter(find.byType(PieChart));
    const ringRadius = 132 * 0.34 + 132 * 0.17 / 2;
    Offset onRing(double degrees) {
      final radians = degrees * math.pi / 180;
      return centre + Offset(math.cos(radians), math.sin(radians)) * ringRadius;
    }

    await tester.tapAt(onRing(90));
    await tester.pumpAndSettle();
    expect(selections, [0]);

    final gesture = await tester.startGesture(onRing(30));
    for (var degrees = 60.0; degrees <= 330; degrees += 30) {
      await gesture.moveTo(onRing(degrees));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selections, [0]);
  }, timeout: uiTestTimeout);
}
