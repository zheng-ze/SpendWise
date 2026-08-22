import 'package:ocr/ocr.dart';
import 'package:test/test.dart';

void main() {
  test('message round-trips', () {
    const failure = TextRecognitionFailure('engine-x: decode failed');

    expect(failure.message, 'engine-x: decode failed');
  });

  test('is an Exception', () {
    const failure = TextRecognitionFailure('boom');

    expect(failure, isA<Exception>());
  });

  group('equality', () {
    test('failures with the same message are equal', () {
      const a = TextRecognitionFailure('boom');
      const b = TextRecognitionFailure('boom');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('failures with different messages are not equal', () {
      const a = TextRecognitionFailure('boom');
      const b = TextRecognitionFailure('bang');

      expect(a, isNot(b));
    });
  });
}
