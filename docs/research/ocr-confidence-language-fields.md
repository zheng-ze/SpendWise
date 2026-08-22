# OCR engines: confidence and language/script output fields

Primary-source research into what confidence-score and language/script-identification
**output** fields three OCR engines expose, at what granularity. Input-only configuration
(e.g. worker init languages, request-level recognition languages) is explicitly called out
as input, not output.

## 1. google_mlkit_text_recognition (Flutter plugin over ML Kit Text Recognition v2)

The Flutter plugin (`flutter-ml/google_ml_kit_flutter`, package
`google_mlkit_text_recognition`) wraps native ML Kit. Its Dart result hierarchy is
`RecognizedText > TextBlock > TextLine > TextElement > TextSymbol`.

### Confidence

- **Flutter plugin (Dart)**: `TextLine`, `TextElement`, and `TextSymbol` each declare a
  field `final double? confidence;`. `TextBlock` and `RecognizedText` do **not** have a
  confidence field.
  - Source doc comment, verbatim: `// The confidence of the recognized line. // Only
    available in Android, for iOS returns null.` (identical wording, "element"/"symbol"
    substituted, on `TextElement` and `TextSymbol`).
  - So confidence is populated on Android, always `null` on iOS, at line/element/symbol
    granularity. No block-level confidence in the plugin.
- **Native Android** (`com.google.mlkit.vision.text.Text`): `Text.TextBlock` has **no**
  `getConfidence()`. `Text.Line` and `Text.Element` each have `public float getConfidence()`,
  documented: "Gets the confidence of the recognized element/line. It is in range
  [0.0f, 1.0f]. Note that this information will be unavailable (i.e. returns 0) if you're
  using the unbundled version of Text Recognition library with an older version of Google
  Play services (lower than 22.30.XX)." So current Android docs confirm confidence is live
  at line and element granularity (0.0–1.0 float), not block granularity, contingent on a
  recent-enough Play services version for the unbundled library.
  - A 2020 Firebase quickstart-android issue (#1040, filed against ML Kit 24.0.1) reported
    `getConfidence()` returning null/0 across the board — this predates the unbundled ML Kit
    Text Recognition v2 API and the documented Play-services-version caveat above; current
    reference docs do not describe confidence as removed.
- **Native iOS**: The v2 iOS guide's code samples and reference do not show a confidence
  property on `MLKTextBlock`/`MLKTextLine`/`MLKTextElement`. This matches the Flutter
  plugin's own doc comment that `confidence`/`angle` return `null` on iOS. No iOS-side
  `confidence` output field was found in the docs consulted.

### Language/script ID as output

- **Flutter plugin (Dart)**: every level of the hierarchy below `RecognizedText` —
  `TextBlock`, `TextLine`, `TextElement`, and `TextSymbol` — declares
  `final List<String> recognizedLanguages;`, doc-commented "List of recognized languages in
  the text block/line/element/symbol. If no languages were recognized, the list is empty."
  Populated from JSON key `recognizedLanguages` via a `_listToRecognizedLanguages` helper.
  So granularity is block/line/element/symbol, type is a list of strings, and (per source)
  it is populated on both platforms (no "Android only" comment on this field, unlike
  `confidence`/`angle`).
- **Native Android**: `Text.TextBlock`, `Text.Line`, and `Text.Element` each expose
  `String getRecognizedLanguage()` — **singular**, returning one BCP-47 language code (or
  `"und"` if undetermined), not a list.
- **Discrepancy**: the Flutter plugin's field is named `recognizedLanguages` (plural,
  `List<String>`) at every level, while the underlying native Android method is
  `getRecognizedLanguage()` (singular, one `String`). The plugin wraps the single native
  value into a one-element (or empty) list rather than exposing multiple languages per
  region.
- No output-side script/orientation field beyond `recognizedLanguages`/`recognizedLanguage`
  was found in either the plugin or native Android docs consulted.

### Sources

- `https://raw.githubusercontent.com/flutter-ml/google_ml_kit_flutter/master/packages/google_mlkit_text_recognition/lib/src/text_recognizer.dart` — exact Dart class bodies for `RecognizedText`, `TextBlock`, `TextLine`, `TextElement`, `TextSymbol`, including doc comments confirming `confidence`/`angle` are Android-only and `recognizedLanguages` is `List<String>` at every level.
- `https://developers.google.com/android/reference/com/google/mlkit/vision/text/Text.TextBlock` — confirms no `getConfidence()`; confirms `getRecognizedLanguage()` (singular).
- `https://developers.google.com/android/reference/com/google/mlkit/vision/text/Text.Line#getConfidence()` — exact method doc: range, unavailability caveat tied to Play services version.
- `https://developers.google.com/android/reference/com/google/mlkit/vision/text/Text.Element#getConfidence()` — same doc text for `Text.Element`.
- `https://developers.google.com/android/reference/com/google/mlkit/vision/text/Text.Line` / `Text.Element` — full method lists confirming `getConfidence()`, `getRecognizedLanguage()`, `getAngle()`, etc.
- `https://developers.google.com/ml-kit/vision/text-recognition/v2/ios` — iOS guide code samples showing `recognizedLanguages` on `TextBlock`, no confidence property surfaced.
- `https://github.com/firebase/quickstart-android/issues/1040` — historical report of `getConfidence()` returning null (2020, pre-unbundled-v2 API); context only, not current-API ground truth.

## 2. Tesseract.js (github.com/naptha/tesseract.js)

`worker.recognize()` with `{ blocks: true }` (or equivalent output option) returns
`data.blocks`, produced by the native (WASM-compiled) Tesseract method `GetJSONText()`. That
method's C++ implementation lives in a patched fork of Tesseract
(`Balearica/tesseract`, branch `tesseract.js-core`, used as the `third_party/tesseract` git
submodule of `naptha/tesseract.js-core`, which `tesseract.js` depends on for its WASM core).
The JS-side `dump.js` in `naptha/tesseract.js` does:
`blocks: output.blocks && !options.skipRecognition ? JSON.parse(api.GetJSONText()).blocks : null`.

The JSON hierarchy actually emitted (confirmed by reading `src/api/jsonrenderer.cpp`
verbatim) is: `blocks[] > paragraphs[] > lines[] > words[] > symbols[]` (there is no
separate "Page" wrapper object inside `blocks` — the page-level wrapping,
`{ page_id, blocks }`, is added by `GetJSONText`, and a further `{ version, pages }` wrapping
is added by the file-output `TessJsonRenderer`, not by the in-browser `data.blocks` value).

### Confidence

Every level in the hierarchy carries a `"confidence"` field, each produced by
`res_it->Confidence(LEVEL)` cast to `int`:
- **block**: `"confidence"` (int)
- **paragraph**: `"confidence"` (int)
- **line**: `"confidence"` (int)
- **word**: `"confidence"` (int) — plus a `"choices"` array of alternate recognition
  candidates, each itself `{ "text": ..., "confidence": ... }` (from
  `WordChoiceIterator::Confidence()`).
- **symbol**: `"confidence"` (int)

Scale: per the underlying `Confidence(PageIteratorLevel)` C++ declaration in
`include/tesseract/ltrresultiterator.h`: "Returns the mean confidence of the current object
at the given level. The number should be interpreted as a percent probability.
(0.0f-100.0f)." The JSON renderer truncates this float to an integer via
`static_cast<int>`. So every level's `confidence` in `data.blocks` is an integer 0–100.

If recognition has not yet completed for a given call (`recognition_done_` false, i.e. a
layout-only pass), `"text"` and `"confidence"` are emitted as JSON `null` at every level.

Separately, the top-level `recognize()` result also has a whole-page
`data.confidence` field (outside `data.blocks`), sourced from `api.MeanTextConf()` in
`dump.js` — a single number for the whole page, not part of the block/paragraph/line/word/
symbol hierarchy.

### Language/script ID as output

No `lang`, `language`, or `script` key appears anywhere in the JSON emitted by
`jsonrenderer.cpp` at any level (block/paragraph/line/word/symbol). The complete set of
fields emitted per level is: `bbox`, `text`, `confidence`, and level-specific extras
(`blocktype`, `paragraphs` at block level; `is_ltr`, `lines` at paragraph level;
`rowAttributes`, `baseline`, `words` at line level; `choices`, `font_name`, `symbols` at
word level; `is_superscript`, `is_subscript`, `is_dropcap` at symbol level). None of these
is a language or script identifier.

The `lang`/`langs` parameter passed to `createWorker()` is worker-initialization input
(which trained-language model(s) to load for recognition), not a per-result output field,
and does not appear anywhere inside `data.blocks`.

### Sources

- `https://raw.githubusercontent.com/naptha/tesseract.js/master/src/worker-script/utils/dump.js` — confirms `data.confidence` comes from `api.MeanTextConf()` (whole-page) and `data.blocks` comes from `JSON.parse(api.GetJSONText()).blocks`, gated on `!options.skipRecognition`.
- `https://github.com/naptha/tesseract.js-core` (repo root + `.gitmodules`) — confirms `third_party/tesseract` submodule points at `Balearica/tesseract`, and that `GetJSONText` is a `TessBaseAPI` method (via `javascript/src/glue.cpp`, line ~890: `emscripten_bind_TessBaseAPI_GetJSONText_1` calling `self->GetJSONText(page_number)`).
- `Balearica/tesseract` repo, branch `tesseract.js-core`, file `src/api/jsonrenderer.cpp` (fetched via GitHub Git Data API blob `ba5130305c19c26eeb7165fb814c854d9e177344`) — the exact C++ source that builds the JSON tree; read in full and quoted above for every `"confidence"` emission site and the complete field list at each level; confirms no language/script field exists anywhere in the output.
- `Balearica/tesseract` repo, branch `tesseract.js-core`, file `include/tesseract/ltrresultiterator.h` — declares `float Confidence(PageIteratorLevel level) const;` with doc comment "The number should be interpreted as a percent probability. (0.0f-100.0f)", and the word-choice-level `float Confidence() const;` with the same scale note.

## 3. Apple Vision framework (VNRecognizeTextRequest / VNRecognizedTextObservation / VNRecognizedText)

### Confidence

- **`VNRecognizedText.confidence`**: declared property, `var confidence: VNConfidence { get }`
  (`VNConfidence` is Apple's confidence type alias, a `Float`). Apple's docs: "The level of
  confidence in the observation's accuracy," normalized to `[0.0, 1.0]` in the general case
  (confidence-unaware requests report `1.0`). `VNRecognizedText` represents one recognition
  **candidate string** for an observation (an observation's `topCandidates(_:)` call returns
  an array of `VNRecognizedText`, ranked); `VNRecognizeTextRequest` operates at a
  line/string-observation level (each `VNRecognizedTextObservation` is one recognized text
  region, not a single word), so this confidence is per-candidate-string, effectively
  per-line/per-observation, not per-word or per-character.
- **`VNRecognizedTextObservation`**: does **not** redeclare `confidence`. Its Objective-C
  declaration is `@interface VNRecognizedTextObservation : VNRectangleObservation`. The
  inheritance chain for `confidence` is `VNRecognizedTextObservation` →
  (`VNRectangleObservation` →) `VNDetectedObjectObservation` → `VNObservation`, which is
  where `confidence` is actually declared: `var confidence: VNConfidence { get }` (base
  declaration on `VNObservation`, "the abstract superclass for analysis results"; see
  `VNObservation.confidence`'s own doc page, same signature and description as above).
  `VNDetectedObjectObservation` itself adds `boundingBox` and `globalSegmentationMask`, not
  its own `confidence`.
- Net: there is exactly one `confidence` value per observation-level object: the
  observation's own inherited `VNObservation.confidence`, and each of its recognized-text
  *candidates* (`VNRecognizedText`, from `topCandidates(_:)`) carries its own separately
  reported `confidence`. Neither `VNRecognizeTextRequest` nor Vision otherwise expose a
  per-word or per-character confidence — `VNRecognizedTextObservation` is a line/string-level
  region.

### Language/script ID as output

- No output-side language or script identification property exists on either
  `VNRecognizedText` or `VNRecognizedTextObservation` in the documentation consulted.
  `VNRecognizedText`'s documented members are `string` (the candidate text, `String`),
  `confidence` (`VNConfidence`), and `boundingBox(for:)` (a method computing a bounding box
  for a substring range) — no language/script field.
- The only language-related property found anywhere in this API surface is
  **`recognitionLanguages: [String]`** on `VNRecognizeTextRequest` itself — explicitly
  documented as "An array of languages to detect, in priority order." This is a
  **request-configuration input** the caller sets before running recognition, not a result
  field. `VNRecognizeTextRequest` also has `automaticallyDetectsLanguage: Bool` ("whether to
  attempt detecting the language to use the appropriate model for recognition and language
  correction") — also a request-level input/configuration switch, and even when set, the
  chosen/detected language is not exposed back as a result property in the docs consulted;
  no corresponding output field (e.g. a "detected language" result property) was found on
  `VNRecognizedTextObservation` or `VNRecognizedText`.

### Sources

- `https://developer.apple.com/tutorials/data/documentation/vision/vnrecognizedtext.json` — confirms `VNRecognizedText`'s full member list: `string: String`, `confidence: VNConfidence`, `boundingBox(for:)`, `init(coder:)`; no language field.
- `https://developer.apple.com/tutorials/data/documentation/vision/vnrecognizedtextobservation.json` — confirms class declaration `@interface VNRecognizedTextObservation : VNRectangleObservation`, and that its only own member beyond inherited ones is `topCandidates(_:)`.
- `https://developer.apple.com/tutorials/data/documentation/vision/vnobservation.json` and `https://developer.apple.com/tutorials/data/documentation/vision/vnobservation/confidence.json` — confirms `confidence` is declared on the base class `VNObservation` (`var confidence: VNConfidence { get }`), with the "normalized to [0.0, 1.0]" discussion text, and topic-section evidence that `VNObservation` is where `confidence` and `VNConfidence` are introduced (grouped under "Evaluating Observations").
- `https://developer.apple.com/tutorials/data/documentation/vision/vndetectedobjectobservation.json` — confirms `VNDetectedObjectObservation`'s own declared members are `boundingBox` and `globalSegmentationMask`, not a redeclared `confidence` (i.e. `confidence` is inherited through this class from `VNObservation`, not introduced here).
- `https://developer.apple.com/tutorials/data/documentation/vision/vnrecognizetextrequest.json` — confirms `recognitionLanguages: [String]` and `automaticallyDetectsLanguage: Bool` are properties of the *request* object (input/configuration), alongside `usesLanguageCorrection`, `customWords`, `minimumTextHeight`, `recognitionLevel`, and the `results: [VNRecognizedTextObservation]?` output property — establishing by contrast that language configuration lives on the request, not on any result type.

Note on method: Apple's rendered HTML documentation pages
(`developer.apple.com/documentation/vision/...`) are heavily JS-rendered and did not yield
usable content via fetch. The `https://developer.apple.com/tutorials/data/documentation/...json`
endpoint (Apple's own DocC data API backing those same pages) did return full, structured,
verbatim documentation content and was used for every Vision-framework fact above.
