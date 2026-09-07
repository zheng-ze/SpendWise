import 'package:flutter_test/flutter_test.dart';
import 'package:ocr/ocr.dart';
import 'package:spendwise/ocr/receipt_recognizer_selection.dart';

void main() {
  group('selectRecognizer', () {
    test('returns the injected vision recognizer on iOS', () {
      final fakeVision = FakeTextRecognizer();

      final recognizer =
          selectRecognizer(isIOS: true, visionFactory: () => fakeVision);

      expect(recognizer, same(fakeVision));
    });

    test('returns the injected android recognizer on android', () {
      final fakeAndroid = FakeTextRecognizer();

      final recognizer = selectRecognizer(
        isIOS: false,
        isAndroid: true,
        androidFactory: () => fakeAndroid,
      );

      expect(recognizer, same(fakeAndroid));
    });

    test('returns null when neither iOS nor android is selected', () {
      final recognizer =
          selectRecognizer(isIOS: false, isAndroid: false);

      expect(recognizer, isNull);
    });
  });
}

class FakeTextRecognizer extends TextRecognizer {
  @override
  Future<RecognizedText> recognize(RecognizableImage image) =>
      throw UnimplementedError();

  @override
  Future<void> dispose() => throw UnimplementedError();
}
