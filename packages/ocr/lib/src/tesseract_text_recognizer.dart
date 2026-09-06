/// `dart:js_interop` fails native AOT compilation, so this resolves to a
/// throwing stub natively and the real implementation only on web.
library;

export 'tesseract_text_recognizer_stub.dart'
    if (dart.library.js_interop) 'tesseract_text_recognizer_web.dart';
