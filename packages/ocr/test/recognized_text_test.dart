import 'package:ocr/ocr.dart';
import 'package:test/test.dart';

void main() {
  test('holds lines in order', () {
    final text = RecognizedText([
      RecognizedLine(text: 'first'),
      RecognizedLine(text: 'second'),
    ]);

    expect(text.lines.map((l) => l.text), ['first', 'second']);
  });

  group('equality', () {
    test('same lines in the same order are equal', () {
      final a = RecognizedText([RecognizedLine(text: 'x')]);
      final b = RecognizedText([RecognizedLine(text: 'x')]);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different line order is not equal', () {
      final a = RecognizedText([
        RecognizedLine(text: 'x'),
        RecognizedLine(text: 'y'),
      ]);
      final b = RecognizedText([
        RecognizedLine(text: 'y'),
        RecognizedLine(text: 'x'),
      ]);

      expect(a, isNot(b));
    });
  });
}
