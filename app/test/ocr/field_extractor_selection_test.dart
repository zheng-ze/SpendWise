import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ocr/android/nano_field_extractor.dart';
import 'package:spendwise/ocr/field_extractor_selection.dart';

void main() {
  group('selectFieldExtractor', () {
    test(
      'returns null when the device fails the Nano eligibility check',
      () async {
        final extractor = await selectFieldExtractor(
          isNanoEligible: () async => false,
        );

        expect(extractor, isNull);
      },
    );

    test('returns a NanoFieldExtractor when the device is eligible', () async {
      final extractor = await selectFieldExtractor(
        isNanoEligible: () async => true,
      );

      expect(extractor, isA<NanoFieldExtractor>());
    });
  });
}
