import 'dart:typed_data';

import 'package:ocr/ocr.dart';
import 'package:test/test.dart';

void main() {
  group('equality', () {
    test('same bytes are equal', () {
      final a = RecognizableImage(Uint8List.fromList([1, 2, 3]));
      final b = RecognizableImage(Uint8List.fromList([1, 2, 3]));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different bytes are not equal', () {
      final a = RecognizableImage(Uint8List.fromList([1, 2, 3]));
      final b = RecognizableImage(Uint8List.fromList([1, 2, 4]));

      expect(a, isNot(b));
    });

    test('different lengths are not equal', () {
      final a = RecognizableImage(Uint8List.fromList([1, 2, 3]));
      final b = RecognizableImage(Uint8List.fromList([1, 2]));

      expect(a, isNot(b));
    });
  });
}
