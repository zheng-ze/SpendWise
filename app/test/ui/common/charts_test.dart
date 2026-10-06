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
      await tester.pumpWidget(
        _host(const MonthBars(slots: [], selectedIndex: 0)),
      );
      await tester.pumpWidget(
        _host(MonthBars(slots: _twelveMonths(), selectedIndex: 9)),
      );
      await tester.pumpAndSettle();

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final rod = chart.data.barGroups[9].barRods[0];
      expect(rod.color, _tokens(tester).selectedMark);
      expect(rod.borderSide.width, 0);
    });

    testWidgets('unselected bars keep their state colours', (tester) async {
      await tester.pumpWidget(
        _host(
          MonthBars(
            slots: const [
              MonthBarSlot(value: 120, status: MonthBarStatus.value),
              MonthBarSlot(value: 80, status: MonthBarStatus.incomplete),
              MonthBarSlot(status: MonthBarStatus.gap),
              MonthBarSlot(status: MonthBarStatus.blank),
            ],
          ),
        ),
      );
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

    testWidgets('tapping a bar reports its index', (tester) async {
      var selected = -1;
      await tester.pumpWidget(
        _host(MonthBars(slots: _twelveMonths(), onSelect: (i) => selected = i)),
      );
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
  });

  group('DonutChart', () {
    testWidgets('a selected section fills with selectedMark and no stroke', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          DonutChart(
            segments: const [
              DonutSegment(
                label: 'Groceries',
                value: 73.5,
                color: Color(0xFF29755E),
              ),
              DonutSegment(
                label: 'Dining',
                value: 83.9,
                color: Color(0xFF986421),
              ),
            ],
            centerLabel: 'October',
            centerValue: 'S\$167.40',
            selectedIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chart = tester.widget<PieChart>(find.byType(PieChart));
      expect(chart.data.sections[0].color, _tokens(tester).selectedMark);
      expect(chart.data.sections[0].borderSide.width, 0);
      expect(chart.data.sections[1].color, const Color(0xFF986421));
      expect(find.text('October'), findsOneWidget);
      expect(find.text('S\$167.40'), findsOneWidget);
    });
  });

  group('layoutCategoryMap', () {
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

    test('empty and zero inputs tile to nothing', () {
      expect(layoutCategoryMap([], const Size(280, 136)), isEmpty);
      final rects = layoutCategoryMap([0, 0], const Size(280, 136));
      expect(rects.every((rect) => rect.isEmpty), isTrue);
    });
  });

  group('CategoryMap', () {
    testWidgets('no block shows a bare number', (tester) async {
      await tester.pumpWidget(
        _host(
          const CategoryMap(
            tiles: [
              CategoryMapTile(
                label: 'Groceries',
                share: 0.44,
                color: Color(0xFF29755E),
              ),
              CategoryMapTile(
                label: 'Dining',
                share: 0.5,
                color: Color(0xFF986421),
              ),
              CategoryMapTile(
                label: 'Tiny',
                share: 0.06,
                color: Color(0xFF6861A4),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bareNumber = RegExp(r'^[\d.,% ]+$');
      for (final element in find.byType(Text).evaluate()) {
        final data = (element.widget as Text).data ?? '';
        expect(bareNumber.hasMatch(data), isFalse, reason: 'bare: $data');
      }
    });

    testWidgets('small blocks name their share beside the map', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
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
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Tiny'), findsWidgets);
    });

    testWidgets('tapping a block reports its index', (tester) async {
      var selected = -1;
      await tester.pumpWidget(
        _host(
          SizedBox(
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
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Groceries').first);
      expect(selected, 1);
    });
  });

  group('WeekStrip', () {
    testWidgets('draws each day with its caption', (tester) async {
      await tester.pumpWidget(
        _host(
          const WeekStrip(
            days: [
              WeekStripDay(label: 'M', caption: 'S\$12', fraction: 0.5),
              WeekStripDay(label: 'T', caption: 'S\$8', fraction: 0.3),
              WeekStripDay(label: 'W', caption: '-', future: true),
              WeekStripDay(label: 'T', caption: '-', future: true),
              WeekStripDay(label: 'F', caption: '-', future: true),
            ],
          ),
        ),
      );

      for (final label in ['M', 'T', 'W', 'F']) {
        expect(find.text(label), findsWidgets);
      }
      expect(find.text('S\$12'), findsOneWidget);
    });
  });
}
