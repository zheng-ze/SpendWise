import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/charts/donut_chart.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

import '../../support/ui_test_timeout.dart';

const _phoneWidth = 320.0;
const _defaultWidth = 800.0;
const _viewportHeight = 600.0;
const _customChartSize = 320.0;
const _share = '75.5%';
const _diameterFactor = 2.0;
const _geometryTolerance = 0.001;
const _valueFontSize = 14.0;
const _shareFontSize = 10.0;
const _pixelRatio = 1.0;
const _longNames = [
  'Uncategorized',
  'Direct to Groceries and other household essentials',
];
const _shortNames = ['Dining', 'Salary'];
const _fontFamily = 'InstrumentSans';
const _fontAssets = [
  'assets/fonts/instrument_sans/InstrumentSans-Regular.ttf',
  'assets/fonts/instrument_sans/InstrumentSans-SemiBold.ttf',
];
const _segment = DonutSegment(
  label: 'Category',
  value: 1,
  color: Color(0xFF8E8E93),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);
  for (final brightness in Brightness.values) {
    for (final width in [_phoneWidth, _defaultWidth]) {
      _registerLongNames(brightness, width);
      _registerShortNames(brightness, width);
    }
  }
}

void _registerLongNames(Brightness brightness, double width) {
  for (final name in _longNames) {
    for (final size in [null, _customChartSize]) {
      _longNameTest(brightness, width, name, size);
    }
  }
}

void _longNameTest(
  Brightness brightness,
  double width,
  String name,
  double? size,
) {
  testWidgets('$brightness $width $size keeps $name inside the hole', (
    tester,
  ) async {
    await _pumpDonut(tester, brightness, width, name, size: size);

    final hole = _holeRect(tester);
    final nameRect = tester.getRect(find.text(name));
    final shareRect = tester.getRect(find.text(_share));
    _expectInsideHole(nameRect, hole);
    _expectInsideHole(shareRect, hole);
    expect(tester.takeException(), isNull);
  }, timeout: uiTestTimeout);
}

void _registerShortNames(Brightness brightness, double width) {
  for (final name in _shortNames) {
    testWidgets('$brightness $width preserves the $name centre layout', (
      tester,
    ) async {
      await _pumpDonut(tester, brightness, width, name);

      final value = find.text(name);
      final share = find.text(_share);
      final valueRect = tester.getRect(value);
      final shareRect = tester.getRect(share);
      final center = tester.getCenter(find.byType(DonutChart));
      expect(valueRect.size, tester.getSize(value));
      expect(shareRect.size, tester.getSize(share));
      expect(valueRect.center.dx, closeTo(center.dx, _geometryTolerance));
      expect(shareRect.center.dx, closeTo(center.dx, _geometryTolerance));
      expect(valueRect.bottom, closeTo(shareRect.top, _geometryTolerance));
      final combinedCenter =
          (valueRect.top + shareRect.bottom) / _diameterFactor;
      expect(combinedCenter, closeTo(center.dy, _geometryTolerance));
      expect(tester.widget<Text>(value).style?.fontSize, _valueFontSize);
      expect(tester.widget<Text>(share).style?.fontSize, _shareFontSize);
    }, timeout: uiTestTimeout);
  }
}

Future<void> _pumpDonut(
  WidgetTester tester,
  Brightness brightness,
  double width,
  String name, {
  double? size,
}) async {
  tester.view.devicePixelRatio = _pixelRatio;
  tester.view.physicalSize = Size(width, _viewportHeight);
  addTearDown(tester.view.reset);
  final chart = size == null
      ? DonutChart(
          segments: const [_segment],
          centerValue: name,
          centerLabel: _share,
        )
      : DonutChart(
          segments: const [_segment],
          centerValue: name,
          centerLabel: _share,
          size: size,
        );
  final body = Scaffold(body: Center(child: chart));
  final app = MaterialApp(theme: buildSpendWiseTheme(brightness), home: body);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

Rect _holeRect(WidgetTester tester) {
  final chart = tester.widget<PieChart>(find.byType(PieChart));
  final ringThickness = chart.data.sections.single.radius;
  final outerDiameter =
      (chart.data.centerSpaceRadius + ringThickness) * _diameterFactor;
  final innerDiameter = outerDiameter - ringThickness * _diameterFactor;
  return Rect.fromCenter(
    center: tester.getCenter(find.byType(DonutChart)),
    width: innerDiameter,
    height: innerDiameter,
  );
}

void _expectInsideHole(Rect label, Rect hole) {
  expect(hole.contains(label.topLeft), isTrue, reason: '$label exceeds $hole');
  expect(
    hole.contains(label.bottomRight),
    isTrue,
    reason: '$label exceeds $hole',
  );
  final radius = hole.width / _diameterFactor;
  final corners = [
    label.topLeft,
    label.topRight,
    label.bottomLeft,
    label.bottomRight,
  ];
  for (final corner in corners) {
    expect(
      (corner - hole.center).distance,
      lessThanOrEqualTo(radius + _geometryTolerance),
    );
  }
}

Future<void> _loadFonts() async {
  final loader = FontLoader(_fontFamily);
  for (final asset in _fontAssets) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
}
