import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ocr/document_scanner_selection.dart';

void main() {
  group('selectDocumentScanner', () {
    test('has no scanner on web', () {
      final scanner = selectDocumentScanner(isWeb: true);

      expect(scanner, isNull);
    });

    test('picks a scanner on iOS', () {
      final scanner = selectDocumentScanner(isWeb: false, isIOS: true);

      expect(scanner, isNotNull);
    });

    test('picks a scanner on Android', () {
      final scanner = selectDocumentScanner(
        isWeb: false,
        isIOS: false,
        isAndroid: true,
      );

      expect(scanner, isNotNull);
    });

    test('has no scanner on an unrecognized platform', () {
      final scanner = selectDocumentScanner(
        isWeb: false,
        isIOS: false,
        isAndroid: false,
      );

      expect(scanner, isNull);
    });
  });
}
