# Receipt OCR Entry

Last reconciled: 2026-09-05

_(Reconciled against `packages/ocr/lib/src/` and `app/lib/ocr/` on the date above. The entry
previously described the OCR engines as unbuilt design; `packages/ocr/` now exists and ships an
implemented ML Kit engine. See Known gaps item 6.)_

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
- `packages/ocr/lib/src/ml_kit_text_recognizer.dart`, `ml_kit_engine.dart` — the one implemented
  engine (`MlKitTextRecognizer`) and its injectable `MlKitEngine` seam.
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
block/paragraph hierarchy. Two swap axes reduce to it: swap the engine by platform (iOS, Android,
web each need a different on-device engine) and swap the engine by framework on the same platform
(a second iOS engine, a future Tesseract.js wrapper). Nothing above the seam may know how many
engines exist for a platform.

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

Implemented today: **`MlKitTextRecognizer`** (`packages/ocr/lib/src/ml_kit_text_recognizer.dart`),
wraps `google_mlkit_text_recognition` for iOS and Android. It writes the image bytes to a scratch
temp file (the plugin only accepts a file path), maps `result.blocks` → `block.lines` to
`RecognizedLine`s, and reads `boundingBox`, `confidence`, and `recognizedLanguages` per line. Its
engine is injectable via the `MlKitEngine` interface (`processImage` + `close`) for testing.

Designed but **not yet built**: a **`TesseractTextRecognizer`** for web,
directly-wired Tesseract.js with `{ blocks: true }` output (no working Flutter wrapper delivers a
web binding), and an experimental iOS **`VisionTextRecognizer`** (issue #8). `selectRecognizer`
returns `null` on web until that path is built.

## Engine and scanner selection

Both selection helpers route platform decisions through `selectPlatformAdapter`
(`app/lib/ocr/platform_adapter_selection.dart`) while keeping their own web-first gates.
`selectPlatformAdapter` is platform-agnostic: it only encodes "first non-null candidate wins, in
order", evaluating an ordered list of already-gated candidate builders and short-circuiting on the
first hit. The domain helpers keep all their platform and gate rules; they never delegate a gate to
it.

`selectRecognizer` (`app/lib/ocr/receipt_recognizer_selection.dart`) keeps its web-first gate: it
checks `kIsWeb` first (because `dart:io`'s `Platform.isIOS`/`isAndroid` cannot be evaluated on web)
and returns `null` before calling `selectPlatformAdapter`; web therefore returns `null` (Tesseract
is not built yet). Otherwise it hands `selectPlatformAdapter` an ordered list holding a single
`MlKitTextRecognizer()` candidate. This is the only place platform identity is inspected in this
layer.

`selectDocumentScanner` (`app/lib/ocr/document_scanner_selection.dart`) keeps its own gates too: it
returns `null` on web first, then selects iOS or Android, and on Android checks Play Services
eligibility before it routes the platform candidate through `selectPlatformAdapter`.

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
  < 0.2). Prefers the tallest surviving line when `line.bounds?.height` is known — the one
  heuristic whose output depends on `bounds`. Returns `null` when none qualifies.
- **`extractDate`** — first date-shaped text with locale-aware day/month disambiguation (month-first
  regions `US, PH, PW, FM, CA`; day-first elsewhere); two-digit years map to 2000+; returns UTC
  midnight. Defaults to today (never null in the caller-visible result) when no date-shaped text
  matches. `locale` and `now` are parameters so tests fix the order and "today" without the device.

None of the three use `confidence` or `recognizedLanguages`; a future consumer may. The exact
keyword sets, pattern filters, thresholds, and disambiguation are implemented in the extraction
heuristics.

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
different problems. `selectRecognizer` chooses the engine for the current platform and returns
`null` where none exists; its behaviour is fixed by `kIsWeb` and platform identity, which tests do
not override. The test seam's job is the opposite: give a test control over the exact recognizer
instance a scan runs on, and dispose it after the scan. That control belongs at the boundary tests
actually invoke (`runReceiptScan`), not at the platform-selection function. The platform gate in
`selectRecognizer` still runs under the default factory, so a platform with no engine still returns
`null` and the scan degrades to a blank draft rather than crashing.

Under the production default `defaultRecognizer` calls `selectRecognizer` on each scan, and
`selectRecognizer` constructs a fresh `MlKitTextRecognizer()` on every call, so production scans run
on and dispose a fresh recognizer each time. The seam does not create this behaviour: it comes from
the default factory, and the injected-test case does not assert it because it reuses one instance.

## Requirements

- The `TextRecognizer` seam keeps engine and framework swaps from reaching the extraction heuristics.
- Extraction is receipt-specific and lives in `app/`, never in `packages/ocr/`.
- Recognition is on-device only; an unreadable receipt falls back to manual entry, not a network
  call.
- Every non-extraction outcome lands on the same blank draft form; `TextRecognitionFailure` is caught
  once, at the UI hook point, and never reaches a widget.
- No extracted data is retained after prefill.
- `packages/ocr/` may depend on Flutter; only `packages/domain/` is hard Flutter-free.
- Engine selection checks `kIsWeb` and returns `null` on web until the Tesseract path lands;
  otherwise it returns the only built engine, ML Kit. (`app/lib/ocr/receipt_recognizer_selection.dart`)
