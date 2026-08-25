import 'package:flutter_test/flutter_test.dart';
import 'package:ocr/ocr.dart';
import 'package:spendwise/ocr/receipt_recognizer_selection.dart';

void main() {
  group('selectRecognizer', () {
    test('picks MlKitTextRecognizer off the web branch', () {
      final recognizer = selectRecognizer(isWeb: false);

      expect(recognizer, isA<MlKitTextRecognizer>());
    });

    test('has no engine on web yet, so the web branch stays null', () {
      final recognizer = selectRecognizer(isWeb: true);

      expect(recognizer, isNull);
    });

    test('defaults to the real kIsWeb constant when isWeb is omitted', () {
      // flutter test always runs on the VM, so kIsWeb is false here.
      final recognizer = selectRecognizer();

      expect(recognizer, isA<MlKitTextRecognizer>());
    });
  });
}
