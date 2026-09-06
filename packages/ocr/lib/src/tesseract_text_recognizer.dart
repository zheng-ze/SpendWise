/// Platform-neutral facade for [TesseractTextRecognizer].
///
/// `dart:js_interop` does not exist for native (iOS/Android AOT)
/// compilation, so the real Tesseract.js-backed implementation can't be
/// imported unconditionally into this package — it's also compiled into
/// native builds via `MlKitTextRecognizer`. This conditional export resolves
/// to the throwing stub on native and to the real web implementation
/// wherever `dart.library.js_interop` is available.
library;

export 'tesseract_text_recognizer_stub.dart'
    if (dart.library.js_interop) 'tesseract_text_recognizer_web.dart';
