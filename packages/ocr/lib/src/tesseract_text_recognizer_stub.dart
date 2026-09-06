import 'dart:typed_data';

import 'recognizable_image.dart';
import 'recognized_text.dart';
import 'text_recognizer.dart';

/// [recognize] returns untyped-key maps: `dartify()` nests
/// `Map<Object?, Object?>` for every JS object, so a String-keyed map here
/// would throw a cast error on real Tesseract.js output.
abstract class TesseractEngine {
  /// Always `true` in production; a parameter so a fake can assert it was
  /// requested.
  Future<Map<Object?, Object?>> recognize(
    Uint8List bytes, {
    required bool blocks,
  });

  Future<void> terminate();
}

/// Never constructed: `selectRecognizer()` only picks this on web, so
/// native compilation just needs the class to resolve.
class TesseractTextRecognizer implements TextRecognizer {
  TesseractTextRecognizer({TesseractEngine? engine}) {
    throw UnsupportedError('TesseractTextRecognizer is web-only');
  }

  @override
  Future<RecognizedText> recognize(RecognizableImage image) {
    throw UnsupportedError('TesseractTextRecognizer is web-only');
  }

  @override
  Future<void> dispose() {
    throw UnsupportedError('TesseractTextRecognizer is web-only');
  }
}
