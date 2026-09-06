import 'dart:typed_data';

import 'recognizable_image.dart';
import 'recognized_text.dart';
import 'text_recognizer.dart';

/// The engine calls [TesseractTextRecognizer] needs from Tesseract.js.
///
/// Kept free of any JS-interop types so both this stub and a hand-written
/// fake engine (used by browser-run unit tests) can implement it without
/// importing `dart:js_interop` or `package:web`. [recognize] returns
/// Tesseract.js's page result as a plain Dart map, following its
/// `RecognizeResult.data` (`Page`) shape:
/// `{'blocks': [{'paragraphs': [{'lines': [{'text', 'confidence',
/// 'rowAttributes': {'rowHeight'}, 'bbox': {'x0', 'y0', 'x1', 'y1'}},
/// ...]}, ...]}, ...]}`.
abstract class TesseractEngine {
  /// [blocks] is always `true` in production; [TesseractTextRecognizer]
  /// requests block/paragraph/line geometry on every call. It's a parameter
  /// rather than hardcoded here so a fake engine can assert it was
  /// requested.
  Future<Map<String, Object?>> recognize(
    Uint8List bytes, {
    required bool blocks,
  });

  /// Releases the underlying Tesseract.js worker.
  Future<void> terminate();
}

/// Native stub. Never actually constructed: `selectRecognizer()` only
/// selects this recognizer on web, so native compilation just needs the
/// class and its supertype to resolve.
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
