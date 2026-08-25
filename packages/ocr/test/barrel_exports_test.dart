import 'dart:typed_data';

import 'package:ocr/ocr.dart';
import 'package:test/test.dart';

void main() {
  test('every value type is nameable through the barrel alone', () {
    final image = RecognizableImage(Uint8List(0));
    const bounds = RecognizedLineBounds(top: 0, bottom: 1, left: 0, right: 1);
    final line = RecognizedLine(text: 'x', bounds: bounds);
    final text = RecognizedText([line]);
    const failure = TextRecognitionFailure('x');

    expect(image, isA<RecognizableImage>());
    expect(text.lines.single, line);
    expect(failure, isA<Exception>());
  });
}
