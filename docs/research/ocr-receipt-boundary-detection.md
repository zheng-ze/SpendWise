# Receipt document-boundary detection: platform capabilities and architecture fit

Research for GitHub issue #19 (`zheng-ze/SpendWise`), which asks how to detect a receipt's document
boundary in a captured or live-preview image so OCR reads only the receipt and not surrounding
scene. Sources are Google's ML Kit reference docs and Android developer blog, Apple's Vision/
VisionKit API reference pages and the WWDC21 session "Extract document data using Vision" (session
234's successor for this specific API), the W3C/WICG Shape Detection API spec and Chrome's own
capabilities doc, and this repo's own `packages/ocr/lib/` source, checked as of 2026-08-27.

**Method note**: as with `docs/research/ocr-vision-vs-mlkit-ios-accuracy.md`, several
`developer.apple.com/documentation/...` pages render via JavaScript and returned only a page title
to automated fetch, not body content. Apple primary-source claims below are corroborated through
independent search aggregation of the same pages (multiple independent queries converging on the
same quotes and facts, including one that surfaced a direct transcript quote from the WWDC21
session itself) rather than a single raw fetch. Flagged inline wherever a claim rests on
aggregation rather than a direct fetch of Apple's page.

## Question

1. What does each platform's first-party document/rectangle-detection primitive return — a
   quadrilateral, a perspective-corrected crop, both — and does it expose a confidence or
   no-detection signal?
2. Can detection run per-frame on a live camera feed, or is it capture-only?
3. Does a web-native equivalent exist?
4. Does this fit as a new method on `packages/ocr`'s `TextRecognizer`, or does it need its own seam?
5. Is live-feed detection (issue #20's gating question) realistic at 15-30fps?

## Android: ML Kit Document Scanner (`GmsDocumentScanner`)

- **What it is**: a self-contained scanning UI, not a callable detection function. Google's own
  overview states it "provides a high-quality fully fledged UI flow that is consistent across
  Android apps," with "a dedicated viewfinder screen and preview screen provided by the SDK"
  ([developers.google.com/ml-kit/vision/doc-scanner](https://developers.google.com/ml-kit/vision/doc-scanner)).
  The app launches this UI via `GmsDocumentScanning.getClient(options).getStartScanIntent(activity)`
  and receives a result in `onActivityResult`/the Activity Result API — the app never gets a
  detection callback per frame, and does not drive its own camera preview against this API at all.
- **What it returns**: `GmsDocumentScanningResult`, retrieved via
  `GmsDocumentScanningResult.fromActivityResultIntent(data)`. Its documented surface is `getPages()`
  (a list of `Page` objects, each carrying an image URI — `getImageUri()` — for the
  already-perspective-corrected, cropped page) and `getPdf()` for the multi-page PDF output
  ([developers.google.com/android/reference/.../GmsDocumentScanningResult](https://developers.google.com/android/reference/com/google/mlkit/vision/documentscanner/GmsDocumentScanningResult),
  corroborated by usage in
  [Android Developers Blog, Feb 2024](https://android-developers.googleblog.com/2024/02/ml-kit-document-scanner-api.html)
  and independent tutorials). **No corner-point quadrilateral and no numeric confidence score are
  exposed anywhere in this API's documented surface** — the API hands back only a finished, cropped
  image per page. This is a materially different output shape from iOS's Vision-level primitive
  (below): Android's first-party API is scan-and-crop-only, with no lower-level "just tell me the
  quad and a confidence" primitive documented alongside it.
- **No-detection signal**: no explicit "no document detected" result code is documented. The
  activity result is binary — `RESULT_OK` (user completed a scan) or `RESULT_CANCELED` (user backed
  out) — corroborated by multiple independent tutorials and this API's own Activity Result contract.
  There is no mid-scan "detection confidence" the app can read; detection quality is entirely
  internal to the SDK's own UI, which guides the user to a good capture rather than reporting a
  score back to the caller.
- **Live-feed feasibility**: **not applicable as a per-frame primitive** — this API is capture-flow
  only. It "manages camera access through Google Play Services" and needs "no camera permission...
  from your app," which is itself evidence the app cannot drive its own camera preview against this
  API — Play Services owns the camera surface for the duration of the scan
  ([developers.google.com/ml-kit/vision/doc-scanner](https://developers.google.com/ml-kit/vision/doc-scanner)).
  Building a custom live-preview overlay (issue #20's ask) against this specific API is not an
  option; it would require CameraX or a different lower-level primitive instead, per independent
  developer guidance converging on the same conclusion.
- **Delivery/platform notes**: models are "delivered using Google Play services," which the docs
  describe as an on-demand, not always-installed, dependency; the API requires a Play Services
  device, so no coverage on AOSP-without-Play-Services devices. Documented three edit modes
  (`SCANNER_MODE_BASE`, `SCANNER_MODE_BASE_WITH_FILTER`, `SCANNER_MODE_FULL`) via
  `GmsDocumentScannerOptions`.
- **Flutter binding**: no first-party Flutter plugin from Google (same situation ADR-0051 already
  found for ML Kit's core text recognizer being first-party while Vision has none). Community
  wrappers exist —`google_mlkit_document_scanner` and `mlkit_document_scanner`, both on pub.dev —
  the former's own listing states it is "not sponsored or maintained by Google," and one source
  notes ML Kit Document Scanner itself is still in beta and Android-only. Neither changes the
  underlying API's return shape or camera-ownership model described above.

## iOS: two different Vision-family primitives, not one

Issue #19 named `VNDocumentCameraViewController` and `VNDetectRectanglesRequest` together, but they
turn out to be a self-contained capture UI plus an **older** lower-level primitive. A third,
newer primitive — `VNDetectDocumentSegmentationRequest` (introduced WWDC21, iOS 15+) — is the one
that actually matters for this ticket, and `VNDocumentCameraViewController` itself has been
rebuilt on top of it on modern hardware. All three are covered below since the ticket's own
wording named the first two; the third is the one this research recommends building against.

### `VNDocumentCameraViewController` (VisionKit) — self-contained capture UI

- **What it is**: a complete, pre-built camera UI the app presents modally
  (`present(controller, animated: true)`) and receives results from via
  `VNDocumentCameraViewControllerDelegate`'s
  `documentCameraViewController(_:didFinishWith:)` callback
  ([developer.apple.com/documentation/visionkit/vndocumentcameraviewcontrollerdelegate/documentcameraviewcontroller(_:didfinishwith:)](https://developer.apple.com/documentation/visionkit/vndocumentcameraviewcontrollerdelegate/documentcameraviewcontroller(_:didfinishwith:)),
  corroborated by multiple independent tutorials —
  [hackingwithswift.com](https://www.hackingwithswift.com/example-code/vision/how-to-detect-documents-using-vndocumentcameraviewcontroller),
  [scanbot.io](https://scanbot.io/techblog/vndocumentcameraviewcontroller-ios-document-scanner-tutorial/)).
  Like Android's Document Scanner, the app does not drive its own camera preview against this
  class — VisionKit owns the capture surface end to end.
- **What it returns**: a `VNDocumentCameraScan` with a page count and, per page,
  `scan.imageOfPage(at: i)` returning an already-perspective-corrected `UIImage`. No corner-point
  quadrilateral and no confidence score are exposed on `VNDocumentCameraScan` itself — same
  finished-crop-only shape as Android's Document Scanner result.
- **Live-feed feasibility**: not applicable, for the same reason as Android — it is a capture flow,
  not a per-frame callback the app can drive against arbitrary frames.
- **Platform note**: iOS 13.0+ minimum for the class itself.

### `VNDetectRectanglesRequest` — general-purpose rectangle detector, classic CV

- **What it returns**: `VNRectangleObservation` objects, each with four corner points
  (`topLeft`, `topRight`, `bottomLeft`, `bottomRight`) and a `confidence` score (0.0-1.0)
  ([developer.apple.com/documentation/vision/vndetectrectanglesrequest](https://developer.apple.com/documentation/vision/vndetectrectanglesrequest),
  corroborated independently). Configurable via `minimumConfidence`, `minimumAspectRatio`, and
  `maximumObservations`. This is a general shape-detector, not document-specific — it will happily
  find a phone screen, a picture frame, or a table edge, with no notion that "receipt" is the
  target shape; the caller filters by aspect ratio/size/confidence itself.
- **No-detection signal**: an empty `results` array — the request never returns a placeholder or
  guaranteed observation.
- **Live-feed feasibility**: **yes, and this is Apple's own stated reason this class existed before
  the newer segmentation request** — it "is a traditional computer vision algorithm that runs only
  on the CPU and can keep up with realtime performance, as long as the CPU is not saturated with
  other tasks" (independent search aggregation of Apple's WWDC21 session content, corroborated
  across multiple sources). It's driven via `VNSequenceRequestHandler` for a video/frame sequence
  or `VNImageRequestHandler` per still frame, both feeding from
  `AVCaptureVideoDataOutputSampleBufferDelegate`'s sample buffers — the standard "drive Vision
  against my own `AVCaptureSession`" pattern independent tutorials
  ([dabblingbadger.com](https://www.dabblingbadger.com/blog/2020/2/10/rectangle-detection),
  a from-scratch real-time Swift walkthrough on Medium) both demonstrate directly. Because it's
  CPU-bound classic CV rather than a learned model, its realtime claim doesn't depend on Neural
  Engine hardware the way the newer request does (below) — but it is a plain edge/contour-based
  rectangle finder, not trained to recognize "this quad is a document" specifically, so it is more
  prone to false positives on background clutter (the exact problem issue #19 exists to solve).

### `VNDetectDocumentSegmentationRequest` — the modern, document-specific primitive (recommended)

This is the API this research recommends building against, and it wasn't named in the ticket's own
wording — surfaced only by researching what actually backs `VNDocumentCameraViewController` today.

- **What it returns**: per Apple's own WWDC21 session 10041 ("Extract document data using Vision"),
  quoted directly via independent transcript/search aggregation: "The result of the request is a
  low resolution segmentation mask, where each pixel represents a confidence if that pixel is part
  of the detected document or not. In addition it provides the four corner points of the
  quadrilateral." Results come back as `VNRectangleObservation` (same result type as the older
  rectangle request), so the same `topLeft`/`topRight`/`bottomLeft`/`bottomRight` corner-point shape
  applies, plus the segmentation mask as an additional signal `VNDetectRectanglesRequest` doesn't
  have. Apple's own demo code in that session:

  ```swift
  let requestHandler = VNImageRequestHandler(ciImage: inputImage)
  let documentDetectionRequest = VNDetectDocumentSegmentationRequest()
  try requestHandler.perform([documentDetectionRequest])
  guard let document = documentDetectionRequest.results?.first,
        let documentImage = perspectiveCorrectedImage(from: inputImage, rectangleObservation: document)
  else { fatalError("Unable to get document image.") }
  ```

  — confirming the perspective-corrected crop is something the *app* computes from the returned
  corner points (via a helper like `perspectiveCorrectedImage`), not something the request hands
  back pre-cropped the way the two capture-UI-level APIs above do.
- **No-detection signal**: an empty/nil `results` array when nothing is found, same convention as
  `VNDetectRectanglesRequest`; per-pixel confidence lives inside the segmentation mask for finer
  signal than a single scalar.
- **Live-feed feasibility — the key finding for issue #20**: directly asymmetric by hardware, per
  the same WWDC21 session: **"On devices with a Neural Engine, the request can run in realtime on a
  camera or video feed."** Without one: **"it can also be used on the GPU or CPU, but it is not
  fast enough there for realtime performance."** This is a machine-learning-based request (unlike
  the classic-CV `VNDetectRectanglesRequest`), so its realtime claim is conditioned on Neural Engine
  availability — every iPhone capable of running this app already has a Neural Engine (A11 chip,
  2017, was Apple's first), so in practice this is realtime-capable on all real-world iOS 15+
  target devices, not a hardware caveat likely to bite.
- **Relationship to `VNDocumentCameraViewController`**: the same session states plainly that
  VisionKit's own capture UI now uses this request internally: "The VNDocumentCamera in VisionKit
  is now using the request instead of the VNDetectRectanglesRequest on modern devices with a Neural
  Engine." This confirms `VNDetectDocumentSegmentationRequest` is the same detector already proven
  in Apple's own shipping capture UI, not an experimental side path.
- **Platform note**: iOS 15.0+ (also macOS 12.0+, Mac Catalyst 15.0+, tvOS 15.0+), per independent
  search aggregation of Apple's reference page and Microsoft's .NET-for-iOS binding docs (which
  mirror Apple's own availability annotations). This repo's iOS deployment target is already 15.5
  (`docs/adr/` commit history / this repo's recent `90e5cb1` bump for `google_mlkit_text_recognition`),
  so this request introduces no new minimum-OS cost.

## Web: no native equivalent; mobile-only capability, confirmed

- **Shape Detection API** (`FaceDetector`, `BarcodeDetector`, `TextDetector`) is the only
  browser-native candidate that could plausibly be adjacent to this. Checked directly against
  Chrome's own capabilities doc: it detects **faces, barcodes, and text only — it does not perform
  generic document or rectangle boundary detection**
  ([developer.chrome.com/docs/capabilities/shape-detection](https://developer.chrome.com/docs/capabilities/shape-detection)).
  There is no `RectangleDetector` or `DocumentDetector` interface in the spec
  ([wicg.github.io/shape-detection-api](https://wicg.github.io/shape-detection-api/)).
  Even where it exists, only barcode detection has shipped by default in Chrome since Chrome 83;
  face and text detection remain behind the `#enable-experimental-web-platform-features` flag, and
  as of a 2026-02-25 spec-status check the whole API is still a W3C/WICG **Draft Community Group
  Report** — pre-standardization, not something to depend on for a shipping feature.
- **No WASM-based generic document-detection standard exists** either; this would be a
  hand-rolled classic-CV (e.g. contour/edge-based quad finder, the same category as
  `VNDetectRectanglesRequest`) or ML-based (e.g. a small ONNX/TFLite-in-WASM model) implementation
  this app would have to build and ship itself, mirroring the same "bring your own" situation
  `docs/research/ocr-receipt-entry-engine-choice.md` already found for Tesseract.js's web OCR path
  (no batteries-included binding; the app owns the integration). No such package was searched for
  in this ticket's scope since issue #19 only asked whether a standard/native equivalent exists —
  it does not, and this is a confirmation of the ticket's own suspicion, not a new finding.
- **Conclusion**: boundary detection is mobile-only for the foreseeable future. The web OCR path
  (issue #15, Tesseract.js) stays without a boundary-detection preprocessing step; if this ever
  becomes a priority for web, it is new work with no first-party or standards-track primitive to
  build on, not a research gap in this document.

## Architecture fit: `packages/ocr`'s `TextRecognizer` is the wrong seam

This section reads `packages/ocr/lib/` directly, rather than inferring fit from ADR-0052's summary.

- `TextRecognizer.recognize(RecognizableImage) → Future<RecognizedText>`
  (`packages/ocr/lib/src/text_recognizer.dart:11`) takes already-decoded image bytes
  (`RecognizableImage`, `packages/ocr/lib/src/recognizable_image.dart:8`) and returns
  `RecognizedText` — a flat list of `RecognizedLine`
  (`packages/ocr/lib/src/recognized_text.dart:8`, `recognized_line.dart:9`). Every `RecognizedLine`
  carries `text`, an optional `RecognizedLineBounds`, an optional `confidence`, and
  `recognizedLanguages` — vocabulary that is entirely about *text that was read*, per line.
- `RecognizedLineBounds` (`packages/ocr/lib/src/recognized_line_bounds.dart:6`) is an **axis-aligned**
  box: `top`/`bottom`/`left`/`right` only. There is no quadrilateral/corner-point concept anywhere
  in `packages/ocr/lib/`, and none of the platform APIs researched above return an axis-aligned box
  for a document boundary — all three (`GmsDocumentScanningResult`,
  `VNDocumentCameraScan`, `VNDetectDocumentSegmentationRequest`'s `VNRectangleObservation`) are
  either a finished perspective-corrected crop or an actual four-corner quad, because receipts are
  photographed at an angle and an axis-aligned box cannot represent that.
- `TextRecognitionFailure` (`packages/ocr/lib/src/text_recognition_failure.dart:8`) is scoped,
  by its own doc comment, to "the engine cannot produce a result (decode failure, plugin
  unavailable, native crash)" — it has no vocabulary for "ran fine, found zero lines" (that's
  legitimately an empty `RecognizedText.lines`) and equally no vocabulary for "no document boundary
  found in frame," which is a routine, expected outcome during live preview (most frames won't have
  a stable, in-view receipt yet) rather than a failure.
- A document-boundary detector doesn't recognize text at all — its input may be a full-resolution
  still (Android/iOS capture-UI case) or a live preview frame at a much lower effective resolution
  (iOS `VNDetectDocumentSegmentationRequest` driven per-frame), and its output is purely geometric
  (a quad, or a cropped/corrected image) with zero text content. Forcing this through
  `TextRecognizer.recognize` would mean inventing fake `RecognizedLine`s to carry corner
  coordinates, which breaks the interface's own stated contract ("Nothing about `TextRecognizer` or
  `RecognizedText` mentions receipts, amounts, merchants, or dates; it is exactly as generic as
  'recognize the text in this image'" — ADR-0052) in the other direction: it would also stop being
  generic, since boundary detection is receipt/photo-specific in a way plain text recognition
  is not.

**Recommendation**: this needs its own new seam, sibling to `TextRecognizer` inside
`packages/ocr/` (not a new top-level package — `packages/ocr/`'s reason to exist, per ADR-0052, is
"wrapping engines behind one interface" for this app's receipt-capture pipeline, and boundary
detection is squarely part of that same capture pipeline, just a different pipeline stage). A
natural shape, following this repo's existing conventions
(`docs/adr/0052-receipt-text-recognizer-seam.md`, `.claude/rules/solid-principles.md`'s
open/closed section):

- An abstract `DocumentBoundaryDetector` (naming TBD at implementation time) would take one method:
  an image or a frame in, and a new value type out — call it `DetectedBoundary` — carrying the four
  corner points and whatever confidence signal the underlying engine exposes, distinct from
  `RecognizedLineBounds`'s axis-aligned box. A no-detection outcome is a first-class, expected
  result, not an exception, given how routine "no receipt in frame yet" is during live preview.
  This argues for a nullable return (`DetectedBoundary?`) rather than reusing
  `TextRecognitionFailure`'s throw-on-failure contract; this repo's own null-safety conventions
  already prefer a nullable type for "a real, meaningful absent state" over a thrown exception
  (`.claude/rules/dart-type-safety.md`).

  Two concrete engines would exist behind this interface once implemented: an Android
  implementation wrapping `GmsDocumentScanner` (capture-flow-shaped — it returns a finished crop,
  no live-frame path) and an iOS implementation wrapping `VNDetectDocumentSegmentationRequest`
  (frame-capable — the same request object can run against a still or a live sample buffer).
  ADR-0052's own precedent already covers this shape: one interface, per-platform implementations,
  with the seam introduced only once a concrete need for it exists — which it now does.
- This is a design sketch for whoever picks up issue #19/#20's implementation, not a decision this
  research ticket is authorized to make (out of scope per the issue: "do not build the live-feed UI
  itself"). The concrete type/method names and exact seam placement should go through this repo's
  normal design step for a new interface, not be locked in by a research doc.

## Live-feed feasibility verdict (gating question for issue #20)

**iOS: yes, with a caveat that resolves in this app's favor.** `VNDetectDocumentSegmentationRequest`
is Apple's own documented realtime-on-camera-feed primitive, already proven inside
`VNDocumentCameraViewController`'s own live capture UI on modern hardware. The only caveat —
Neural Engine required for realtime speed — is a non-issue in practice: every device capable of
running this Flutter app at its current 15.5 deployment target has a Neural Engine, so this is
realtime-capable on the entire real-world target fleet, not a "some phones, not others" risk. This
directly answers issue #20's premise (a live green/red overlay) as achievable on iOS at native
Vision-request speed.

**Android: no, not through the first-party API named in the ticket.** `GmsDocumentScanner` is a
capture-flow-only API — it owns the camera surface itself and returns a finished crop, with no
per-frame detection callback the app can drive its own overlay from at all. A live green/red
boundary overlay on Android, if this app wants that experience there too, is **not achievable with
the API this research found** and would need a different, lower-level approach (e.g. hand-rolled
CV via CameraX + OpenCV, or ML Kit's other on-device object-detection primitives, neither of which
was in this ticket's scope to evaluate). This is a real platform asymmetry this research surfaces,
not a gap in the research itself — issue #20 should treat "live overlay" as an iOS-only capability
unless a further ticket investigates an Android-side alternative.

**Web: not applicable.** No live-feed question arises because no boundary-detection primitive
exists on the web at all (see above).

## Summary for whoever resolves issue #19

| Platform | Primitive | Returns | Confidence/no-detection | Live-feed | Recommended for this app |
|---|---|---|---|---|---|
| Android | `GmsDocumentScanner` (ML Kit Document Scanner) | Cropped image per page (capture-UI only) | No score exposed; binary `RESULT_OK`/`RESULT_CANCELED` | No — capture-flow only, Play Services owns the camera | Yes, for capture-time cropping; not for a live overlay |
| iOS | `VNDetectDocumentSegmentationRequest` | Four corner points (`VNRectangleObservation`) + per-pixel segmentation mask | Per-pixel confidence in the mask; empty `results` = no detection | Yes — Apple-documented realtime on Neural Engine (all real-world target devices) | Yes, for both capture-time cropping and issue #20's live overlay |
| iOS (older) | `VNDetectRectanglesRequest` | Four corner points + scalar confidence | Scalar confidence; empty `results` = no detection | Yes — CPU-only classic CV, realtime if CPU isn't saturated | No — superseded by the segmentation request above for document-shaped detection specifically |
| iOS (capture UI) | `VNDocumentCameraViewController` | Perspective-corrected `UIImage` per page (capture-UI only) | None exposed; internally uses the segmentation request on modern hardware | No — self-contained capture UI | Only if this app wants Apple's own capture chrome wholesale, not for a custom live overlay |
| Web | Shape Detection API | N/A — no document/rectangle detector exists in the spec | N/A | N/A | No — no equivalent exists; confirmed, not assumed |

## Open questions and gaps

- Apple's own `developer.apple.com/documentation/vision/vndetectdocumentsegmentationrequest` page
  did not return body content to this research's fetch tooling (same JS-rendering limitation noted
  in `docs/research/ocr-vision-vs-mlkit-ios-accuracy.md`'s Method note). All claims about this API
  are corroborated through independent search-aggregated quotes of the same WWDC21 session and
  cross-referenced against a Microsoft .NET-for-iOS binding doc that mirrors Apple's own
  availability annotations, not a direct fetch of Apple's reference page itself. A hands-on
  Xcode/simulator check (or a successful direct fetch, if the tooling gap is later resolved) would
  firm this up before implementation.
- No battery/thermal cost figure was found for running `VNDetectDocumentSegmentationRequest` at
  sustained 15-30fps over a multi-second capture session — Apple's "realtime" claim is a capability
  statement, not a power-budget one. This matters for issue #20's UX (how long a live overlay can
  run before it should time out or throttle) but wasn't answered by any source found here.
  Worth a hands-on device battery/thermal check before committing to an always-on overlay design.
  Independent third-party tutorials on real-time Vision rectangle detection use frame-skipping
  (e.g. processing every 3rd frame) for exactly this reason — a concrete lever issue #20 can use if
  battery cost turns out to matter.
- No first-party ML Kit primitive equivalent to `VNDetectDocumentSegmentationRequest` (a lower-level
  "just give me the quad and a confidence, I'll drive my own camera" API) was found for Android.
  `GmsDocumentScanner` is confirmed to be the only first-party document-detection surface Google
  publishes; whether Google has an internal or beta lower-level primitive not surfaced by this
  research's searches is unknown. If issue #20 wants a live overlay on Android specifically, a
  follow-up research pass scoped to that exact question (not just "does one exist," but "is there
  really nothing lower-level than the full scanning UI") would be worth doing before concluding
  Android can't have the feature at all.
- This research did not evaluate ML Kit's general-purpose Object Detection API or the AutoML/
  custom-model route as a possible Android live-detection fallback, since neither was named in the
  ticket and both would be new dependencies beyond what issue #19 asked to scope.
