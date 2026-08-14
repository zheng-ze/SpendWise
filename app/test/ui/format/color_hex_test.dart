import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/format/color_hex.dart';

void main() {
  group('parseColorHex', () {
    test('accepts a six-digit string with or without a leading hash', () {
      expect(parseColorHex('#FF8800'), const Color(0xFFFF8800));
      expect(parseColorHex('FF8800'), const Color(0xFFFF8800));
    });

    test('accepts lowercase and surrounding whitespace', () {
      expect(parseColorHex('  #ff8800 '), const Color(0xFFFF8800));
    });

    test('falls back to gray on malformed input', () {
      for (final bad in ['', '#FFF', 'GGGGGG', '#FF88000', 'not a color']) {
        expect(parseColorHex(bad), colorHexFallback, reason: bad);
      }
    });

    test('the fallback is desaturated, so a broken color reads as absent', () {
      final channels = [
        colorHexFallback.r,
        colorHexFallback.g,
        colorHexFallback.b,
      ];
      final spread =
          channels.reduce((a, b) => a > b ? a : b) -
          channels.reduce((a, b) => a < b ? a : b);
      expect(spread, lessThan(0.05));
      expect(colorHexFallback.a, 1.0);
    });
  });

  group('toColorHex', () {
    test('writes uppercase with a leading hash', () {
      expect(toColorHex(const Color(0xFFff8800)), '#FF8800');
    });

    test('drops alpha rather than encoding it', () {
      expect(toColorHex(const Color(0x00FF8800)), '#FF8800');
      expect(toColorHex(const Color(0x80FF8800)), '#FF8800');
    });

    test('pads components that need a leading zero', () {
      expect(toColorHex(const Color(0xFF000102)), '#000102');
    });

    test('round-trips a parsed color', () {
      expect(toColorHex(parseColorHex('#1A2B3C')), '#1A2B3C');
    });
  });
}
