import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ocr/android/nano_field_extractor.dart';
import 'package:spendwise/ocr/field_extractor_selection.dart';
import 'package:spendwise/ocr/ios/foundation_models_field_extractor.dart';

void main() {
  group('selectFieldExtractor', () {
    group('Android', () {
      test(
        'returns null when the device fails the Nano eligibility check',
        () async {
          final extractor = await selectFieldExtractor(
            isWeb: false,
            isIOS: false,
            isNanoEligible: () async => false,
          );

          expect(extractor, isNull);
        },
      );

      test(
        'returns a NanoFieldExtractor when the device is eligible',
        () async {
          final extractor = await selectFieldExtractor(
            isWeb: false,
            isIOS: false,
            isNanoEligible: () async => true,
          );

          expect(extractor, isA<NanoFieldExtractor>());
        },
      );
    });

    group('iOS', () {
      test(
        'returns null when the device fails the Foundation Models eligibility check',
        () async {
          final extractor = await selectFieldExtractor(
            isWeb: false,
            isIOS: true,
            isFoundationModelsEligible: () async => false,
          );

          expect(extractor, isNull);
        },
      );

      test(
        'returns a FoundationModelsFieldExtractor when the device is eligible',
        () async {
          final extractor = await selectFieldExtractor(
            isWeb: false,
            isIOS: true,
            isFoundationModelsEligible: () async => true,
          );

          expect(extractor, isA<FoundationModelsFieldExtractor>());
        },
      );

      test('never checks Nano eligibility on iOS', () async {
        await selectFieldExtractor(
          isWeb: false,
          isIOS: true,
          isFoundationModelsEligible: () async => true,
          isNanoEligible: () async => fail('should not be called on iOS'),
        );
      });
    });
  });
}
