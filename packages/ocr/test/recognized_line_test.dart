import 'package:ocr/ocr.dart';
import 'package:test/test.dart';

void main() {
  group('RecognizedLine.recognizedLanguages', () {
    test('defaults to an empty list, not null', () {
      final line = RecognizedLine(text: 'hello');

      expect(line.recognizedLanguages, isEmpty);
      expect(line.recognizedLanguages, isNotNull);
    });

    test('keeps a supplied list', () {
      final line = RecognizedLine(text: 'hola', recognizedLanguages: ['es']);

      expect(line.recognizedLanguages, ['es']);
    });
  });

  group('RecognizedLine equality', () {
    test('lines with the same fields are equal', () {
      final a = RecognizedLine(
        text: 'hello',
        confidence: 0.9,
        recognizedLanguages: const ['en'],
      );
      final b = RecognizedLine(
        text: 'hello',
        confidence: 0.9,
        recognizedLanguages: const ['en'],
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('lines differing in text are not equal', () {
      final a = RecognizedLine(text: 'hello');
      final b = RecognizedLine(text: 'goodbye');

      expect(a, isNot(b));
    });

    test('lines differing in recognizedLanguages are not equal', () {
      final a = RecognizedLine(text: 'hi', recognizedLanguages: const ['en']);
      final b = RecognizedLine(text: 'hi', recognizedLanguages: const ['fr']);

      expect(a, isNot(b));
    });
  });
}
