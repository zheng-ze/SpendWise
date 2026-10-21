import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/common/charts/category_map.dart';
import 'package:spendwise/ui/theme/category_palette.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

import '../../../support/ui_test_timeout.dart';

const _mapWidth = 300.0;
const _fullShare = 1.0;
const _tinyShare = 0.001;
const _largeShare = 0.999;
const _zeroShare = 0.0;
const _ranks = 8;
const _largeTextScale = 2.0;
const _defaultTextScale = 1.0;
const _lightFill = Color(0xFFFFFFFF);
const _darkFill = Color(0xFF101112);

void main() {
  for (final brightness in Brightness.values) {
    _registerThemeTests(brightness);
  }
}

void _registerThemeTests(Brightness brightness) {
  for (var rank = 0; rank < _ranks; rank++) {
    testWidgets('$brightness ramp rank $rank uses its rendered fill', (
      tester,
    ) async {
      final colors = _colors(brightness);
      final fill = CategoryPalette.resolve(
        savedHex: null,
        rank: rank,
        mode: ChartColours.themeShades,
        colors: colors,
      );
      await _expectBlock(tester, brightness, fill, selected: false);
    }, timeout: uiTestTimeout);
  }
  _registerSavedFillTest(brightness, '#34C759');
  _registerSavedFillTest(brightness, '#FFCC00');
  testWidgets('$brightness selection label uses selectedMark', (tester) async {
    final fill = brightness == Brightness.light ? _lightFill : _darkFill;
    await _expectBlock(tester, brightness, fill, selected: false);
    await _expectBlock(tester, brightness, fill, selected: true);
  }, timeout: uiTestTimeout);
  testWidgets('$brightness tiny adjacent labels retain subtext and selection', (
    tester,
  ) async {
    await _expectAdjacent(tester, brightness);
  }, timeout: uiTestTimeout);
}

void _registerSavedFillTest(Brightness brightness, String savedHex) {
  testWidgets('$brightness saved fill $savedHex chooses its foreground', (
    tester,
  ) async {
    final fill = CategoryPalette.resolve(
      savedHex: savedHex,
      rank: 0,
      mode: ChartColours.categoryColours,
      colors: _colors(brightness),
    );
    await _expectBlock(tester, brightness, fill, selected: false);
  }, timeout: uiTestTimeout);
}

SpendWiseColors _colors(Brightness brightness) => brightness == Brightness.light
    ? SpendWiseColors.light
    : SpendWiseColors.dark;

Widget _host(
  Brightness brightness,
  CategoryMap map, {
  double textScale = _defaultTextScale,
}) {
  final sizedMap = SizedBox(width: _mapWidth, child: map);
  final mediaData = MediaQueryData(textScaler: TextScaler.linear(textScale));
  final body = MediaQuery(data: mediaData, child: sizedMap);
  return MaterialApp(
    theme: buildSpendWiseTheme(brightness),
    home: Scaffold(body: body),
  );
}

Future<void> _expectBlock(
  WidgetTester tester,
  Brightness brightness,
  Color fill, {
  required bool selected,
}) async {
  final tile = CategoryMapTile(
    label: 'Category',
    share: _fullShare,
    color: fill,
  );
  final map = CategoryMap(tiles: [tile], selectedIndex: selected ? 0 : null);
  await tester.pumpWidget(_host(brightness, map));
  final labelFinder = find.text('Category\n100.0%');
  final label = tester.widget<Text>(labelFinder);
  final containerFinder = find.ancestor(
    of: labelFinder,
    matching: find.byType(Container),
  );
  final container = tester.widget<Container>(containerFinder.first);
  final decoration = container.decoration;
  expect(decoration, isA<BoxDecoration>());
  if (decoration is! BoxDecoration) return;
  final actualFill = selected ? _colors(brightness).selectedMark : fill;
  expect(decoration.color, actualFill);
  expect(label.style?.color, foregroundOn(actualFill));
  expect(tester.takeException(), isNull);
}

Future<void> _expectAdjacent(WidgetTester tester, Brightness brightness) async {
  var selected = -1;
  const tiles = [
    CategoryMapTile(label: 'Big', share: _largeShare, color: _lightFill),
    CategoryMapTile(label: 'Tiny', share: _tinyShare, color: _lightFill),
    CategoryMapTile(label: 'Zero', share: _zeroShare, color: _lightFill),
  ];
  final map = CategoryMap(
    tiles: tiles,
    selectedIndex: 1,
    onSelect: (i) => selected = i,
  );
  await tester.pumpWidget(_host(brightness, map, textScale: _largeTextScale));
  final labelFinder = find.text('Tiny 0.1%');
  final label = tester.widget<Text>(labelFinder);
  expect(label.style?.color, _colors(brightness).subtext);
  expect(find.textContaining('Tiny\n'), findsNothing);
  expect(find.textContaining('Zero'), findsNothing);
  await tester.tap(labelFinder);
  expect(selected, 1);
  expect(tester.takeException(), isNull);
}
