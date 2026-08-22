# Module spec — receipt OCR capture

**Scope:** the general-purpose `packages/ocr/` text-recognition package (interface, value types,
and the three per-platform/per-framework engines), and the receipt-specific field-extraction
pipeline in `app/` that turns its output into a structured prefill (name, amount, date) for the
existing entry form.

**Status:** design spec, pre-implementation. Wayfinder map "OCR Receipt Entry"
(github.com/zheng-ze/SpendWise issue #1) is fully walked; no open decision remains. Nothing has
been built yet. This doc is the architecture companion to `docs/specs/ocr-receipt-entry.md`, which
is the ratified behavior contract (Given/When/Then) and takes precedence on any behavioral
question. This doc exists for the code-structure questions the spec doesn't answer: how the OCR
package is shaped, why, and what implementing each piece involves.

**Relationship to the domain layer:** neither `packages/ocr/` nor the extraction pipeline in `app/`
write to `LedgerState` directly. Extraction produces prefill values handed to the same
entry-creation path a manually typed entry already goes through, so every ledger invariant and
validation rule that applies to a manually entered `Entry` applies here unchanged. This module is a
tool for populating the domain from the app layer, not part of the domain itself — see §3 for why
that boundary is drawn at `packages/ocr/`'s edge, not merely at `packages/domain/`'s.

**Governing ADRs:** `docs/adr/0051-on-device-per-platform-ocr-split.md` (on-device, per-platform
engine split, why no single engine covers all three platforms) and
`docs/adr/0052-receipt-text-recognizer-seam.md` (the seam this doc details, including its
placement in `packages/ocr/`; see that ADR's Revision notes for the two earlier placements this
superseded). Read both before touching this layer; this doc does not repeat their "why," only
their consequences for structure.

---

## 1. Purpose

Let the user photograph or pick a receipt image and have the entry form's name, amount, and date
fields prefilled from it, cutting typing for the common case, while never saving anything to the
ledger without the user reviewing the result first — and while keeping the engine that performs
recognition swappable, on two independent axes, without touching the extraction logic that
consumes its output.

## 2. The two swap axes

This layer is built against a single seam, `TextRecognizer`, specifically because two kinds of
change are already known to happen here, not hypothetically:

**Axis 1 — swap by platform.** iOS, Android and web each need a different engine today: no single
on-device engine covers all three (ADR-0051). The seam must let each platform select its own
implementation at the call site with zero change to anything downstream.

**Axis 2 — swap by framework, same platform.** Issue #8 already commits this app to a second iOS
engine (`VisionTextRecognizer`, Apple Vision) as an experimental path alongside the shipping ML Kit
implementation, switchable later if it proves more accurate. A better-maintained Tesseract.js
wrapper replacing the hand-wired web integration is the same kind of change on web (ADR-0051
Consequences). The seam must let a platform's engine be replaced outright — not just selected among
presets — without the field-extraction heuristics or the rest of the pipeline changing at all.

Both axes reduce to the same requirement: nothing above the seam may know which engine, or how
many engines, exist for a given platform. Section 3 is the seam that satisfies both from one
design, not two.

## 3. `packages/ocr/`: a general-purpose text-recognition package

The interface, its value types, and all three engine implementations live together in one new
package, `packages/ocr/`, sibling to `packages/domain/`. Unlike `packages/domain/`,
`packages/ocr/` is allowed to depend on Flutter, platform plugins, and `dart:js`/`package:web`
interop — the constraint this repo enforces is narrower than "only `app/` may use Flutter": it is
"`packages/domain/` may never use Flutter." `packages/ocr/` is a second, independent local package
that carries the OCR dependency exactly once, instead of scattering `google_mlkit_text_recognition`
imports and Tesseract.js interop through `app/lib`.

```dart
abstract class TextRecognizer {
  Future<RecognizedText> recognize(RecognizableImage image);
  Future<void> dispose();
}

class RecognizableImage {
  final Uint8List bytes; // already-decoded image bytes (PNG/JPEG), not a platform File or path
}

class RecognizedText {
  final List<RecognizedLine> lines;
}

class RecognizedLine {
  final String text;
  final RecognizedLineBounds? bounds; // when the engine exposes line geometry
  final double? confidence; // 0.0-1.0, when the engine exposes it — see §3 confidence note
  final List<String> recognizedLanguages; // BCP-47 codes; empty when the engine has no output-side language ID
}

class RecognizedLineBounds {
  final double top;
  final double bottom;
  final double left;
  final double right;
  double get height => bottom - top;
}

class TextRecognitionFailure implements Exception {
  final String message; // engine name + underlying cause, never shown to the user directly
}
```

Nothing in this package mentions receipts, amounts, merchants, or dates — `TextRecognizer` is
exactly as generic as its name says: hand it image bytes, get back recognized lines with optional
geometry, confidence, and language. That genericity is deliberate, not incidental: it is what makes
`packages/ocr/` independently reusable, and it is also what keeps axis 2 free, since a
`RecognizedText` consumer cannot depend on anything an engine uniquely offers — nothing
receipt-specific or engine-specific survives past this type. Block/paragraph hierarchy stays out:
`RecognizedText` is deliberately a flat line list, matching what §4's heuristics actually consume,
and restructuring to nested blocks is a bigger type change than this package's one real consumer
currently justifies.

The bounding box, confidence, and language fields are each optional/empty-by-default because their
actual availability varies by engine and platform — confirmed by primary-source research
(`docs/research/ocr-confidence-language-fields.md`), not assumed:

- **Bounds**: present at line granularity on every named engine — ML Kit's line result, and
  Tesseract.js's `rowAttributes`/`bbox` output requested via `{ blocks: true }` (ADR-0051).
- **Confidence** (`double?`, 0.0–1.0): present on all three engines, but not uniformly. ML Kit's
  native `Text.Line.getConfidence()` is Android-only — the plugin's own doc comment states it
  returns `null` on iOS, so `MlKitTextRecognizer` (§5.1) can only ever populate this field on
  Android. Tesseract.js reports an integer 0–100 per line (`Confidence(PageIteratorLevel)`,
  documented as a percent probability) — `TesseractTextRecognizer` (§5.2) divides by 100 to match
  this type's 0.0–1.0 scale. Vision's `VNRecognizedText.confidence` is per recognized-text
  candidate, which is line-granularity here, already 0.0–1.0. No engine offers word- or
  character-level confidence through the APIs consulted, so this field stays line-level, matching
  `RecognizedLine` itself.
- **`recognizedLanguages`** (`List<String>`, BCP-47 codes, empty list when unavailable — never
  null, so callers don't need a null check on top of an empty-list check): present, at line
  granularity, only on ML Kit — and even there it is the Flutter plugin wrapping native Android's
  *singular* `getRecognizedLanguage()` into a one-element list; iOS ML Kit has no confirmed
  language output either. Tesseract.js and Vision have **no output-side language or script
  identification at all** in the APIs consulted — Tesseract.js's `lang` and Vision's
  `recognitionLanguages` are both worker/request-configuration *input* (which language model to
  use), never a per-result field. So `recognizedLanguages` is realistically populated on Android
  ML Kit only, and empty everywhere else. It is included anyway because when it is available it
  costs the consuming heuristic nothing to ignore, and a future engine (or a future ML Kit iOS
  release) could change this without another type change — but no heuristic in this app should be
  designed assuming it will usually be non-empty, since today it usually won't be.

This is a genuinely different reliability story for the two fields: confidence is usable, with a
documented platform gap, on every engine; language is usable on close to one platform out of the
three this app ships to. Both are included because §2's genericity goal means `packages/ocr/`
should expose what its engines actually offer rather than only what this app's current three
heuristics need — but a caller should treat `recognizedLanguages` as "occasionally present," not
as a reliable signal, until a wider engine survey says otherwise.

`TextRecognizer.recognize` takes a `RecognizableImage`, not a platform `File`, path, or
engine-specific type. Producing one from whatever the camera/picker plugin returns (bytes, a path,
an `XFile`) is `app/`'s job at the UI hook point (§8), not the recognizer's — this keeps
platform-specific image-acquisition types from leaking into the seam alongside the recognized-text
type, the same discipline this section already applies on the output side. `recognize` throws
`TextRecognitionFailure` for any failure the engine surfaces (decode failure, plugin unavailable,
native crash); it does not return an empty `RecognizedText` to signal failure, so "engine ran and
found nothing" (empty `lines`) and "engine could not run" are never conflated. §6 covers where that
exception is caught in `app/` and how it collapses to the same blank-draft outcome as an empty
result — the two cases converge only after this seam, never inside it.

`dispose` exists because every named implementation holds a resource an interface with only
`recognize` would leak: ML Kit's `TextRecognizer` (the plugin's own class, distinct from this
package's `TextRecognizer` interface) needs `close()`; a Tesseract.js integration owns a worker
needing `terminate()`. The call site (§5.4) owns the recognizer's lifetime and is responsible for
calling `dispose` when the scan/upload flow ends.

There is no capability negotiation beyond the optional/empty-by-default fields already described —
no "does this engine support geometry" or "does this engine report confidence" query. A caller that
needs geometry-dependent behavior (the name heuristic, §4) checks `RecognizedLine.bounds` for null,
per line, at the point of use; a caller that wants to use confidence checks it for null the same
way. This keeps
new implementations cheap to add over the life of this feature (Vision, a future Tesseract.js
wrapper): each one should be nothing but "call the engine, map its result into `RecognizedText`,
throwing `TextRecognitionFailure` on the way out if the engine call fails."

Dependency direction: `app/` depends on `packages/domain/` and `packages/ocr/` by path, same as
today plus one new package. `packages/ocr/` depends on neither `app/` nor `packages/domain/` — it
has no reason to import ledger types, since its job ends at producing recognized lines, not at
constructing an `Entry`. `packages/domain/` gains no new dependency at all from this module and
stays exactly as pure-Dart-only as it already is; nothing here relaxes that constraint, only the
separate, narrower constraint that used to also fence Flutter out of everywhere except `app/`.

## 4. Receipt field-extraction, in `app/`

The three field-extraction heuristics — amount, name, date — are receipt-specific and live in
`app/`, not `packages/ocr/`: keyword sets like "TOTAL"/"SUBTOTAL", address- and phone-pattern
filters, day/month disambiguation are all receipt vocabulary, exactly the kind of thing
`packages/ocr/`'s genericity (§3) is defined to exclude. Each heuristic is a plain function from
`RecognizedText` (imported from `packages/ocr/`) to an optional result — `Decimal?`, `String?`,
`DateTime?` (date has its own today-default per spec, so it is never actually null in the
caller-visible result) — operating only on `RecognizedText.lines`, never on anything
engine-specific. This is what axis 1 and axis 2 both actually buy: the same three functions run
unchanged regardless of which `packages/ocr/` engine produced the input, on any platform, present
or future.

The full rules for each heuristic — the keyword sets, the pattern filters, the exact numeric
thresholds, the day/month disambiguation logic — are normative in
`docs/specs/ocr-receipt-entry.md` under "Field extraction" and are not restated here to avoid two
sources of truth drifting apart. Summary of what each heuristic depends on from `RecognizedText`:

- **Amount** (spec: keyword-matched total line, falling back to the last currency-formatted
  number) depends only on `RecognizedLine.text` across all lines. No geometry needed.
- **Name** (spec: scan the first 5 lines, apply pattern filters, prefer the tallest surviving line
  when height is known) depends on `RecognizedLine.text` for filtering and optionally
  `RecognizedLine.bounds.height` for tie-breaking among survivors. This is the one heuristic whose
  output quality depends on whether the recognizer populates `bounds` — see §5.
- **Date** (spec: first date-shaped text, locale-aware day/month disambiguation) depends only on
  `RecognizedLine.text`.

None of the three take a recognizer, an engine identifier, or a platform argument; they cannot,
structurally, special-case an engine, which is the property this whole layer is built around.

None of the three use `RecognizedLine.confidence` or `RecognizedLine.recognizedLanguages` — no
requirement in `docs/specs/ocr-receipt-entry.md` calls for confidence-weighted extraction or
language-aware parsing, and per §3, `recognizedLanguages` is realistically empty on two of the
three shipping engines anyway. Both fields exist on `RecognizedText` because `packages/ocr/` is
general-purpose (§3), not because these heuristics need them; a future heuristic (or a future
`packages/ocr/` consumer outside this app) is free to use them without another type change.

## 5. Engines, all in `packages/ocr/`

### 5.1 `MlKitTextRecognizer` — iOS, Android

Wraps `google_mlkit_text_recognition`. Same package, same call shape on both platforms; no open
decision remains for either (issue #8 resolved Vision as an additional, non-blocking iOS path, not
a replacement — see §5.3). Maps the plugin's per-line bounding-box result directly into
`RecognizedLineBounds`, so the name heuristic's geometry-aware branch is always active on these
platforms. Maps `TextLine.confidence` directly into `RecognizedLine.confidence` on Android; always
leaves it null on iOS, matching the plugin's own documented behavior (`confidence` is Android-only
at the native level). Maps `TextLine.recognizedLanguages` directly into
`RecognizedLine.recognizedLanguages` — populated on Android from the native singular
`getRecognizedLanguage()` wrapped into a list by the plugin; not confirmed populated on iOS in the
docs consulted, so this recognizer must not assume it is non-empty there. Wraps plugin exceptions
(recognizer initialization failure, a corrupt image the plugin rejects) in `TextRecognitionFailure`
rather than letting the plugin's own exception type escape the package. `dispose` calls the
underlying plugin recognizer's `close()`.

### 5.2 `TesseractTextRecognizer` — web

Hand-wired Tesseract.js integration, not a Flutter wrapper package — none was found to deliver a
working web binding (ADR-0051). Calls Tesseract.js with `{ blocks: true }` output so per-line
geometry is available (`rowAttributes.rowHeight`/`bbox`, mapped into `RecognizedLineBounds`),
confirmed present in Tesseract.js's own type definitions. Requires a `dart:js`/`package:web`
interop layer to marshal Tesseract.js's nested block/paragraph/line/word result into
`RecognizedText`, and to decode the incoming `RecognizableImage.bytes` into whatever input shape
Tesseract.js's own API expects. Flagged in ADR-0051 as untested and worth a spike before relying on
it — this is the highest-risk piece of the whole layer and the reason the suggested build order
(`docs/HANDOVER.md`) sequences it last. `dispose` terminates the Tesseract.js worker.

Omitting `{ blocks: true }` is not an error case: the name heuristic already degrades to
first-surviving-line when `bounds` is null, so a `TesseractTextRecognizer` that for any reason
cannot get geometry still produces a usable, if less precise, result rather than failing. A
Tesseract.js call that fails outright (worker crash, WASM load failure) is a `recognize`-time error
and surfaces as `TextRecognitionFailure`, same as §5.1's plugin-exception case — geometry being
unavailable and recognition failing outright are different outcomes and only the second throws.

Maps each line's integer `confidence` (0–100, from `Confidence(PageIteratorLevel)`) into
`RecognizedLine.confidence` by dividing by 100, matching every other engine's 0.0–1.0 scale.
Tesseract.js has no output-side language field at any level of its result — `recognizedLanguages`
is always the empty list for this recognizer; `lang` is a worker-init input (which trained-language
model to load), never a result.

### 5.3 `VisionTextRecognizer` — iOS, experimental

Apple Vision framework path from issue #8, resolved as a separate learning-value build, explicitly
not blocking and not part of the MVP shipping path. `MlKitTextRecognizer` stays the sole shipping
iOS engine unless a later decision changes that. Existing only as a class satisfying
`TextRecognizer` is sufficient proof that axis 2 works: nothing in §4 or in the call site selecting
an iOS engine needs to change to add it. Vision's own bounding-box result maps onto
`RecognizedLineBounds` the same way ML Kit's does; nothing about the value types needed to change
to accommodate a second iOS engine, which is the actual test of whether the seam holds.

Maps each recognized text candidate's `VNRecognizedText.confidence` (already 0.0–1.0) directly into
`RecognizedLine.confidence` — Vision's confidence is per-candidate, which lines up with this type's
line granularity, so no rescaling is needed, unlike Tesseract.js. Vision has no output-side language
field on `VNRecognizedText` or `VNRecognizedTextObservation` — `recognizedLanguages` is always the
empty list for this recognizer; `recognitionLanguages`/`automaticallyDetectsLanguage` are
request-configuration inputs on `VNRecognizeTextRequest`, never a result.

### 5.4 Engine selection at the call site

Which recognizer runs on a given platform is a single choice, made in `app/` where the OCR entry
point is wired up, of which `packages/ocr/` `TextRecognizer` implementation gets constructed. That
choice must check `kIsWeb` first: `dart:io`'s `Platform.isIOS`/`Platform.isAndroid` cannot be
evaluated on web at all (`dart:io` is unavailable on that target), so the selection is `kIsWeb` →
`TesseractTextRecognizer`, else `Platform.isIOS` → `MlKitTextRecognizer`, else (Android) →
`MlKitTextRecognizer` — never a bare `Platform.isIOS`/`isAndroid` check reached before the
`kIsWeb` branch has already ruled out web. Use the app's existing platform-selection convention if
one already exists elsewhere in `app/lib`, applying the same `kIsWeb`-first ordering. This is the
only place platform identity is inspected anywhere in this layer — not in `packages/ocr/`'s
interface, not in `RecognizedText`, not in the extraction heuristics.

## 6. Failure handling

Extraction failure is never surfaced as a distinct error state — this is a hard requirement in
`docs/specs/ocr-receipt-entry.md` ("Every non-extraction outcome lands on the same draft form"), not
a preference. A corrupt file, an unreadable image, and a successfully processed image whose fields
all fail to extract all produce the same new-entry form, populated with whatever subset of the
three fields actually resolved (zero, some, or all three), no error dialog, no "could not read
receipt" message, no visible distinction from a manually started blank draft. A single loading
indicator covers processing on every platform regardless of that platform's typical recognition
speed.

Concretely: the UI hook point (§8) wraps its call to `recognize` in a single try/catch for
`TextRecognitionFailure` (§3) and treats a caught failure identically to a successful call that
returned `RecognizedText(lines: [])` — both proceed straight to §4's heuristics, which already
produce blank fields (save date's today-default) from empty input with no special-casing needed.
This is the one and only place `TextRecognitionFailure` is caught anywhere in this layer; it is
never allowed to reach a widget's `build` method or any error-display code path.

This mirrors the category classifier's confidence gate (`category_classifier.md` §4): when the
evidence is not good enough to support a specific answer, the field is left blank rather than
filled with a low-confidence guess. Date is the sole exception, defaulting to today rather than
blank, per spec.

Nothing extracted is retained after prefill: the source image and any intermediate recognized text
are discarded immediately once the three fields are extracted, on every platform, with no "view
raw scan" affordance anywhere in the UI.

## 7. Integration with the category classifier

The extracted merchant name is placed into the entry form's name field through the same path a
manually typed name would take. The category classifier's `predict` call
(`category_classifier.md` §2.4) runs against OCR-derived text exactly as it would against
hand-typed text, with no special-casing, and the user accepting or correcting the resulting
suggestion is a normal `observe` training signal (`category_classifier.md` §3) regardless of where
the name came from.

## 8. UI hook point

Per `docs/specs/ocr-receipt-entry.md` ("Entry point"), "Scan receipt" and "Upload photo" actions sit
at the top of the new-entry form, gated by a settings toggle (default shown) and by platform
("Scan receipt" on iOS/Android only; "Upload photo" everywhere including web). Either action
produces image bytes from the camera or file picker plugin, wraps them in a `RecognizableImage`
(§3), and calls `recognize` on the platform's selected `packages/ocr/` `TextRecognizer` (§5.4)
inside the try/catch described in §6. Converting whatever the picker plugin returns (a path, an
`XFile`, raw bytes) into `RecognizableImage.bytes` happens here, at the hook point — this is the
one place image-acquisition's own platform-specific types are handled, kept out of `packages/ocr/`
itself (§3). The resulting `RecognizedText`, real or empty, feeds §4's receipt-specific heuristics,
and the existing entry-form sheet opens with the extracted name, amount, and date passed as initial
values. The form behaves exactly as it does for a new entry started from scratch: every field stays
editable, and nothing is written to the ledger until the user saves. The recognizer's `dispose`
(§3) is called once the flow ends, whether it succeeded, failed, or the user backed out before
completion.

## 9. Non-goals

- No line-item-level extraction. The feature reads a single total, a single merchant name, and a
  single date; it does not itemize individual receipt lines into separate entries.
- No cloud OCR, on any platform, ever, as a fallback or otherwise — recognition is on-device only
  (ADR-0051). A receipt the on-device recognizer cannot read falls back to manual entry per §6, not
  to a network call.
- No custom-trained recognition model — text recognition is a commoditized problem better solved
  by an existing engine than by a model built for this feature.
- No receipt image attachment or retention, no cloud sync of scan results — explicitly deferred,
  tracked in the wayfinder map's Out of scope, not part of this module.
- `packages/ocr/` is not scoped, designed, or tested as a publishable general-purpose package —
  "general-purpose" here means "not receipt-specific," not "hardened for external consumers." It
  has exactly one consumer, this app, for now.
