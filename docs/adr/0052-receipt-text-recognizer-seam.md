# 52. A general-purpose `packages/ocr/` package decouples receipt extraction from the OCR engine

## Status

Accepted

## Context

ADR-0051 already commits this app to two OCR engines today (`google_mlkit_text_recognition` on
iOS/Android, a hand-wired Tesseract.js on web) and issue #8 adds a third on the horizon: Apple
Vision, as an experimental iOS path the user wants to build for its own learning value, switchable
in later if it proves more accurate. That's three engines with no shared package, each with its own
call shape (a Flutter plugin call, raw JS interop, and eventually a hand-written platform channel).

The field-extraction heuristics in `docs/specs/ocr-receipt-entry.md` (amount, name, date) are
already written engine-agnostically: they operate on recognized lines with optional per-line height
(`rowAttributes.rowHeight` / `bbox.y1 - bbox.y0` for Tesseract.js; ML Kit exposes equivalent line
geometry). Nothing about that logic should change when the engine underneath it changes.

## Decision

Introduce a general-purpose text-recognition abstraction, `TextRecognizer`, with a single method
that takes an image and returns a `RecognizedText` — an engine-agnostic value type: a list of
lines, each with its text and optional bounding-box geometry, confidence, and recognized
languages. Nothing about `TextRecognizer` or `RecognizedText` mentions receipts, amounts,
merchants, or dates; it is exactly as generic as "recognize the text in this image," and exposes
what its engines actually report rather than only what this app's current receipt heuristics need.
Confidence and language availability differ sharply by engine — confirmed by primary-source
research (`docs/research/ocr-confidence-language-fields.md`), not assumed — and `docs/modules/receipt_ocr.md`
§3 has the full per-engine detail; in short, confidence is usable on all three engines with a
documented ML-Kit-iOS gap, while output-side language identification is confirmed only on ML Kit
(and only reliably on Android), never on Tesseract.js or Vision.

Three implementations, each doing nothing but calling its engine and mapping the result into
`RecognizedText`:

- `MlKitTextRecognizer` — iOS and Android, wraps `google_mlkit_text_recognition`.
- `TesseractTextRecognizer` — web, wraps the hand-wired Tesseract.js integration from ADR-0051.
- `VisionTextRecognizer` — iOS experimental path from issue #8, once built.

The interface, its value types, and all three implementations live together in one new package,
`packages/ocr/`, sibling to `packages/domain/`. This means relaxing, precisely, one constraint:
this repo's rule is no longer "only `app/` may depend on Flutter" but "`packages/domain/` may
never depend on Flutter" — a second local package, `packages/ocr/`, is now also allowed to, because
its entire reason to exist is wrapping three Flutter-plugin/`dart:js`-interop OCR engines behind
one interface. `packages/domain/`'s own constraint is unchanged and unrelaxed: it stays pure Dart,
exactly as before.

`packages/ocr/` does not live inside `packages/domain/` and does not depend on it, and the
receipt-specific field-extraction heuristics that consume `RecognizedText` do not live in
`packages/ocr/` either — they live in `app/`, alongside the UI hook point that calls this package.
`packages/domain/` models `LedgerState` and accounting — the financial world this app tracks — and
nothing about text recognition, receipts, or OCR engines belongs to that vocabulary. This tool
exists to help populate the domain from the app layer, the same relationship a manually typed entry
already has to `LedgerState`; it is not itself part of the domain, and folding it into
`packages/domain/` would blur a boundary this repo depends on staying sharp regardless of which
packages happen to share a language.

## Consequences

Swapping which engine runs on a given platform, including resolving issue #8's Vision-vs-ML-Kit
question later, becomes choosing which `packages/ocr/` `TextRecognizer` implementation gets
constructed at the call site in `app/`. The field-extraction heuristics and the rest of the
pipeline never change.

`packages/ocr/` is a real dependency this repo now carries in one place instead of three:
`google_mlkit_text_recognition`, the Tesseract.js interop, and eventually the Vision platform
channel all live behind its one interface rather than scattered through `app/lib`. This is accepted
because all three engines are already committed work (ADR-0051, issue #8), not speculative, and
because `packages/ocr/` has exactly one consumer — this app — so nothing about it needs hardening
for external use; see `docs/modules/receipt_ocr.md` §9.

`app/` now depends on two local packages by path, `packages/domain/` and `packages/ocr/`, instead
of one. `packages/ocr/` depends on neither `app/` nor `packages/domain/`, so this does not create a
path for OCR concerns to reach `LedgerState` except through the app layer explicitly constructing an
`Entry` from the extracted values, exactly as a hand-typed entry already does.

**Revision notes** (both from before any code was written):

1. This ADR first placed the interface and value type in `app/` alongside the engine
   implementations, and floated `packages/domain/` as a possible home for the field-extraction
   heuristics on the reasoning that both are pure Dart. Corrected to a dedicated pure-Dart
   `packages/ocr/`, separate from `packages/domain/`, so OCR vocabulary never mixes with accounting
   vocabulary and the heuristics get a testable pure-Dart home without either package depending on
   `app/`.
2. That correction then kept `packages/ocr/` pure Dart and moved the three engine implementations
   back into `app/`, on the reasoning that only `packages/domain/` needed a hard Flutter-free rule.
   Corrected again, to the shape recorded above: the engines move into `packages/ocr/` alongside the
   interface, making it a genuinely general-purpose, reusable text-recognition package rather than
   a Flutter-free shell whose only implementations live elsewhere. `packages/domain/`'s own
   pure-Dart constraint never moved through either revision.

See `docs/modules/receipt_ocr.md` for the full implementation-level detail.
