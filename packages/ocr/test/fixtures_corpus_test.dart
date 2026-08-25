// Checks the corpus itself is well-formed. No ML Kit recognition runs here,
// since that needs a device this suite doesn't have.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ocr/ocr.dart';
import 'package:test/test.dart';

const _fixtureNames = [
  'fixture_01_grocery_total_keyword.png',
  'fixture_02_cafe_no_total_keyword.png',
  'fixture_03_hardware_iso_date.png',
  'fixture_04_pharmacy_written_date.png',
  'fixture_05_kiosk_tight_spacing.png',
  'fixture_06_restaurant_with_tip.png',
  'fixture_07_bookstore_currency_symbol.png',
  'fixture_08_gas_station_dense_numbers.png',
  'fixture_09_electronics_wide_layout.png',
  'fixture_10_farmers_market_no_keyword.png',
];

void main() {
  test('the corpus has between 8 and 12 fixtures', () {
    expect(_fixtureNames.length, inInclusiveRange(8, 12));
  });

  for (final name in _fixtureNames) {
    group(name, () {
      late File file;

      setUp(() {
        file = File('test/fixtures/$name');
      });

      test('exists and is a non-trivial file', () async {
        expect(
          file.existsSync(),
          isTrue,
          reason: '$name is missing from test/fixtures/',
        );
        final bytes = await file.readAsBytes();
        expect(bytes.length, greaterThan(1000));
      });

      test(
        'decodes as a real image with plausible receipt-photo dimensions',
        () async {
          final bytes = await file.readAsBytes();
          final image = await _decode(bytes);

          expect(image.width, greaterThan(100));
          expect(image.height, greaterThan(100));
        },
      );

      test('wraps into a RecognizableImage carrying the same bytes', () async {
        final bytes = await file.readAsBytes();
        final recognizable = RecognizableImage(bytes);

        expect(recognizable.bytes, bytes);
      });
    });
  }
}

Future<ui.Image> _decode(List<int> bytes) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
  final frame = await codec.getNextFrame();
  return frame.image;
}
