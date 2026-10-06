import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/charts/category_map.dart';
import 'package:spendwise/ui/common/charts/donut_chart.dart';
import 'package:spendwise/ui/common/charts/month_bars.dart';
import 'package:spendwise/ui/common/charts/week_strip.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: buildSpendWiseTheme(Brightness.light),
    home: Scaffold(body: child),
  );
}

SpendWiseColors _tokens(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold)))
        .extension<SpendWiseColors>()!;

List<MonthBarSlot> _twelveMonths() => [
  for (var i = 0; i < 12; i++)
    MonthBarSlot(value: 40 + i * 10, status: MonthBarStatus.value),
];

void main() {
  group('MonthBars', () {
    testWidgets('a selected mark fills with selectedMark and no stroke', (
      tester,
    ) async {
      const emptyBars = MonthBars(slots: [], selectedIndex: 0);
      final selectedBars = MonthBars(slots: _twelveMonths(), selectedIndex: 9);
      await tester.pumpWidget(_host(emptyBars));
      await tester.pumpWidget(_host(selectedBars));
      await tester.pumpAndSettle();

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final rod = chart.data.barGroups[9].barRods[0];
      expect(rod.color, _tokens(tester).selectedMark);
      expect(rod.borderSide.width, 0);
    });

    testWidgets('unselected bars keep their state colours', (tester) async {
      const slots = [
        MonthBarSlot(value: 120, status: MonthBarStatus.value),
        MonthBarSlot(value: 80, status: MonthBarStatus.incomplete),
        MonthBarSlot(status: MonthBarStatus.gap),
        MonthBarSlot(status: MonthBarStatus.blank),
      ];
      const bars = MonthBars(slots: slots);
      await tester.pumpWidget(_host(bars));
      await tester.pumpAndSettle();

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final tokens = _tokens(tester);
      expect(chart.data.barGroups[0].barRods[0].color, tokens.action);
      expect(chart.data.barGroups[1].barRods[0].color, tokens.incomplete);
      expect(
        chart.data.barGroups[1].barRods[0].borderSide.color,
        tokens.action,
      );
      expect(chart.data.barGroups[2].barRods[0].borderSide.color, tokens.gap);
      expect(chart.data.barGroups[3].barRods[0].toY, 0);
    });

    testWidgets('a selected blank slot stays at zero height', (tester) async {
      const slots = [
        MonthBarSlot(value: 120, status: MonthBarStatus.value),
        MonthBarSlot(status: MonthBarStatus.blank),
      ];
      const bars = MonthBars(slots: slots, selectedIndex: 1);
      await tester.pumpWidget(_host(bars));
      await tester.pumpAndSettle();

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups[1].barRods[0].toY, 0);
    });

    testWidgets('a gap slot draws a dashed stub', (tester) async {
      const bars = MonthBars(slots: [MonthBarSlot(status: MonthBarStatus.gap)]);
      await tester.pumpWidget(_host(bars));
      await tester.pumpAndSettle();

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups[0].barRods[0].borderDashArray, isNotNull);
    });

    testWidgets('tapping a bar reports its index', (tester) async {
      var selected = -1;
      final bars = MonthBars(
        slots: _twelveMonths(),
        onSelect: (i) => selected = i,
      );
      await tester.pumpWidget(_host(bars));
      await tester.pumpAndSettle();

      final chartRect = tester.getRect(find.byType(BarChart));
      await tester.tapAt(
        Offset(
          chartRect.left + chartRect.width * 3.5 / 12,
          chartRect.bottom - 20,
        ),
      );
      await tester.pumpAndSettle();

      expect(selected, 3);
    });

    testWidgets('a tap selects once and a drag across bars selects nothing', (
      tester,
    ) async {
      final selections = <int>[];
      final bars = MonthBars(slots: _twelveMonths(), onSelect: selections.add);
      await tester.pumpWidget(_host(bars));
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
    });
  });

  group('DonutChart', () {
    testWidgets('a selected section fills with selectedMark and no stroke', (
      tester,
    ) async {
      const segments = [
        DonutSegment(label: 'Groceries', value: 73.5, color: Color(0xFF29755E)),
        DonutSegment(label: 'Dining', value: 83.9, color: Color(0xFF986421)),
      ];
      const donut = DonutChart(
        segments: segments,
        centerLabel: 'October',
        centerValue: 'S\$167.40',
        selectedIndex: 0,
      );
      await tester.pumpWidget(_host(donut));
      await tester.pumpAndSettle();

      final chart = tester.widget<PieChart>(find.byType(PieChart));
      expect(chart.data.sections[0].color, _tokens(tester).selectedMark);
      expect(chart.data.sections[0].borderSide.width, 0);
      expect(chart.data.sections[1].color, const Color(0xFF986421));
      expect(find.text('October'), findsOneWidget);
      expect(find.text('S\$167.40'), findsOneWidget);
    });

    testWidgets(
      'a tap selects once and a drag around the ring selects nothing',
      (tester) async {
        final selections = <int>[];
        final donut = DonutChart(
          segments: const [
            DonutSegment(
              label: 'Groceries',
              value: 1,
              color: Color(0xFF29755E),
            ),
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
          return centre +
              Offset(math.cos(radians), math.sin(radians)) * ringRadius;
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
      },
    );
  });

  group('layoutCategoryMap', () {
    double maxAspect(List<Rect> rects) {
      var worst = 0.0;
      for (final rect in rects) {
        if (rect.isEmpty) continue;
        final ratio =
            math.max(rect.width, rect.height) /
            math.min(rect.width, rect.height);
        if (ratio > worst) worst = ratio;
      }
      return worst;
    }

    test('areas follow values and tile the box', () {
      const size = Size(280, 136);
      final rects = layoutCategoryMap([60, 30, 10], size);

      expect(rects, hasLength(3));
      final boxArea = size.width * size.height;
      final areas = rects.map((rect) => rect.width * rect.height).toList();
      expect(areas[0] / boxArea, closeTo(0.6, 0.02));
      expect(areas[1] / boxArea, closeTo(0.3, 0.02));
      expect(areas[2] / boxArea, closeTo(0.1, 0.02));
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(rects[i].overlaps(rects[j]), isFalse);
        }
      }
    });

    test('rows follow the shorter side in landscape and portrait', () {
      final landscape = layoutCategoryMap([60, 30, 10], const Size(280, 136));
      final portrait = layoutCategoryMap([60, 30, 10], const Size(136, 280));

      expect(maxAspect(landscape), lessThanOrEqualTo(3.5));
      expect(maxAspect(portrait), lessThanOrEqualTo(3.5));
    });

    test('empty and zero inputs tile to nothing', () {
      expect(layoutCategoryMap([], const Size(280, 136)), isEmpty);
      final rects = layoutCategoryMap([0, 0], const Size(280, 136));
      expect(rects.every((rect) => rect.isEmpty), isTrue);
    });
  });

  group('CategoryMap', () {
    testWidgets('no block shows a bare number', (tester) async {
      const tiles = [
        CategoryMapTile(
          label: 'Groceries',
          share: 0.44,
          color: Color(0xFF29755E),
        ),
        CategoryMapTile(label: 'Dining', share: 0.5, color: Color(0xFF986421)),
        CategoryMapTile(label: 'Tiny', share: 0.06, color: Color(0xFF6861A4)),
      ];
      const map = CategoryMap(tiles: tiles);
      await tester.pumpWidget(_host(map));
      await tester.pumpAndSettle();

      final bareNumber = RegExp(r'^[\d.,% ]+$');
      for (final element in find.byType(Text).evaluate()) {
        final data = (element.widget as Text).data ?? '';
        expect(bareNumber.hasMatch(data), isFalse, reason: 'bare: $data');
      }
    });

    testWidgets('small blocks name their share beside the map', (tester) async {
      const map = SizedBox(
        width: 300,
        child: CategoryMap(
          tiles: [
            CategoryMapTile(
              label: 'Dining',
              share: 0.97,
              color: Color(0xFF986421),
            ),
            CategoryMapTile(
              label: 'Tiny',
              share: 0.03,
              color: Color(0xFF6861A4),
            ),
          ],
        ),
      );
      await tester.pumpWidget(_host(map));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tiny'), findsWidgets);
    });

    testWidgets('labels that do not fit move beside the map', (tester) async {
      const tiles = [
        CategoryMapTile(
          label: 'Healthcare',
          share: 0.34,
          color: Color(0xFF29755E),
        ),
        CategoryMapTile(
          label: 'Transport',
          share: 0.33,
          color: Color(0xFF6861A4),
        ),
        CategoryMapTile(label: 'Dining', share: 0.33, color: Color(0xFF8A4F7D)),
      ];
      const map = SizedBox(width: 300, child: CategoryMap(tiles: tiles));
      Widget mapWithScale(double scale) {
        return MaterialApp(
          theme: buildSpendWiseTheme(Brightness.light),
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: map,
            ),
          ),
        );
      }

      await tester.pumpWidget(mapWithScale(1));
      await tester.pumpAndSettle();
      expect(find.textContaining('Healthcare\n'), findsOneWidget);
      expect(find.text('Healthcare 34.0%'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(mapWithScale(2));
      await tester.pumpAndSettle();
      expect(find.text('Healthcare 34.0%'), findsOneWidget);
      expect(find.text('Transport 33.0%'), findsOneWidget);
      expect(find.text('Dining 33.0%'), findsOneWidget);
      expect(find.textContaining('Healthcare\n'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping an adjacent label selects its original index', (
      tester,
    ) async {
      var selected = -1;
      final map = SizedBox(
        width: 280,
        child: CategoryMap(
          tiles: const [
            CategoryMapTile(
              label: 'Big',
              share: 0.999,
              color: Color(0xFF986421),
            ),
            CategoryMapTile(
              label: 'Tiny',
              share: 0.001,
              color: Color(0xFF6861A4),
            ),
          ],
          onSelect: (i) => selected = i,
        ),
      );
      await tester.pumpWidget(_host(map));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tiny 0.1%'));
      expect(selected, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a block reports its index', (tester) async {
      var selected = -1;
      final map = SizedBox(
        width: 300,
        child: CategoryMap(
          tiles: const [
            CategoryMapTile(
              label: 'Dining',
              share: 0.6,
              color: Color(0xFF986421),
            ),
            CategoryMapTile(
              label: 'Groceries',
              share: 0.4,
              color: Color(0xFF29755E),
            ),
          ],
          onSelect: (i) => selected = i,
        ),
      );
      await tester.pumpWidget(_host(map));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Groceries').first);
      expect(selected, 1);
    });
  });

  group('WeekStrip', () {
    testWidgets('future days draw no bar and past empty days draw the stub', (
      tester,
    ) async {
      const strip = WeekStrip(
        days: [
          WeekStripDay(label: 'M', caption: 'S\$12', fraction: 0.5),
          WeekStripDay(label: 'T', caption: 'None'),
          WeekStripDay(label: 'W', caption: 'Ahead', future: true),
        ],
      );
      await tester.pumpWidget(_host(strip));

      expect(find.byKey(const ValueKey('weekStripGapStub')), findsOneWidget);
      final stub = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('weekStripGapStub')),
      );
      expect(stub.painter, isA<GapStubPainter>());
      expect((stub.painter! as GapStubPainter).color, _tokens(tester).gap);
    });

    testWidgets('draws each day with its caption', (tester) async {
      const strip = WeekStrip(
        days: [
          WeekStripDay(label: 'M', caption: 'S\$12', fraction: 0.5),
          WeekStripDay(label: 'T', caption: 'S\$8', fraction: 0.3),
          WeekStripDay(label: 'W', caption: '-', future: true),
          WeekStripDay(label: 'T', caption: '-', future: true),
          WeekStripDay(label: 'F', caption: '-', future: true),
        ],
      );
      await tester.pumpWidget(_host(strip));

      for (final label in ['M', 'T', 'W', 'F']) {
        expect(find.text(label), findsWidgets);
      }
      expect(find.text('S\$12'), findsOneWidget);
    });
  });
}
