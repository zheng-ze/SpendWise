# OCR accuracy testing strategy

Research for GitHub issue #9 (`zheng-ze/SpendWise`), which asks what validates that this app's OCR
receipt entry (ADR-0051, ADR-0052, `docs/specs/ocr-receipt-entry.md`) actually works, given there
is no server-side test harness and recognition runs on-device through two engines today
(`google_mlkit_text_recognition`, hand-wired Tesseract.js) and a third soon (Apple Vision, issue
#8). Sources are Martin Fowler's own site, Google Research's published ML-testing paper, Google's
CocoaPods/ML Kit documentation already checked in prior research, the Tesseract project's own
testing docs, the CORD dataset's GitHub repository, and a real shipping Flutter package
(`receipt_recognition`, built on ML Kit) checked directly at the source level — not blog summaries
— as of 2026-08-22.

## Question

1. Is engine-level OCR accuracy standard practice to treat as out of an app's own test scope (trust
   the vendor), or do teams commonly build corpus-based accuracy regression tests even for
   third-party engines?
2. Given `RecognizedText` (ADR-0052) already exists as an engine-agnostic seam, is unit-testing the
   amount/name/date heuristics against synthetic/hand-built `RecognizedText` fixtures standard and
   sufficient, or does real-image testing catch failure classes fixtures structurally can't?
3. If a real/realistic receipt corpus is warranted: how do practitioners source and store one
   safely — synthetic generation, scrubbed real receipts, public datasets (SROIE, CORD) — given even
   "sample" receipts can carry incidental PII/financial data?
4. What does prior art from real Flutter/mobile projects layering custom parsing on a third-party
   on-device recognizer actually do at the test-boundary?

## Sources checked

### Martin Fowler / Sato & Wider, "Continuous Delivery for Machine Learning" (martinfowler.com, 2019)

Checked directly at `martinfowler.com/articles/cd4ml.html`. This is the most-cited
software-engineering-authored (not ML-research-authored) source on testing ML-dependent systems,
and it draws exactly the boundary this question needs:

- **Contract tests, not accuracy tests, at the integration point.** The article's guidance for
  where an application meets a model it consumes is "Contract Tests to validate that the expected
  model interface is compatible with the consuming application" — a shape/schema check, not an
  accuracy check.
- **Model quality gates belong to the model's own pipeline, not the consuming app.** "New models
  don't degrade against a known performance baseline" is scoped to whoever owns and retrains the
  model — the article discusses this in the context of a team's own ML pipeline shipping ML
  artifacts, with a held-out validation dataset distributed *alongside the model artifact* so a
  consuming system can "reassess the model's performance against the holdout dataset after it is
  integrated." That reassessment is framed as integration-level validation the model owner enables,
  not a corpus an unrelated downstream app is expected to build from scratch.
- **Holistic quality (bias, fairness, "does this actually work well") is explicitly flagged as hard
  to fully automate** — the article recommends manual review stages for that, not more unit tests.

Read onto this question: ML Kit and Tesseract.js are both cases where SpendWise is the consuming
application, not the model owner. Neither vendor ships a holdout dataset for SpendWise to
integration-test against, and SpendWise has no ability to retrain or gate either engine's releases.
The article's own framework puts "does the vendor's model perform well" outside the consuming app's
test responsibility, and puts "is our code called correctly against the model's contract" inside
it.

### Google Research, "The ML Test Score: A Rubric for ML Production Readiness and Technical Debt
Reduction" (Breck et al., research.google)

This paper (its existence and abstract) is real and is the most-cited primary source on production
ML testing; the PDF's actual body text did not extract cleanly through this research's fetch tooling
(binary/font-encoded PDF, unreadable as prose — flagged rather than silently worked around). What is
independently confirmed from the abstract and secondary citations of it: the paper's 28 tests and
monitoring checks are written for teams that **own and can retrain the model** — its four
categories (data, model development, ML infrastructure, and monitoring) presuppose a training
pipeline and a deployment pipeline under the reader's control. SpendWise controls neither ML Kit's
nor Tesseract.js's training or release process, so this paper's tests target a different actor than
SpendWise; it corroborates the cd4ml framing (test what you own, monitor what you don't) without
adding a directly quotable ruling for this specific question. Treated as supporting, not
load-bearing.

### Tesseract's own maintainers, on testing Tesseract itself

Checked `tesseract-ocr.github.io/tessdoc/TestingTesseract.html` and its linked
`UNLV-Testing-of-Tesseract.html` page directly.

- Tesseract's own repo states plainly: "Currently there is no test suite for performance testing" —
  even the *engine's own maintainers* don't ship a maintained accuracy regression suite as a
  standard, current practice.
- The one accuracy methodology that does exist (UNLV, from the "Fourth Annual Test of OCR Accuracy")
  is a ground-truth-corpus-plus-scoring-script approach — bitonal TIFF scans matched against
  ground-truth text files, scored for character accuracy, word accuracy, and non-stopword accuracy —
  but it lives in the **engine's own** test infrastructure, run by Tesseract's maintainers to verify
  their own builds ("verify that their installation is correct"), not something every downstream
  application using Tesseract is expected to replicate.

This directly answers part of Q1: even the vendor whose accuracy is most in question here (ADR-0051
and the engine-choice research both flag Tesseract as materially more skew/contrast-sensitive than
ML Kit) does not treat exhaustive corpus-based accuracy testing as every consumer's job — it treats
it as the engine's own maintenance concern, imperfectly maintained even there.

### `receipt_recognition` (pub.dev / `github.com/manfredbork/receipt_recognition`) — real prior art, checked directly

This is the closest real prior art available: a shipping Flutter package that does exactly what
SpendWise's OCR pipeline does — takes `google_mlkit_text_recognition`'s output and runs
amount/name/date-shaped extraction logic on top of it. Its GitHub repo's `test/` directory was
listed directly via the GitHub API (`gh api repos/manfredbork/receipt_recognition/contents/test`),
not inferred from a README:

```
test/assets/ocr_fixtures.json
test/assets/test_receipts_optimizer.json
test/japanese_test.dart
test/ocr_fixture_test.dart
test/receipt_basic_test.dart
test/receipt_formatter_test.dart
test/receipt_normalizer_test.dart
test/receipt_optimizer_test.dart
test/receipt_parser_ja_test.dart
test/receipt_recognition_ja_test.dart
```

`test/ocr_fixture_test.dart` was fetched and read directly. Its pattern:

- Builds `_FakeRecognizedText` / `_FakeTextBlock` test doubles implementing ML Kit's own
  `RecognizedText`/`TextBlock` interfaces, populated from **hand-authored JSON fixtures**
  (`test/assets/ocr_fixtures.json`) — text lines and bounding boxes typed in directly, not sourced
  from an actual photographed receipt run through the real engine.
- Feeds the fake `RecognizedText` into `ReceiptTextProcessor.processText(...)`, then asserts the
  parsed `store`, `total`, `date`, line-item count, and per-item prices against expected values
  recorded alongside each fixture.
- There is **no image asset, snapshot image test, or real-engine-in-the-loop test**
  anywhere in this repository's `test/` directory. The entire suite — across normalization,
  optimization, and two locales (default and Japanese) — is fixture-driven against a hand-built
  stand-in for the engine's output shape.

This is materially significant: it is not a hypothetical "how should this be tested" answer, it is
what a real, published package with the identical architecture (recognizer → structured value type →
parsing heuristics) actually shipped and considered sufficient.

### SROIE and CORD — public receipt-OCR datasets, checked for fit

- **SROIE** (ICDAR 2019 Robust Reading Challenge): 626 training + 347 test scanned receipts, with
  company/address/total/date ground truth — closely matches SpendWise's own three extraction targets
  (name/amount/date) plus address, which is useful as a name-heuristic negative example (the spec's
  name heuristic explicitly must skip address-pattern lines). Distribution is ICDAR-challenge-gated
  (typically requires registration; research-oriented terms), and the receipts are scanned, not
  phone-photographed — they lack the skew/lighting/thermal-fade variation this app's actual capture
  path (a phone camera or gallery upload) produces. A scanned-document corpus under-represents
  exactly the failure modes ADR-0051's Tesseract preprocessing discussion and the Vision-vs-ML-Kit
  research (`docs/research/ocr-vision-vs-mlkit-ios-accuracy.md`) both flag as the real risk.
- **CORD** ("A Consolidated Receipt Dataset for Post-OCR Parsing", `github.com/clovaai/cord`,
  checked directly): CC BY 4.0 licensed — genuinely open, redistributable, attribution-only. 1,000
  Indonesian receipts (800/100/100 train/dev/test split), with box/text OCR annotations plus
  semantic parse labels (store, menu, total — again close to this app's own three fields). The
  README states some annotation *categories* (`store_info`, `payment_info`, `etc`) were stripped
  "due to Indonesian legal issues," which is evidence the dataset's own maintainers found a privacy
  concern worth redacting — but the README does not affirmatively state raw image pixels are
  scrubbed of incidental PII (card tail digits, loyalty numbers, addresses genuinely printed on the
  receipts photographed). This matters for whether CORD images could be redistributed inside
  SpendWise's own repo, separately from whether they're useful as a corpus at all. CORD receipts are
  also foreign-currency, Indonesian-language, camera-captured — a real image corpus, closer to
  SpendWise's actual input shape than SROIE's scans, but wrong locale/currency/keyword-set for the
  spec's English total/subtotal/currency keyword matching (`docs/specs/ocr-receipt-entry.md`'s
  amount heuristic keys on "TOTAL", "AMOUNT DUE", "GRAND TOTAL", "BALANCE DUE", "TOTAL DUE" —
  English-specific strings that a non-English corpus can't exercise).
- **Neither dataset's receipts are SpendWise's own receipts.** Both are third-party photographed/
  scanned documents from other people, already published research datasets under known licenses —
  not real receipts the app's own maintainer or users would be contributing. This sidesteps the
  "does my own grocery receipt with my own card's last 4 digits end up in a public git history"
  risk that using self-sourced sample receipts would create, but it does not fully sidestep it:
  redistributing *other people's* real financial documents, even under a research license, still
  means real people's real purchase history and (per CORD's own redaction note) potentially-personal
  fields sit in the repo's git history forever once committed, regardless of upstream license terms
  permitting reuse.

### Synthetic receipt generation and PII-safe test data — general practice

Search results converged on a consistent industry pattern, not vendor-specific: synthetic
test-fixture generators for financial documents (card numbers, SSNs, receipts) commonly use
Luhn-valid-but-fake card numbers and placeholder names specifically so "zero real PII" ships in a
test corpus, and the explicit reason given is that even sample/test data resembling real financial
documents is treated as a handling risk if it's *actually* real. This matches the general secure
test-data guidance pattern (avoid real customer data in test fixtures; prefer synthetic data
engineered to look realistic without being real) rather than any OCR-specific practice — it is the
same rule this app already applies to money-domain testing in general.

## Reasoning

Putting the sources together:

- **Q1 — is engine accuracy this app's test scope?** No source found — not Fowler's own framework,
  not the ML Test Score paper's scope, not even Tesseract's own maintainers testing Tesseract itself
  — treats "build and maintain a corpus-based accuracy regression suite against a vendor's own
  model" as the standard job of a downstream *consumer* of that model. It's the model owner's job
  (cd4ml), and even the model owner (Tesseract) does it loosely ("currently no test suite for
  performance testing"). SpendWise cannot retrain, gate, or influence ML Kit's or Tesseract.js's
  releases; a SpendWise-side accuracy regression suite would only ever tell SpendWise "the vendor's
  model changed," which SpendWise can't act on except by noticing and adjusting its own heuristics —
  which is Q2's territory, not Q1's.
- **Q2 — are synthetic `RecognizedText` fixtures sufficient for the heuristics?** Yes, for what they
  test, and this isn't a guess: `receipt_recognition` is a real, shipping package with the identical
  architecture (ML Kit → structured value type → amount/name/date-style parsing) and its entire
  committed test suite is fixture-driven against hand-built stand-ins for `RecognizedText`, with zero
  image-based tests. This is direct architectural precedent, not an analogy. `RecognizedText`
  (ADR-0052) exists precisely so the heuristics can be exercised without depending on which engine
  produced the lines — that's the seam's whole purpose, and fixtures are the natural way to drive a
  seam. What fixtures **cannot** catch, structurally: an engine misreading a character (e.g. "O" for
  "0" corrupting an amount), an engine failing to segment a line the spec's heuristics assume is one
  line, or an engine's bbox/height geometry behaving differently than assumed (this is exactly the
  kind of gap `docs/research/ocr-vision-vs-mlkit-ios-accuracy.md` already flagged as unanswered by
  documentation alone). Those are real gaps, but they are gaps in "does the recognizer work," which
  is Q1's territory (vendor-trusted) crossed with a much narrower, cheaper check: does *this app's*
  mapping from each engine's native result into `RecognizedText` preserve the text and geometry the
  engine actually returned. That's a mapping-correctness check, not an accuracy corpus.
- **Q3 — is a corpus warranted, and if so what?** A full accuracy-benchmarking corpus (SROIE/CORD
  scale, scored character/word accuracy) is not warranted, per Q1's reasoning — that would be
  testing the vendor, not this app. But a **small, targeted, manually-verified real-image smoke
  set** is still worth having, for a narrower purpose than "measure OCR accuracy": proving the
  `MlKitReceiptRecognizer` / `TesseractReceiptRecognizer` mapping into `RecognizedText` actually
  round-trips real engine output into the shape the heuristics expect, on each platform, including
  real bbox/height geometry — not a fixture that assumes the shape is right. This is a mapping test,
  not an accuracy test, and it needs only a handful of images, not a labeled dataset.
- **Q4 — prior art.** `receipt_recognition` answers this directly: real Flutter projects layering
  parsing on a vendor OCR engine draw the line exactly where Fowler's framework predicts — fixtures
  for the parsing logic, nothing for the engine itself. No counter-example (a Flutter/mobile project
  in this space maintaining its own accuracy corpus against ML Kit or Tesseract) turned up in this
  research despite specific search for one.

## Recommendation

**(b), narrowly scoped — not a full accuracy corpus, but a small real-image mapping-smoke corpus,
plus fixture-based heuristic tests as the primary suite.**

Concretely, for SpendWise:

1. **Primary suite: unit-test the amount/name/date heuristics against hand-built `RecognizedText`
   fixtures**, living wherever `packages/domain` (or `app/`, per ADR-0052's placement note) puts the
   heuristic code's own test directory, following the existing repo convention of colocated `_test.dart`
   files. Cover every branch the spec (`docs/specs/ocr-receipt-entry.md`) actually enumerates as a
   scenario — subtotal-vs-total disambiguation, the day/month->12 rule, both-ambiguous locale
   fallback, no-date-found default, the 3-line-name-scan-depth and 3-consecutive-skip rules, missing
   height/geometry degrading to first-line — since those are the branches this app's own logic
   owns and can regress. This mirrors exactly what `receipt_recognition`'s shipped suite does, and
   what Fowler's framework calls testing what you own.
2. **A small real-image corpus — roughly 8-12 photos, not hundreds — used only to prove each
   `ReceiptTextRecognizer` implementation's mapping into `RecognizedText` is honest**, not to score
   OCR accuracy. Per platform/engine (ML Kit on a real device or emulator, Tesseract.js on web, later
   Vision), run one or two receipts through the real engine and assert the resulting `RecognizedText`
   has non-empty lines, plausible geometry (height/bbox present and ordered top-to-bottom), and that
   feeding that real `RecognizedText` through the same heuristics produces a sane (not necessarily
   perfect) result on at least the obvious case. A failure here means "our mapping code is wrong,"
   which this app can and must fix; it is not a claim about the vendor engine's character-level
   accuracy.
   - **Source**: self-generated, synthetic-style receipts, not real personal receipts and not a
     redistributed third-party dataset. Use a simple receipt-template generator (plain HTML/CSS or a
     small script rendering a monospace "thermal receipt" layout, printed to image) with invented
     store names, invented totals, and either omitted or clearly-fake card/loyalty numbers (e.g.
     `**** **** **** 0000`, matching the Luhn-safe-fake-data convention the general PII-test-data
     practice above already establishes) — this sidesteps both the "my own card's last 4 digits in
     git history forever" risk and the "redistributing someone else's real purchase history under a
     research license" ambiguity CORD's own redaction note leaves open. A handful of these images,
     deliberately varied on the axes the spec's heuristics actually branch on — a SUBTOTAL-and-TOTAL
     pair, a receipt with no keyword match (forcing the last-currency-number fallback), an
     ambiguous-date receipt, a no-date receipt, a receipt whose first few lines are address/phone/URL
     boilerplate the name heuristic must skip — covers what the spec's own scenarios need
     mapping-level proof for, without needing thermal-degradation/skew fidelity a synthetic image
     can't reproduce anyway (and which, per Q1, is the vendor's problem, not this app's to
     benchmark).
   - **Where it lives**: Store the fixtures in `app/test/ocr/fixtures/`, colocated with the
     `ReceiptTextRecognizer` implementation tests. Commit the small PNG/JPEG set alongside a short
     note in the directory or test file stating that the images are synthetic and contain no real
     personal or financial data. This lets future contributors regenerate or extend the set.
   - **Not SROIE, not CORD**: both were checked and both are real, accessible, real-licensed
     datasets — CORD's CC BY 4.0 license in particular would permit redistribution — but neither is
     the right fit here. They're the wrong language/currency/keyword-set (CORD) or scanned rather
     than phone-photographed and access-gated (SROIE), and both carry other real people's
     receipts into this repo's permanent git history for a purpose (mapping-correctness proof) that
     a handful of invented, purpose-built synthetic images already covers more precisely and more
     cheaply.
3. **Engine accuracy itself — character-level or word-level OCR correctness — is accepted as
   vendor-trusted and explicitly out of SpendWise's test scope**, consistent with every source
   checked (Fowler's cd4ml contract-test framing, the ML Test Score paper's model-owner scoping,
   and Tesseract's own maintainers not maintaining a performance suite for their own engine). If a
   real accuracy problem surfaces in practice (a user reports consistently bad extraction on one
   platform), the right response is a targeted investigation against that specific failure — closer
   to what `docs/research/ocr-vision-vs-mlkit-ios-accuracy.md` already scoped as a hands-on device
   test plan for issue #8 — not a standing corpus maintained speculatively ahead of evidence of a
   problem.
4. **This validation is per-implementation for the mapping smoke test (step 2), and shared for the
   heuristics (step 1)** — matching ADR-0052's own seam: each `ReceiptTextRecognizer` implementation
   gets its own small real-image check that its mapping is honest, but the amount/name/date logic
   itself is tested exactly once, against the shared `RecognizedText` shape, regardless of which
   engine is expected to produce it.

This resolves issue #9 without deferring it further: no large corpus, no per-engine accuracy
scoring, no redistributed third-party receipt dataset — a fixture-first heuristic suite plus a
small, synthetic, purpose-built real-image set that exists only to catch mapping bugs, not to
benchmark vendors.
