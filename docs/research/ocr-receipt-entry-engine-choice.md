# On-device OCR engine choice for receipt entry

Research for `.scratch/ocr-receipt-entry/issues/01-ondevice-ocr-library-choice.md`. Sources are
pub.dev package pages, Google's ML Kit docs, and package GitHub issue trackers, checked directly
(not blog summaries) as of 2026-08-21.

## Requirement

Fully local (zero network call) OCR for photographed/uploaded receipts, across iOS, Android, and
web.

## Candidates checked

### Google ML Kit Text Recognition — `google_mlkit_text_recognition` (pub.dev)

- **Version / release cadence**: 0.17.1, published 3 days ago. Healthy, active.
- **Platform coverage**: Android and iOS only. The plugin's own docs state it plainly: "Google's
  ML Kit was build only for mobile platforms: iOS and Android apps. Web or any other platform is
  not supported." Confirmed — no web path exists, not even via a shim.
- **Native requirements**: iOS min deployment 15.5, Xcode 15.3+, Swift 5, 64-bit only. Android
  minSdk 21, targetSdk/compileSdk 35. Depends on `google_mlkit_commons` ^0.13.0. Ordinary native
  dependency weight for an ML Kit-based plugin — no unusual install friction.
- **Receipt use case**: Google's own Text Recognition v2 docs state directly: "The API can also be
  used to automate data-entry tasks such as processing credit cards, receipts, and business cards."
  This is an explicitly supported, first-party use case, not an inferred fit.
- **Preprocessing burden**: Google's iOS integration guide gives image-quality guidance (character
  size ideally 16-24px, poor focus hurts accuracy, recapture if focus is bad) but does **not** call
  for deskewing or binarization — the engine is tolerant of real-world photo conditions out of the
  box. No preprocessing pipeline is documented as required.
- **Maintenance health**: last release 3 days ago. Upstream repo
  (`flutter-ml/google_ml_kit_flutter`) has 3 open issues total: SPM integration, a
  GoogleDataTransport/Firebase symbol duplication conflict, and an Apple Silicon arm64 simulator
  build failure. All three are build/dependency-tooling issues — none concern accuracy or runtime
  crashes.

**Verdict**: strong for iOS + Android. Zero web path, confirmed from the plugin's own docs, not
just an omission.

### Apple Vision (`VNRecognizeTextRequest`) via Flutter wrapper

Checked several current wrapper packages on pub.dev:

- **`apple_vision_recognize_text`** (part of the `apple_vision` plugin family) — v0.1.0, published
  26 days ago, 160 pub points, 8 likes, 1.37k downloads. Supports iOS 13+ and macOS 10.15+. Explicit
  disclaimer: "not sponsored or maintained by Apple" — community-run. Small but not abandoned.
- **`platform_text_recognition`** — v0.2.0, published 31 days ago. Notable because it already
  bundles the per-platform split this ticket is evaluating: Apple Vision on iOS (13+), Google ML
  Kit on Android (API 21+), explicitly no ML Kit/SPM dependency pulled in on iOS. No web, no
  macOS/desktop. Very new and low-adoption (0 likes, 141 downloads) — worth watching, not yet
  something to depend on for a shipping app.
- Other wrappers found (`vision_text_recognition`, `text_sight`, `flutter_native_ocr`) are smaller
  or staler (one is 14 months since last release) and don't change the picture.

**Structural limit, independent of which wrapper**: Vision is an Apple framework. It only ever
covers iOS/macOS, so it can never be a single cross-platform answer — any use of it necessarily
means a per-platform split with something else covering Android and web. This matches what the
ticket already expected.

**Verdict**: not needed here. ML Kit already covers iOS at "supported, maintained, receipt-capable"
quality, so Vision would only be worth adopting for an iOS-specific accuracy edge — not currently a
gap this app has.

### Tesseract-based Flutter packages

- **`flutter_tesseract_ocr`** (pub.dev, repo `khjde1207/tesseract_ocr`) — v0.4.31, published 2
  months ago. 214 likes, 130 pub points, 5.1k weekly downloads — the most-adopted Tesseract option.
  Lists Android/iOS/Web as supported platforms in its metadata, and the changelog shows a "WASM
  support" entry (0.4.29). **But** checking the actual example and readme: there is no batteries-
  included web binding. The web path is "go implement Tesseract.js v4.0.2 yourself" — the readme
  hands the developer JS snippets (`Tesseract.createWorker()`, `loadLanguage(...)`) to wire up via
  `dart:js` interop. This is a pointer to a manual integration, not a maintained web binding baked
  into the plugin's own Dart API.
  - Its own readme carries a self-assessed caveat: "Tesseract is slower than ml_kit."
  - GitHub issues (repo `khjde1207/tesseract_ocr`, 68 stars): **18 open issues**, including two
    crash reports — `SwiftyTesseract.swift:100: Fatal error: Initialization of SwiftyTesseract has
    failed` and a Simulator arm64 build failure (`Could not find module 'SwiftyTesseract'`) — plus
    an `extractHocr()` iOS/Android inconsistency bug. This is a materially worse crash/accuracy
    issue profile than ML Kit's 3 build-only issues.
- **`tesseract_ocr`** (separate pub.dev package, publisher zuzu.dev, verified) — v0.5.0, published
  14 months ago. Android + iOS only, no web claim at all (uses Tesseract4Android + SwiftyTesseract
  + Apple Vision under the hood). Stale relative to the other option and doesn't even attempt web.
- **`id_card_ocr_web`** — a real, working example of the WASM path done properly: Tesseract.js run
  client-side in the browser, zero network, last published 51 days ago. But it's purpose-built for
  Indonesian ID cards (KTP), unverified publisher, roadmap shows incomplete items, and it isn't a
  general-purpose OCR plugin — it's a narrow proof that the Tesseract.js-in-browser pattern works,
  not a drop-in dependency for this app.
- **Preprocessing burden**: well-documented in the OCR literature that Tesseract's accuracy is
  materially more sensitive to skew, contrast, and binarization than modern neural on-device
  engines — published results cited in general OCR preprocessing research show ~20-33% accuracy
  gains from deskew/contrast/grayscale preprocessing specifically for Tesseract. None of the
  Tesseract Flutter packages checked ship this preprocessing themselves — an app adopting Tesseract
  for receipts (thermal print, creases, skew) would need to build deskew/binarization itself to
  reach usable accuracy. This preprocessing burden would fall entirely on this app.

**Verdict**: Tesseract is the only real path to true in-browser fully-local OCR, but every
packaged option either doesn't actually implement the web binding (`flutter_tesseract_ocr` requires
writing your own JS interop) or isn't a general-purpose OCR dependency at all
(`id_card_ocr_web`). Combined with materially worse crash reports and an unavoidable preprocessing
burden, Tesseract is the correct engine for web specifically, but a "just add this package" claim
for iOS/Android does not hold up — ML Kit is better there.

## Recommendation: per-platform split

- **iOS and Android: `google_mlkit_text_recognition`.** First-party-documented receipt support,
  active release cadence (3 days old), clean issue tracker (3 issues, all build tooling, none
  accuracy/crash), and no deskew/binarization pipeline required to reach usable accuracy on typical
  phone photos.
- **Web: Tesseract.js, wired directly (not through `flutter_tesseract_ocr`'s incomplete plugin
  path).** ML Kit has zero web story, confirmed from its own docs. Tesseract via WASM is the only
  fully-local OCR that runs in a browser at all. Given `flutter_tesseract_ocr`'s web support is
  actually "bring your own JS interop" rather than a working binding, and its native side carries
  meaningfully worse crash reports (18 open issues, including SwiftyTesseract fatal-error crashes)
  than ML Kit's, the pragmatic move is to use Tesseract.js **directly** for the web target (own
  `dart:js`/`package:web` interop, following the same pattern `id_card_ocr_web` demonstrates) rather
  than depend on a Flutter package that doesn't actually deliver the web binding it claims. This
  also means the app must budget for its own deskew/contrast/binarization preprocessing on the web
  path specifically, since Tesseract needs it and nothing in the ecosystem provides it
  out-of-the-box.

This is a genuine per-platform split, not a compromise pending a better cross-platform answer:
Apple Vision was structurally ruled out as ever being a single-engine answer (iOS/macOS only), and
no fully-local engine today covers all three platforms at a comparable accuracy/maintenance bar.
ML Kit for iOS/Android plus a hand-wired Tesseract.js for web is the combination backed by what
these primary sources actually show, not by package marketing claims.
