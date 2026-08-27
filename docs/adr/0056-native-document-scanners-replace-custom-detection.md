# 56. Native document scanners (iOS, Android) and a manual crop step (web), not custom
document-boundary detection

## Status

Accepted

## Context

Issue #19 researched how to detect a receipt's document boundary so OCR reads only the receipt
and not the surrounding scene. That research found iOS has a real per-frame primitive (Vision
framework's `VNDetectDocumentSegmentationRequest`, iOS 15+, four corner points plus a confidence
mask, documented for live camera-feed use) but Android has none: `GmsDocumentScanner` only returns
a finished, already-cropped image, with no callable per-frame detection or quad data. Issue #20
followed from that finding, framed as building a live camera preview with a real-time
boundary-overlay this app would own and draw itself — on iOS via `VNDetectDocumentSegmentationRequest`,
and on Android via a custom CameraX plus native OpenCV pipeline built from scratch to compensate
for the missing platform primitive.

A `/prototype` pass built three UI variants of that live-overlay screen to react to. Reacting to
the prototype surfaced the actual goal: a good, correctly-cropped receipt image, not necessarily
this app's own custom detection UI. Once that was named directly, it became clear that Android's
`GmsDocumentScanner` — despite having no per-frame hook this app can read — already provides live
rectangle feedback and capture through its own self-contained scanning UI, and returns a
perspective-corrected image at the end. Apple's `VNDocumentCameraViewController` does the same on
iOS, built on top of the same `VNDetectDocumentSegmentationRequest` primitive issue #19 found, but
exposed as a finished scanning UI rather than raw per-frame data. Neither app-owned per-frame
detection nor a custom CameraX/OpenCV pipeline is needed to reach the actual goal: both platforms
already ship a first-party scanner that gets there on its own.

Web has no camera capture at all — its "Upload photo" action is upload-only — so neither native
scanner applies there regardless.

## Decision

**iOS and Android: launch the platform's own document scanner and take its finished image.** No
custom per-frame detection, no `camera` package, no native computer-vision pipeline.
`VNDocumentCameraViewController` (iOS, `VisionKit`) and `GmsDocumentScanner` (Android, ML Kit
Document Scanner API) each own their live rectangle feedback and capture step entirely; this app
never sees a frame or a corner point, only the final cropped JPEG bytes the scanner hands back
once the user finishes. `DocumentScannerChannel` (Swift and Kotlin) wraps each platform's scanner
behind the same `MethodChannel` name and the same bytes-or-null contract, so
`document_scanner_channel.dart`'s Dart wrapper is a single shared class rather than two
per-platform ones.

**Android falls back to a plain camera capture if Google Play Services is unavailable**, rather
than showing an error. `GmsDocumentScanner` requires Play Services and fails outright on GMS-less
devices (Fire OS, some Chinese-market Android builds, stripped enterprise images).
`DocumentScannerChannel.kt` checks `GoogleApiAvailability.isGooglePlayServicesAvailable` before
launching the scanner and returns an error result on failure; the Dart-side wiring in
`receipt_scan_strip.dart` falls back to `ImagePicker(source: camera)` on that error rather than
surfacing it to the user, keeping a GMS-less device on a working path instead of a dead end.

**Web gets a from-scratch manual 4-point crop screen**, since it has no camera and neither native
scanner applies. `DocumentCropScreen` shows the picked-up image uncropped with four draggable
corner handles starting at the image's own corners; confirming crops to the handles' bounding
rectangle. This is a documented first-cut fallback, not a true perspective/homography warp — no
new dependency was added for a full four-point transform, since `package:image` isn't already a
dependency of this app and `dart:ui`'s own `Canvas`/`PictureRecorder` primitives are enough for a
bounding-rect crop without adding one. A true perspective warp remains open for a future ticket if
the bounding-rect crop proves insufficient in practice.

**The custom live-overlay UI (Variant C from the `/prototype` pass) is dropped entirely, not
built.** Its prototype file (`prototype_boundary_overlay.dart`) is deleted. The underlying goal it
was chasing — live feedback before capture, then a clean crop — is still met, by each platform's
own scanner UI instead of one this app owns and renders.

## Consequences

This app has no control over the scanner's visual styling, its "no detection" messaging, or
whether it auto-captures versus waits for a manual shutter — those are each platform's own scanner
UI, not this app's to skin. That trade-off is accepted because custom UI parity across the two
scanners was never the actual requirement once "get a good crop" was named as the real goal.

No custom per-frame document-boundary detection code exists anywhere in this app.
`VNDetectDocumentSegmentationRequest`, issue #19's iOS finding, is not called directly by this
app — it's used internally by `VNDocumentCameraViewController`, which is what this app calls
instead. If a future ticket needs raw per-frame corner data for some purpose this app's own
scanner UI can't serve, that primitive is still available and issue #19's research still holds;
nothing here removes it as an option.

Single-page extraction is explicit on both platforms: iOS takes `scan.imageOfPage(at: 0)`,
Android's scanner is configured with `setPageLimit(1)`. A user who scans a multi-page receipt on
either scanner still gets only its first page passed to extraction — the same "first page wins"
assumption this app's single-receipt flow already made before this change, just now enforced by
scanner configuration rather than by only ever offering a one-shot camera capture.

Web's bounding-rect crop is weaker than a true perspective correction for a receipt photographed
at an angle — a rectangle drawn around four non-rectangular corners includes some background the
four points themselves would have excluded. This is accepted as a known, documented limitation of
the first cut, not treated as final quality.
