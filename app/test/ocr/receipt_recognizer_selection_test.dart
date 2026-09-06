import 'package:flutter_test/flutter_test.dart';
import 'package:ocr/ocr.dart';
import 'package:spendwise/ocr/receipt_recognizer_selection.dart';

void main() {
  group('selectRecognizer', () {
    test('picks VisionTextRecognizer on iOS', () {
      final recognizer = selectRecognizer(isWeb: false, isIOS: true);

      expect(recognizer, isA<VisionTextRecognizer>());
    });

    test('picks AndroidTextRecognizer off the web branch on non-iOS', () {
      final recognizer = selectRecognizer(isWeb: false, isIOS: false);

      expect(recognizer, isA<AndroidTextRecognizer>());
    });

    test(
      'defaults to the real kIsWeb/isIOSPlatform constants when omitted',
      () {
        // flutter test always runs on the VM (never web) and never on iOS, so
        // this lands on AndroidTextRecognizer here.
        final recognizer = selectRecognizer();

        expect(recognizer, isA<AndroidTextRecognizer>());
      },
    );
  });
}
