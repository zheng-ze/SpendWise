# Apple Vision vs Google ML Kit accuracy on iOS, for receipt OCR

Research for GitHub issue #8 (`zheng-ze/SpendWise`), which asks to settle the accuracy question
`docs/adr/0051-on-device-per-platform-ocr-split.md` left open — that ADR picked
`google_mlkit_text_recognition` for iOS on maintenance/support grounds only, without comparing it
against Apple's own Vision framework on accuracy. Sources are Apple's own developer documentation,
a WWDC19 session (via session-notes transcript, since Apple's live doc pages did not return body
text to automated fetch — see Method note below), Google's ML Kit documentation and CocoaPods
podspecs, the `flutter-ml/google_ml_kit_flutter` plugin repository, and independent blog
benchmarks, checked directly as of 2026-08-22. Where a source's own content is dated earlier (e.g.
a WWDC session year, a blog post's publish date), that date is called out per source.

**Method note**: Apple's `developer.apple.com/documentation/vision/...` pages render via
JavaScript and returned only page titles to automated fetch, not body content, and the Apple docs
JSON data API (`developer.apple.com/tutorials/data/...`) was not reachable from this environment.
Apple primary-source claims below are therefore sourced through the WWDC19 session-234 transcript
(via wwdcnotes.com, a third-party notes site that transcribes Apple's own session content) and a
tutorial site's direct quotes from the live API docs, not from a raw fetch of
`developer.apple.com` pages themselves. This is a real gap, flagged rather than papered over — see
Verdict.

## Question

For iOS on-device OCR of receipt photos (thermal print, typical skew/lighting), how does Apple's
Vision framework (`VNRecognizeTextRequest`) compare to `google_mlkit_text_recognition`'s iOS
backend on:

(a) text-extraction accuracy for receipt-like text — small print, numbers, mixed fonts,
thermal-paper degradation (low contrast, fading, speckling).

(b) hardware acceleration — does Vision have a documented Neural Engine / Apple Silicon
acceleration advantage ML Kit's iOS backend does not share, and specifically: does ML Kit's iOS
text recognizer wrap Apple's Vision/Core ML/Neural Engine APIs, or run Google's own cross-platform
model via Google's own runtime?

Out of scope (already settled in ADR 0051, not re-litigated here): the "no first-party Flutter
Vision wrapper, hand-written interop required" argument, and the platform-split decision itself.

## Candidates checked

### Apple Vision (`VNRecognizeTextRequest`)

- **Recognition levels**: `recognitionLevel` takes `.fast` or `.accurate`. A tutorial site quoting
  the live API docs directly states: "If accuracy is paramount, use `accurate` (though it takes
  longer), whereas `fast` is more suitable for speed-sensitive tasks"
  ([createwithswift.com, dated 2026-10-25](https://www.createwithswift.com/recognizing-text-with-the-vision-framework/) —
  note this publish date is later than this research's own check date, i.e. the site auto-dates or
  the fetch tool mis-parsed a date; treat the date as unreliable, the content as consistent with
  Apple's documented API shape). Apple's default for `VNRecognizeTextRequest` is `.accurate`.
- **Model architecture, stated by Apple at WWDC**: WWDC 2019 session 234, "Text Recognition in
  Vision Framework," is Apple's own explanation of how the two modes work. Per the session-notes
  transcript: fast mode "recognizes characters (with a small model)" and is less accurate; accurate
  mode "Uses a Neural Network to find the text (in terms of sentences placement in the image)" and
  "another Neural Network to read the text," and is "much [more] accurate, especially when
  'special' fonts are used." Apple's own presented timing numbers on a "small note picture": ~0.25s
  fast vs ~2s accurate
  ([wwdcnotes.com transcript of WWDC19-234](https://wwdcnotes.com/documentation/wwdc19-234-text-recognition-in-vision-framework/),
  session originally presented 2019, video also at
  [developer.apple.com/videos/play/wwdc2019/234/](https://developer.apple.com/videos/play/wwdc2019/234/)).
- **Hardware acceleration**: the same WWDC19 session is the one place a hardware-dispatch detail
  surfaced directly from Apple: Vision text recognition exposes a CPU-only override, described in
  the session as being "so you can set it to run only on the CPU to give more gpu/neural network
  for other core experiences (like ARKit)." The existence of this override is itself the
  documentation-level evidence that Vision's default path is *not* CPU-only — it dispatches to
  GPU/Neural Engine unless the developer opts out. No numeric accuracy or throughput delta between
  CPU-only and default dispatch was stated in the transcript. No newer WWDC session (WWDC21
  "Extract document data using Vision," WWDC25 "Read documents using the Vision framework") was
  fetched in full for this research; they were found by title search only
  ([developer.apple.com/videos/play/wwdc2021/10041/](https://developer.apple.com/videos/play/wwdc2021/10041/),
  [developer.apple.com/videos/play/wwdc2025/272/](https://developer.apple.com/videos/play/wwdc2025/272/))
  and their content was not verified against this question.
- **No published accuracy benchmark**: neither the API docs nor the WWDC transcript found gives a
  quantified accuracy number (e.g. a character- or word-error rate) for either recognition level, on
  receipts or otherwise. Apple's own documentation-level claim is qualitative ("more accurate,
  especially with special fonts") not measured.

**Verdict**: Apple confirms, in its own words, that `.accurate` mode is neural-network-based and
that Vision's default dispatch is not CPU-restricted (implying GPU/Neural Engine use is the
default, not an opt-in). Apple does not publish a quantified accuracy number, for receipts or any
other document class, in any primary source reached by this research.

### Google ML Kit Text Recognition — iOS backend (`google_mlkit_text_recognition` / `GoogleMLKit/TextRecognition`)

- **Crux fact — what model/runtime the iOS backend actually uses**: settled directly from the
  CocoaPods podspec dependency graph, not inferred. The Flutter plugin's iOS podspec depends on
  `GoogleMLKit/TextRecognition ~> 7.0.0`
  ([raw podspec, flutter-ml/google_ml_kit_flutter](https://raw.githubusercontent.com/flutter-ml/google_ml_kit_flutter/master/packages/google_mlkit_text_recognition/ios/google_mlkit_text_recognition.podspec)).
  That pod's own dependency, `MLKitVision`, was checked directly at the CocoaPods Specs source:
  its dependencies are `GTMSessionFetcher/Core`, `GoogleToolboxForMac/Logger`,
  `GoogleToolboxForMac/NSData+zlib`, `MLImage`, and `MLKitCommon` — all Google-owned pods — plus
  generic Apple **system** frameworks (`Accelerate`, `AVFoundation`, `CoreGraphics`, `CoreMedia`,
  `CoreVideo`, `Foundation`, `UIKit`) used for image/buffer plumbing, and one vendored binary:
  `MLKitVision.framework`
  ([CocoaPods/Specs, MLKitVision 6.0.0 podspec.json](https://github.com/CocoaPods/Specs/blob/master/Specs/8/1/e/MLKitVision/6.0.0/MLKitVision.podspec.json)).
  **Apple's `Vision.framework` or `VisionKit` does not appear anywhere in this dependency graph.**
  `MLKitVision.framework` is a Google-shipped precompiled binary, not a thin wrapper that calls
  into Apple's Vision APIs.
- **"Mobile Vision" is not Apple's Vision — a naming trap ruled out directly**: ML Kit's own
  migration guide, "Migrating from Mobile Vision to ML Kit on iOS," was checked to make sure this
  wasn't a false positive. It states plainly this covers migrating "from Google Mobile Vision (GMV)
  to ML Kit on iOS" — Google's own predecessor OCR SDK, unrelated to Apple's Vision framework
  despite the name collision
  ([developers.google.com/ml-kit/mobile-vision-migration/ios](https://developers.google.com/ml-kit/mobile-vision-migration/ios)).
  This confirms ML Kit's OCR lineage is Google-internal (Mobile Vision → ML Kit), not
  Apple-derived.
- **Model architecture, per independent technical sources**: ML Kit's on-device text recognition is
  consistently described as a TensorFlow-Lite-based pipeline — a CNN locates text regions, then a
  sequence decoder reads the characters — bundled into the app rather than calling a cloud API
  ([search-aggregated from Google-affiliated and third-party developer sources]; Google's own
  release/architecture pages did not state this in as many words in the pages fetched directly for
  this research, so this specific claim is weighted as corroborated-but-not-Google-primary-quoted;
  see Verdict).
- **Google's own iOS integration guide** (`developers.google.com/ml-kit/vision/text-recognition/v2/ios`,
  fetched directly) does not state what model or runtime backs the iOS recognizer at all — it
  covers integration steps and image-quality guidance only: "Poor image focus can affect text
  recognition accuracy. If you aren't getting acceptable results, try asking the user to recapture
  the image," and a character-size guideline: "each character should be at least 16x16 pixels" with
  "generally no accuracy benefit for characters to be larger than 24x24 pixels." It states assets
  "are statically linked to your app at build time" (models ship with the app, not
  downloaded-on-demand) but does not name Vision, Core ML, or TensorFlow Lite by name on this page.
- **No documented Neural Engine / Core ML dispatch**: no source checked — Google's iOS
  integration guide, the podspec dependency graph, or the migration doc — states that the iOS
  recognizer dispatches through Core ML or the Neural Engine. The `Accelerate` framework dependency
  in `MLKitVision`'s podspec is Apple's general-purpose vectorized-math framework (used for
  on-CPU/SIMD numerical work); its presence is not evidence of Neural-Engine dispatch, only that
  some numerical operations are hardware-accelerated at the vector-instruction level. This is a
  materially different (and lower) acceleration claim than Vision's documented GPU/Neural-Engine
  auto-dispatch.

**Verdict**: the crux fact is settled directly from primary sources (the podspec dependency graph),
not assumed: ML Kit's iOS text recognizer ships and runs Google's own `MLKitVision.framework` — a
cross-platform Google model, TensorFlow-Lite-lineage per independent technical sources — and does
**not** wrap or call Apple's Vision/Core ML/Neural Engine APIs. No source found documents Neural
Engine dispatch for ML Kit's iOS backend; Vision's Neural Engine/GPU dispatch is documented
(indirectly, via the CPU-only override) by Apple itself. This is a real, source-confirmed asymmetry
in documented hardware acceleration, not a symmetric "both probably do it" assumption.

### Independent benchmarks and developer reports

- **bitfactory.io head-to-head benchmark** (published 2021-06-30, tested on an iPhone 12): the only
  benchmark found that actually ran both engines against the same images rather than describing
  them separately. Test images were rotated text (0°-90° in 5° steps) and resolution-degraded text
  (500×500 down to 50×50 px) — not receipts, and not thermal-paper-specific degradation
  (low-contrast fading, speckling). Findings: ML Kit was roughly 6x faster (~0.05s vs ~0.31s
  average); Vision was "slightly better" on rotated text past ~20° rotation; ML Kit did somewhat
  better at low resolution around 125×125px; overall the two were close on accuracy, with speed the
  clearer differentiator
  ([bitfactory.io, "Comparing On-device OCR Frameworks Apple Vision and Google MLKit"](https://www.bitfactory.io/de/dev-blog/comparing-on-device-ocr-frameworks-apple-vision-and-google-mlkit/)).
  This is a real, dated, methodology-disclosed benchmark, but its test corpus (rotated/scaled clean
  text) does not stand in for thermal-receipt conditions — no low-contrast/faded/speckled test set
  was used.
- **General accuracy anecdotes**: one blog on receipt OCR broadly characterizes clean printed text
  as landing in a "95-99%" range for on-device OCR generally (not attributed to either engine
  specifically) and notes that "faded thermal paper, coffee-stained receipts, and poorly-lit phone
  photos" are where on-device engines are outperformed by larger server-side models — a generic
  on-device-vs-cloud tradeoff claim, not an Apple-vs-Google comparison
  ([scanlens.io, "On-Device vs Cloud OCR: Privacy, Speed, and Accuracy"](https://scanlens.io/blog/on-device-vs-cloud-ocr)).
  No anecdote or issue found from either project's tracker isolates thermal-print or small
  line-item receipt text as a specific accuracy complaint against one engine over the other.
- **No thermal-receipt-specific comparison found**: searches for "thermal receipt OCR Vision
  VNRecognizeTextRequest," GitHub issues on `flutter-ml/google_ml_kit_flutter` for
  receipt/thermal-print accuracy, and Apple Developer Forum threads did not surface a single
  head-to-head data point on thermal-paper receipts specifically for either engine. Existing
  developer reports on receipt OCR (e.g. a community `receipt_recognition` package built on ML Kit)
  give end-to-end accuracy estimates like "~85-100% accuracy depending on receipt quality and
  lighting conditions" — but these are ML-Kit-only, not comparative, and don't isolate thermal
  degradation from other quality factors
  ([github.com/manfredbork/receipt_recognition](https://github.com/manfredbork/receipt_recognition)).

**Verdict**: independent sources give one real (but off-topic) benchmark — rotation/resolution, not
receipts — that shows the two engines are close on accuracy with ML Kit faster. No source, primary
or independent, gives a thermal-receipt-specific accuracy comparison between the two engines.

## Verdict

**This documentation-level research does not settle the accuracy question (a).** No primary source
from either Apple or Google, and no independent benchmark found, tests thermal-print receipt
conditions specifically — low-contrast fading, speckling, skew combined with small line-item text —
for either engine, let alone head-to-head. The closest independent data point (bitfactory.io) tests
rotation and resolution on clean text, not thermal-paper degradation, and its finding ("close on
accuracy, ML Kit faster") cannot be extended to receipts without an unjustified leap. Any accuracy
claim for receipts specifically, for either engine, would be extrapolation, not settled fact — flag
this instead of writing a false conclusion.

**The hardware-acceleration question (b) — including the crux fact — is settled, directly, from
primary sources:**

- ML Kit's iOS text recognizer runs **Google's own `MLKitVision.framework`**, confirmed from the
  CocoaPods dependency graph of the actual pod (`GoogleMLKit/TextRecognition` → `MLKitVision`,
  checked at both the Flutter plugin's own podspec and the CocoaPods Specs source of record). It
  does **not** depend on or wrap Apple's `Vision.framework`/`VisionKit`. The "Mobile Vision" name
  that appears in ML Kit's own migration docs refers to Google's own predecessor SDK, not Apple's
  framework — checked directly to rule out a naming-collision false positive.
- Apple documents (via the WWDC19 session transcript, since live API docs did not return body
  content to this research's fetch tool — see Method note) that Vision's `.accurate` mode is
  neural-network based and that its default dispatch path is not CPU-restricted, implying GPU/Neural
  Engine use by default. No equivalent Neural-Engine-dispatch claim exists anywhere in ML Kit's
  documentation or dependency graph for the iOS backend.
- So: Vision has a documented (if indirect) hardware-acceleration claim ML Kit's iOS backend does
  not share in any source checked. This is a real asymmetry, not a wash.

**What would actually answer the accuracy question**, if it's worth settling before iOS OCR
implementation starts: a hands-on device test, not further documentation research. It would need,
at minimum:

1. A sample set of real thermal receipts spanning: fresh/high-contrast print, visibly faded print
   (thermal paper degrades with age/heat/light — get receipts at least several weeks old), and
   speckled/dot-dropout print from a worn or low-quality thermal head.
2. Deliberate skew angles per sample (e.g. 0°, 5°, 15° — realistic hand-held photo angles, not the
   bitfactory benchmark's up-to-90° rotation sweep, which is not representative of how someone
   photographs a receipt).
3. Small line-item text specifically, isolated from the merchant-name/total header text (which is
   usually printed larger) — since receipt line items are the smallest, most degraded print on the
   page and the least accuracy-tolerant field this app needs (issue #8's stated concern).
4. Numeric/currency parsing correctness as its own scored dimension, not just raw character
   accuracy — a receipt OCR engine can get characters mostly right and still misplace a decimal
   point or merge a subtotal with a tax line, which matters more for this app's use case (extracting
   totals) than generic character-error rate.
5. Both engines run against the *identical* photo set (not separately captured images, which the
   bitfactory benchmark also controlled for) so lighting/angle/distance are held constant, with both
   `VNRecognizeTextRequest.recognitionLevel = .accurate` and ML Kit's default configuration used —
   matching how each would actually ship in this app, not each engine's fastest/lowest-accuracy
   mode.

Absent that test, the honest recommendation is: hardware-acceleration and model-provenance are
Vision's documented (if modest) edge, but accuracy on the receipts this app actually needs to read
is an open empirical question neither vendor's documentation nor any benchmark found here answers.
