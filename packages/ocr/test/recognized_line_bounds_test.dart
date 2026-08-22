import 'package:ocr/ocr.dart';
import 'package:test/test.dart';

void main() {
  group('RecognizedLineBounds.height', () {
    test('computes bottom minus top', () {
      const bounds = RecognizedLineBounds(
        top: 10,
        bottom: 25,
        left: 0,
        right: 100,
      );

      expect(bounds.height, 15);
    });

    test('is negative if bottom is above top', () {
      const bounds = RecognizedLineBounds(
        top: 25,
        bottom: 10,
        left: 0,
        right: 100,
      );

      expect(bounds.height, -15);
    });
  });

  group('RecognizedLineBounds equality', () {
    test('bounds with the same values are equal', () {
      const a = RecognizedLineBounds(top: 1, bottom: 2, left: 3, right: 4);
      const b = RecognizedLineBounds(top: 1, bottom: 2, left: 3, right: 4);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('bounds differing in one value are not equal', () {
      const a = RecognizedLineBounds(top: 1, bottom: 2, left: 3, right: 4);
      const b = RecognizedLineBounds(top: 1, bottom: 2, left: 3, right: 99);

      expect(a, isNot(b));
    });
  });
}
