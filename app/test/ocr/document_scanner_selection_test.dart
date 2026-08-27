import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ocr/document_scanner_selection.dart';

void main() {
  group('selectDocumentScanner', () {
    test('has no scanner on web', () async {
      final scanner = await selectDocumentScanner(isWeb: true);

      expect(scanner, isNull);
    });

    test('picks a scanner on iOS', () async {
      final scanner = await selectDocumentScanner(isWeb: false, isIOS: true);

      expect(scanner, isNotNull);
    });

    group('Android', () {
      test(
        'returns null when the device fails the eligibility check',
        () async {
          final scanner = await selectDocumentScanner(
            isWeb: false,
            isIOS: false,
            isAndroid: true,
            isAndroidScannerEligible: () async => false,
          );

          expect(scanner, isNull);
        },
      );

      test('returns a scanner when the device is eligible', () async {
        final scanner = await selectDocumentScanner(
          isWeb: false,
          isIOS: false,
          isAndroid: true,
          isAndroidScannerEligible: () async => true,
        );

        expect(scanner, isNotNull);
      });
    });

    test('has no scanner on an unrecognized platform', () async {
      final scanner = await selectDocumentScanner(
        isWeb: false,
        isIOS: false,
        isAndroid: false,
      );

      expect(scanner, isNull);
    });
  });
}
