// Native builds cannot import the web check and web builds cannot import
// the native one, because each pulls libraries the other platform has no
// compiler support for. This picks the right one at build time.
import 'web/field_extraction_readiness_native.dart'
    if (dart.library.js_interop) 'web/field_extraction_readiness_web.dart'
    as readiness;

/// Whether the scan/upload strip should offer name/amount autofill right
/// now. Always true on iOS/Android — their own eligibility gaps are a
/// separate, still-open question (see issue #28) and don't hide the strip
/// yet. On web, this is false until Chrome's on-device model has finished
/// downloading, and starts that download as a side effect if it hasn't
/// started yet (see `chrome_prompt_api_availability.dart`).
Future<bool> isFieldExtractionReady() => readiness.isFieldExtractionReady();
