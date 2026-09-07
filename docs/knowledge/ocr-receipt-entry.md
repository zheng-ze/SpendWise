# Receipt OCR Entry

Last reconciled: 20741e0

_(Reconciled against `packages/ocr/lib/src/`, `app/lib/ocr/`, `app/android/app/src/main/kotlin/`,
and `app/ios/Runner/` at the commit above. `packages/ocr/` now ships two implemented engines:
Vision (iOS) and a native Android ML Kit bridge (Android). Issue #86 dropped web as a supported
platform: the Tesseract.js engine, its native-vs-web conditional-export facade, and its tests are
deleted (#87), and `selectRecognizer`/`selectDocumentScanner` no longer have a web branch at all —
a platform that is neither iOS nor Android (macOS, Windows, Linux) now falls through to `null`
instead of constructing a recognizer, which also fixes a latent defect where that fallthrough
would have wrongly constructed `AndroidTextRecognizer` on desktop (#88). Issue #77 replaced the
Android engine: it dropped the `google_mlkit_text_recognition` Flutter plugin entirely in favor
of a hand-written `AndroidTextRecognizer`/`AndroidEngine` bridge over a native Kotlin MethodChannel,
mirroring `VisionTextRecognizer`'s own architecture — see Engines below. This also let iOS's
`IPHONEOS_DEPLOYMENT_TARGET` revert from 15.5 back to 13.0, since the plugin's iOS podspec was the
sole reason for that floor — see Gotchas.)_

## Feature overview

Let the user photograph or pick a receipt image and prefill the entry form's name, amount, and date
fields from it, without ever saving to the ledger before the user reviews the result, and while
keeping the recognition engine swappable by platform and by framework. Two layers are separated by
the `TextRecognizer` seam: a general-purpose `packages/ocr/` text-recognition package (engine- and
receipt-agnostic) and receipt-specific field-extraction heuristics in `app/`.

## Key files

- `packages/ocr/lib/ocr.dart` — the barrel; exports the seam, value types, and the ML Kit engine.
- `packages/ocr/lib/src/text_recognizer.dart` — the `TextRecognizer` seam.
- `packages/ocr/lib/src/recognizable_image.dart`, `recognized_text.dart`, `recognized_line.dart`,
  `recognized_line_bounds.dart` — the engine-agnostic value types.
- `packages/ocr/lib/src/text_recognition_failure.dart` — the engine-failure exception.
- `packages/ocr/lib/src/android_text_recognizer.dart`, `android_engine.dart` — the native Android
  engine (`AndroidTextRecognizer`) and its injectable `AndroidEngine` seam, reaching
  `app/android/app/src/main/kotlin/com/example/spendwise/TextRecognizerChannel.kt` over the
  `spendwise/android_text_recognizer` method channel (method `recognizeText`). No Flutter-plugin
  dependency — see Engines below.
- `app/android/app/src/main/kotlin/com/example/spendwise/TextRecognizerChannel.kt` — the native
  Android bridge. Registered in `MainActivity.kt`'s `configureFlutterEngine`. Runs
  `TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)` on a single-thread `Executor`
  (decode + recognition never block the platform-channel thread), replies exactly once via
  `Handler(Looper.getMainLooper())`, and exposes a `close()` called from `MainActivity.onDestroy()`
  that closes the recognizer and shuts down the executor.
- `app/android/app/build.gradle.kts` — declares `com.google.mlkit:text-recognition:16.0.1` as a
  plain Gradle dependency, alongside the pre-existing, unrelated
  `com.google.android.gms:play-services-mlkit-document-scanner` (a different ML Kit module, for
  document boundary scanning — see `document_scanner_channel.dart` below).
- `packages/ocr/lib/src/vision_text_recognizer.dart`, `vision_engine.dart` — the native iOS Vision
  engine (`VisionTextRecognizer`) and its injectable `VisionEngine` seam, reaching
  `app/ios/Runner/VisionTextRecognizerChannel.swift` over the `spendwise/vision_text_recognizer`
  method channel (method `recognizeText`).
- `app/ios/Runner/VisionTextRecognizerChannel.swift` — the native Vision bridge. Runs
  `VNRecognizeTextRequest(recognitionLevel: .accurate)` via `VNImageRequestHandler`, decoding the
  image and performing the request inside `DispatchQueue.global(qos: .userInitiated)` (never on the
  calling/main thread — see Gotchas), then hops to `DispatchQueue.main.async` to call `result(...)`
  exactly once on every path. Registered in `AppDelegate.swift` alongside `DocumentScannerChannel`.
- `app/lib/ocr/amount_extraction.dart`, `name_extraction.dart`, `date_extraction.dart` — the three
  receipt-specific heuristics (in `app/`, consuming `RecognizedText`).
- `app/lib/ocr/receipt_recognizer_selection.dart`, `document_scanner_selection.dart` — platform
  engine and document-scanner selection.
- `app/lib/ocr/platform_adapter_selection.dart` — `selectPlatformAdapter`, the shared "first
  non-null candidate wins, in order" router both helpers delegate to.
- `app/lib/ocr/document_scanner_channel.dart` — the shared `DocumentScannerChannel` MethodChannel
  wrapper.
- `app/lib/ui/transactions/document_crop/` — the web 4-point crop screen (`document_crop_screen.dart`).
- `app/lib/ui/transactions/receipt_scan/` — the scan strip/flow that wires scanner + extraction.


`packages/ocr/` is a real package sibling to `packages/domain/`. It is allowed to
depend on Flutter and platform interop — the enforced boundary is "`packages/domain/` may never use
Flutter", narrower than "only `app/` may use Flutter". `packages/ocr/` depends on neither `app/`
nor `packages/domain/`.

## The seam

`TextRecognizer` (`packages/ocr/lib/src/text_recognizer.dart`) is the single seam:
`recognize(RecognizableImage) -> Future<RecognizedText>`, `dispose()`. It is exactly as generic as
its name: image bytes in, a flat list of lines out — no receipts, amounts, merchants, or dates, no
block/paragraph hierarchy. Two swap axes reduce to it: swap the engine by platform (iOS and Android
each need a different on-device engine) and swap the engine by framework on the same platform (a
second iOS engine, or a future engine for a platform not yet supported). Nothing above the seam may
know how many engines exist for a platform. Web was a third platform reached through this same seam
until issue #86 dropped it as a supported platform (see Gotchas) — the seam itself did not change
to make that removal possible; only the concrete `TesseractTextRecognizer` implementation and its
selection branch went away.

Value types (`packages/ocr/lib/src/`):

- **`RecognizableImage`** — already-decoded image bytes (`Uint8List`, PNG/JPEG), never a platform
  file or path. Converting a camera/picker result is the caller's job.
- **`RecognizedText`** — a flat, unmodifiable `List<RecognizedLine>` in the order the engine
  returned them. It carries no per-line data itself.
- **`RecognizedLine`** — `text`, optional `bounds` (`RecognizedLineBounds`, with a `height`
  getter = `bottom - top`), optional `confidence` (0.0–1.0, or null when the engine does not
  report it), and `recognizedLanguages` (BCP-47, an empty list — never null — when unavailable).
  These three optional fields live on the **line**, not on `RecognizedText`.
- **`TextRecognitionFailure`** — thrown by `recognize` on engine failure; carries a `message`
  combining the engine name and underlying cause (logs/debugging, never shown to the user). It
  never returns an empty `RecognizedText` to signal failure, so "ran and found nothing" and
  "couldn't run" stay distinguishable.

Availability of `bounds`/`confidence`/`recognizedLanguages` varies by engine and is confirmed by
research (`docs/research/ocr-confidence-language-fields.md`), not assumed: `bounds` on every named
engine; `confidence` on all three but with a documented ML-Kit-iOS gap; `recognizedLanguages`
reliably only on Android ML Kit.

## Engines: implemented vs designed

Implemented today:

- **`AndroidTextRecognizer`** (`packages/ocr/lib/src/android_text_recognizer.dart`), wraps
  Android's on-device ML Kit text recognizer via `AndroidEngine`/`PluginAndroidEngine`
  (`packages/ocr/lib/src/android_engine.dart`), reaching the native bridge over the
  `spendwise/android_text_recognizer` method channel. `PluginAndroidEngine.recognizeText` calls
  `invokeListMethod<Map<Object?, Object?>>('recognizeText', imageBytes)`; a `null` channel reply
  throws `StateError('Android text-recognition channel returned null')`, the same
  never-silently-empty discipline as Vision's engine. Each line map carries `text`, pixel-space
  top-left-origin `left`/`top`/`right`/`bottom`, an optional `confidence` (present only when ML Kit
  reports one for that line), and an optional `language` (a BCP-47 tag from ML Kit's
  `Text.Line.getRecognizedLanguage()`, present only when ML Kit determined one — the native side
  treats `"und"` the same as absent). The Dart mapping reads `language` into a single-element
  `recognizedLanguages` list, or empty when absent — ML Kit reports at most one language per line,
  unlike the removed plugin's own already-list-shaped field. `dispose()` is an intentional no-op:
  the underlying ML Kit recognizer is process-scoped and owned by the native
  `TextRecognizerChannel` (closed once, from `MainActivity.onDestroy()`), not per-recognizer-
  instance like the removed plugin wrapper was. Tested in
  `packages/ocr/test/android_text_recognizer_test.dart` (mapping, confidence and language
  passthrough including their absent cases, the empty-vs-failure distinction, dispose-is-truly-a-
  no-op, and a `PluginAndroidEngine`-focused mocked-channel test proving the null-response throw).
- **`VisionTextRecognizer`** (`packages/ocr/lib/src/vision_text_recognizer.dart`), wraps Apple's
  Vision framework for iOS via `VisionEngine`/`PluginVisionEngine`
  (`packages/ocr/lib/src/vision_engine.dart`), reaching the native bridge over the
  `spendwise/vision_text_recognizer` method channel. `PluginVisionEngine.recognizeText` decodes via
  `invokeListMethod<Map<Object?, Object?>>` (a raw `invokeMethod<List<Map<Object?, Object?>>>` call
  is rejected by `MethodChannel`'s own generic-type restriction). A `null` channel reply — the
  native side never producing a list — throws `StateError('Vision channel returned null')` rather
  than silently coercing to an empty result, keeping "no text found" (a genuine empty list) and
  "the channel call itself failed" distinguishable; both are still wrapped in
  `TextRecognitionFailure` at the `VisionTextRecognizer.recognize` boundary like every other engine.
  Confidence (`VNRecognizedText.confidence`) is already 0.0–1.0 and mapped directly, no rescaling.
  `recognizedLanguages` is always `const []` — Vision has no output-side language field.
  `dispose()` is an intentional no-op: Vision issues one-shot requests with no persistent resource
  to release, unlike `MlKitTextRecognizer`'s long-lived recognizer instance
  (`vision_text_recognizer.dart`'s `dispose()` doc comment). Tested in
  `packages/ocr/test/vision_text_recognizer_test.dart` (9 cases: line-by-line mapping, confidence
  passthrough, bounds, empty-languages, the empty-vs-failure distinction, dispose-is-truly-a-no-op,
  and a `PluginVisionEngine`-focused mocked-channel test proving the null-response throw — this last
  case needs `flutter test`, not `dart test`, for its `TestWidgetsFlutterBinding` requirement).

`selectRecognizer` returns `null` where no engine is built for a platform at all. As of issue #86,
that now includes every desktop platform (macOS, Windows, Linux) alongside any platform that is
neither iOS nor Android — web is no longer a supported platform, so it is not a case the function
distinguishes at all. iOS specifically runs Vision rather than ML Kit (see Engine and scanner
selection below).

## Engine and scanner selection

Both selection helpers route platform decisions through `selectPlatformAdapter`
(`app/lib/ocr/platform_adapter_selection.dart`) while keeping their own web-first gates.
`selectPlatformAdapter` is platform-agnostic: it only encodes "first non-null candidate wins, in
order", evaluating an ordered list of already-gated candidate builders and short-circuiting on the
first hit. The domain helpers keep all their platform and gate rules; they never delegate a gate to
it.

`selectRecognizer` (`app/lib/ocr/receipt_recognizer_selection.dart`) takes `isIOS`/`isAndroid`
overrides (letting a test fix the branch instead of reading the real platform) plus two injected
factory parameters, `visionFactory`/`androidFactory` (typedef `TextRecognizerFactory = TextRecognizer
Function()`), defaulting to `VisionTextRecognizer.new`/`AndroidTextRecognizer.new`. It hands
`selectPlatformAdapter` an ordered candidate list: a `visionFactory()` candidate gated on `isIOS ??
defaultTargetPlatform == TargetPlatform.iOS` (`null` on non-iOS, so the vision recognizer is never
even constructed there), then an `androidFactory()` candidate gated on `isAndroid ??
defaultTargetPlatform == TargetPlatform.android`. Both platform checks now go through
`package:flutter/foundation.dart`'s `defaultTargetPlatform`; there is no more separate `dart:io`
`Platform.isIOS`-based check or file for iOS (`ios_platform_check.dart` and its native/web variants
were deleted — the conditional-export split existed only because `dart:io` couldn't be imported in
a file that also compiled for web, and that constraint disappeared with web support itself). A
platform that is neither iOS
nor Android — every desktop target (macOS/Windows/Linux) as of issue #86 — falls through both
gates to `null`; there is no more unconditional fallback candidate. This is the only place platform
identity is inspected in this layer. As of issue #77, Android runs the native `AndroidTextRecognizer`
bridge rather than the `google_mlkit_text_recognition` Flutter plugin — no platform in this app
depends on a Flutter OCR plugin anymore. The injected factories exist purely for tests: production
code never passes them, so production still constructs a fresh `VisionTextRecognizer`/
`AndroidTextRecognizer` per call, same as before the injection was added (see Recognizer seam for
scans below for why this differs from the scan-level seam).

`selectDocumentScanner` (`app/lib/ocr/document_scanner_selection.dart`) selects iOS or Android
directly (no more web gate — removed alongside `selectRecognizer`'s in issue #86/#88), and on
Android checks Play Services eligibility before it routes the platform candidate through
`selectPlatformAdapter`. On any other platform it falls through to `null`, same as `selectRecognizer`.

Document capture: iOS launches `VNDocumentCameraViewController`, Android launches
`GmsDocumentScanner` and falls back to a plain camera capture (`ImagePicker(source: camera)`) when
Google Play Services is unavailable rather than showing an error; web gets a from-scratch 4-point
crop screen (`app/lib/ui/transactions/document_crop/`). Both native scanners own their live
rectangle feedback and capture; this app sees only the final cropped bytes. `DocumentScannerChannel`
(Swift + Kotlin) wraps each scanner behind one MethodChannel and one Dart class. No custom
per-frame document-boundary detection exists anywhere.

## Extraction heuristics (app layer)

Each heuristic is a plain function from `RecognizedText` to a result, operating only on `lines`, so
they cannot special-case an engine:

- **`extractAmount`** — scans for a grand-total keyword line (`TOTAL DUE`, `GRAND TOTAL`,
  `AMOUNT DUE`, `BALANCE DUE`, `TOTAL`), skipping lines containing a false-match keyword
  (`SUBTOTAL`, `TAX`), and returns the last currency number on it; if no keyword line matches it
  falls back to the last currency-formatted number anywhere in the receipt. Depends only on
  `line.text`. Returns `null` when no currency value is found.
- **`extractName`** — scans the first 5 lines (`_scanDepth = 5`), skips address/phone/url/boilerplate
  and greeting lines (with a consecutive-skip early return of `null`), and keeps the first surviving
  line that looks like a name (length 3–35, ≤ 6 words, an alphabetic character, digit density
  < 0.2). Strips a trailing `Store #<digits>` tag from a line before evaluating it (`_trailingStoreNumber`),
  so a merged header line like `STARBUCKS Store #10208` keeps `STARBUCKS` as a candidate instead of
  being discarded whole; a line that is only a store-number tag still reduces to empty and is
  skipped. `MANAGER` is a boilerplate keyword (skips an employee-name line such as
  `MANAGER DIANA EARNEST`). A line whose `confidence` is present and below `0.4` is skipped before
  the height comparison, since a stylized logo commonly OCRs as a tall, near-zero-confidence line
  that would otherwise win on height alone over smaller, legible text (see Gotchas). Prefers the
  tallest surviving line when `line.bounds?.height` is known — the one heuristic whose output
  depends on `bounds`. Returns `null` when none qualifies.
- **`extractDate`** — first date-shaped text with locale-aware day/month disambiguation (month-first
  regions `US, PH, PW, FM, CA`; day-first elsewhere); two-digit years map to 2000+; returns UTC
  midnight. Defaults to today (never null in the caller-visible result) when no date-shaped text
  matches. `locale` and `now` are parameters so tests fix the order and "today" without the device.

`extractName` is the only one of the three that reads `confidence`; `extractAmount` and
`extractDate` still depend only on `line.text`. None use `recognizedLanguages`. The exact keyword
sets, pattern filters, thresholds, and disambiguation are implemented in the extraction heuristics.

## Failure handling

Every non-extraction outcome lands on the same blank draft form — a hard requirement. The single UI
hook point wraps `recognize` in one try/catch for `TextRecognitionFailure` and treats a caught
failure identically to an empty result; both feed the heuristics, which produce blank fields (the
date field's today-default) from empty input. This is the one and only place `TextRecognitionFailure`
is caught; it never reaches a widget. Nothing extracted is retained after prefill — no "view raw
scan". The date field is the sole exception, defaulting to today rather than blank.

## Integration and non-goals

The extracted merchant name feeds the entry form's name field through the same path hand-typed text
takes; the category classifier's `predict` runs against OCR text with no special-casing, and
accepting or correcting the suggestion is a normal `observe` signal. Non-goals: no line-item
extraction, no cloud OCR on any platform ever, no custom-trained model, no receipt image retention
or cloud sync, single-page extraction on both native scanners, and `packages/ocr/` is not hardened
for external consumers (it has exactly one consumer — this app).

## Recognizer seam for scans

`runReceiptScan` (`app/lib/ui/transactions/receipt_scan/receipt_scan_flow.dart`) takes its
recognizer from a `RecognizerFactory` parameter (`typedef RecognizerFactory = TextRecognizer?
Function()`), defaulting to `defaultRecognizer` (`() => selectRecognizer()`), the platform-aware
production path.

The seam's contract lives in `_recognize`: it invokes the factory to obtain a recognizer and disposes
whatever non-null recognizer it received in its `finally` block, so any scan that gets a recognizer
disposes it exactly once. The test that accompanies the seam passes a factory that returns a single
in-memory recognizer, so it exercises one instance per scan, not per-call construction.

The seam lives on the scan entry point rather than on `selectRecognizer` because the two solve
different problems, even though `selectRecognizer` also gained its own test-injection parameters
(`isIOS`/`isAndroid`, `visionFactory`/`androidFactory` — see Engine and scanner selection) when
issue #86/#88 rewrote it. `selectRecognizer`'s injection exists to let a unit test assert *which*
recognizer type a given platform combination selects, in isolation, without going through a scan at
all. The scan-level seam's job is different: give a test control over the exact recognizer
*instance* a full `runReceiptScan` call runs on, and confirm it gets disposed after the scan — a
concern `selectRecognizer` itself has no reason to know about. That control belongs at the boundary
tests actually invoke (`runReceiptScan`), not at the platform-selection function. The platform gate
in `selectRecognizer` still runs under the default factory, so a platform with no engine still
returns `null` and the scan degrades to a blank draft rather than crashing.

Under the production default `defaultRecognizer` calls `selectRecognizer` on each scan, and
`selectRecognizer` constructs a fresh recognizer instance on every call (`AndroidTextRecognizer()`
on Android, `VisionTextRecognizer()` on iOS), so production scans run on and dispose a fresh
recognizer each time. The seam does not create this behaviour: it comes from the default factory,
and the injected-test case does not assert it because it reuses one instance.

## Gotchas and invariants

- **`app/ios`'s `IPHONEOS_DEPLOYMENT_TARGET` is 13.0, resolved after issue #77.** It was pinned to
  15.5 for a while because `google_mlkit_commons`'s own iOS podspec hard-declared
  `platform :ios, '15.5'` — a CocoaPods dependency-resolution floor enforced regardless of whether
  iOS code ever called the plugin. As long as the app depended on `google_mlkit_text_recognition`
  for Android OCR, the plugin stayed a resolved dependency and `pod install` refused a lower
  `platform :ios` value, even though Vision itself only needs iOS 13. Flutter has no mechanism to
  exclude one platform's pod from a single combined plugin package (`podhelper.rb`'s
  `flutter_install_all_ios_pods` has no per-platform exclusion). Issue #77 removed
  `google_mlkit_text_recognition` from the dependency graph entirely (a native Android bridge, at
  the Gradle level, never touching CocoaPods — see Engines above), which let the deployment target
  revert. `app/ios/Podfile.lock` now lists only the Flutter pod. This also exposed one incidental
  compile break: `app/ios/Runner/DocumentScannerChannel.swift`'s key-window lookup used
  `UIWindowScene.keyWindow`, an iOS-15+-only API; fixed to
  `.compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows }).first(where: { $0.isKeyWindow })`,
  which is iOS-13-safe and finds the same window.
- **`MlKitTextRecognizer` could not run on an iOS Simulator on the tooling available at the time —
  no longer relevant, since ML Kit is off iOS entirely as of issue #77.** For history: the plugin's
  native pods shipped no arm64 Simulator slice, and a machine with only arm64 Simulator runtimes
  installed could not run it at all. This blocked issue #73 (a planned Vision-vs-ML-Kit comparison
  harness) — closed as skipped rather than built. Issue #77 resolved this by removing ML Kit from
  iOS rather than attempting to make it run there; a future session has no reason to hit this
  blocker again on this codebase.
- **Web is no longer a supported platform (issue #86, sub-tickets #87/#88).** The Tesseract.js
  engine, its `TesseractEngine` seam, its conditional-export facade, and every accompanying test
  (`packages/ocr/lib/src/tesseract_text_recognizer*.dart`,
  `packages/ocr/test/tesseract_text_recognizer*.dart`) were deleted rather than kept dormant, since
  no build target reaches them anymore. `app/lib/ocr/ios_platform_check.dart` and
  `ios_platform_check_native.dart` were deleted entirely, not merely simplified: `selectRecognizer`
  now checks iOS the same way it already checked Android, via `defaultTargetPlatform ==
  TargetPlatform.iOS` from `package:flutter/foundation.dart`, so the separate `dart:io`-based file
  (needed only to keep `dart:io` out of a file that also compiled for web) had nothing left to do.
  A future session should not expect to find any Tesseract-related code, or any `ios_platform_check`
  file, in this feature; the remaining gotchas below predate this removal and cover the
  still-shipping Vision and Android engines.

## Requirements

- The `TextRecognizer` seam keeps engine and framework swaps from reaching the extraction heuristics.
- Extraction is receipt-specific and lives in `app/`, never in `packages/ocr/`.
- Recognition never sends receipt image bytes or recognized text off-device.
- Every non-extraction outcome lands on the same blank draft form; `TextRecognitionFailure` is caught
  once, at the UI hook point, and never reaches a widget.
- No extracted data is retained after prefill.
- `packages/ocr/` may depend on Flutter; only `packages/domain/` is hard Flutter-free.
- Engine selection returns `VisionTextRecognizer` on iOS, `AndroidTextRecognizer` on Android, and
  `null` on every other platform (macOS, Windows, Linux — web is no longer a supported platform).
  (`app/lib/ocr/receipt_recognizer_selection.dart`, reconciled at commit `20741e0`)
- No platform in this app depends on a Flutter OCR plugin; every engine reaches its native SDK
  through a hand-written MethodChannel bridge (issue #77 for the last remaining plugin dependency,
  `google_mlkit_text_recognition`, removed).
