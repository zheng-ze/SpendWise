import 'dart:typed_data';

import 'package:ocr/ocr.dart';
import 'package:test/test.dart';

void main() {
  test('a concrete class can implement the interface', () async {
    final TextRecognizer recognizer = _FakeTextRecognizer();
    final result = await recognizer.recognize(RecognizableImage(Uint8List(0)));

    expect(result.lines, isEmpty);
    await recognizer.dispose();
  });
}

class _FakeTextRecognizer implements TextRecognizer {
  @override
  Future<RecognizedText> recognize(RecognizableImage image) async {
    return RecognizedText(const []);
  }

  @override
  Future<void> dispose() async {}
}
