import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/theme/category_palette.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/format/color_hex.dart';

const _channelTolerance = 1 / 255;
const _hueTolerance = 1.0;
const _saturationTolerance = 0.015;
const _lightGrayFallback = 0xFF808085;
const _darkGrayFallback = 0xFFA2A2A6;

const _lightRamp = <int>[
  0xFF205F83,
  0xFF306A8C,
  0xFF407695,
  0xFF50819E,
  0xFF608DA6,
  0xFF7098AF,
  0xFF80A4B8,
  0xFF90AFC1,
];
const _darkRamp = <int>[
  0xFF98C5E8,
  0xFF8FB9DA,
  0xFF86ADCB,
  0xFF7DA1BD,
  0xFF7595AF,
  0xFF6C89A0,
  0xFF637D92,
  0xFF5A7184,
];

const _lightMarks = <int>[
  0xFF29755E,
  0xFF237642,
  0xFF257B66,
  0xFF986421,
  0xFF6861A4,
  0xFF28684F,
  0xFF8A4F7D,
  0xFF5B6B78,
];
const _darkMarks = <int>[
  0xFF8FC69B,
  0xFF82C68F,
  0xFF84CDB9,
  0xFFE6B679,
  0xFFB5A9E6,
  0xFFA4D5B5,
  0xFFD9A8CC,
  0xFFAEB9C2,
];

void main() {
  test('theme shades resolve every sRGB ramp rank and wrap in both themes', () {
    _expectRanks(SpendWiseColors.light, ChartColours.themeShades, _lightRamp);
    _expectRanks(SpendWiseColors.dark, ChartColours.themeShades, _darkRamp);
  });
  test(
    'contrasting resolves the fixed mark order and wraps in both themes',
    () {
      _expectRanks(
        SpendWiseColors.light,
        ChartColours.contrasting,
        _lightMarks,
      );
      _expectRanks(SpendWiseColors.dark, ChartColours.contrasting, _darkMarks);
    },
  );

  test(
    'saved RGB values map to exactly six theme counterparts after parsing',
    () {
      _expectSaved(SpendWiseColors.light, _lightMarks);
      _expectSaved(SpendWiseColors.dark, _darkMarks);
    },
  );
  test(
    'unmapped colours preserve hue and saturation with bounded lightness',
    () {
      _expectUnmapped(SpendWiseColors.light, _lightUnmapped);
      _expectUnmapped(SpendWiseColors.dark, _darkUnmapped);
    },
  );
  test('null and malformed hex use the clamped gray fallback', () {
    _expectFallback(SpendWiseColors.light, _lightGrayFallback);
    _expectFallback(SpendWiseColors.dark, _darkGrayFallback);
  });
  test('lightness bounds equal the extrema of the eight theme marks', () {
    _expectBounds(SpendWiseColors.light, _lightMarks);
    _expectBounds(SpendWiseColors.dark, _darkMarks);
  });
}

void _expectRanks(
  SpendWiseColors colors,
  ChartColours mode,
  List<int> expected,
) {
  for (var rank = 0; rank < expected.length * 2; rank++) {
    final actual = CategoryPalette.resolve(
      savedHex: rank.isEven ? '#34C759' : null,
      rank: rank,
      mode: mode,
      colors: colors,
    );
    expect(
      actual.toARGB32(),
      expected[rank % expected.length],
      reason: '$mode rank $rank',
    );
    expect(actual, isNot(colors.selectedMark));
  }
}

const _lightUnmapped = <String, int>{
  '#010203': 0xFF24486C,
  '#FAF0E6': 0xFFD58330,
  '#607080': 0xFF607080,
  '#FF3B30': 0xFFFF1306,
  '#FFCC00': 0xFFFFCC00,
  '#5AC8FA': 0xFF0DAEF8,
  '#AF52DE': 0xFF9E2ED7,
  '#8E8E93': 0xFF808085,
  '#8A4F7D': 0xFF8A4F7D,
  '#5B6B78': 0xFF5B6B78,
};

const _darkUnmapped = <String, int>{
  '#010203': 0xFF77A4D2,
  '#FAF0E6': 0xFFEDC8A3,
  '#607080': 0xFF97A4B1,
  '#FF3B30': 0xFFFF5349,
  '#FFCC00': 0xFFFFDB49,
  '#5AC8FA': 0xFF5AC8FA,
  '#AF52DE': 0xFFB866E2,
  '#8E8E93': 0xFFA2A2A6,
  '#8A4F7D': 0xFFBD8BB2,
  '#5B6B78': 0xFF97A5B1,
};

void _expectSaved(SpendWiseColors colors, List<int> marks) {
  const saved = ['34c759', '30d158', '63e6be', 'ff9500', '5856d6', '007aff'];
  for (var index = 0; index < saved.length; index++) {
    _expectCategory(colors, saved[index], marks[index]);
    _expectCategory(colors, ' #${saved[index].toUpperCase()} ', marks[index]);
  }
}

void _expectUnmapped(SpendWiseColors colors, Map<String, int> expected) {
  for (final entry in expected.entries) {
    final actual = CategoryPalette.resolve(
      savedHex: entry.key,
      rank: 0,
      mode: ChartColours.categoryColours,
      colors: colors,
    );
    final expectedColor = Color(entry.value);
    final originalHsl = HSLColor.fromColor(parseColorHex(entry.key));
    final actualHsl = HSLColor.fromColor(actual);
    expect(actualHsl.hue, closeTo(originalHsl.hue, _hueTolerance));
    expect(
      actualHsl.saturation,
      closeTo(originalHsl.saturation, _saturationTolerance),
    );
    expect(actual.r, closeTo(expectedColor.r, _channelTolerance));
    expect(actual.g, closeTo(expectedColor.g, _channelTolerance));
    expect(actual.b, closeTo(expectedColor.b, _channelTolerance));
  }
}

void _expectFallback(SpendWiseColors colors, int expected) {
  const invalidHexes = <String?>[null, '', '#123', '#GGGGGG', '#8034C759'];
  for (final hex in invalidHexes) {
    _expectCategory(colors, hex, expected);
  }
}

void _expectCategory(SpendWiseColors colors, String? hex, int expected) {
  final actual = CategoryPalette.resolve(
    savedHex: hex,
    rank: 3,
    mode: ChartColours.categoryColours,
    colors: colors,
  );
  expect(actual.toARGB32(), expected, reason: '$hex on ${colors.surface}');
  expect(actual, isNot(colors.selectedMark));
}

void _expectBounds(SpendWiseColors colors, List<int> marks) {
  final lightnesses =
      marks.map((mark) => HSLColor.fromColor(Color(mark)).lightness).toList()
        ..sort();
  final darkest = CategoryPalette.resolve(
    savedHex: '#000000',
    rank: 0,
    mode: ChartColours.categoryColours,
    colors: colors,
  );
  final lightest = CategoryPalette.resolve(
    savedHex: '#FFFFFF',
    rank: 0,
    mode: ChartColours.categoryColours,
    colors: colors,
  );
  final minimum = HSLColor.fromColor(darkest).lightness;
  final maximum = HSLColor.fromColor(lightest).lightness;
  expect(minimum, closeTo(lightnesses.first, _channelTolerance));
  expect(maximum, closeTo(lightnesses.last, _channelTolerance));
}
