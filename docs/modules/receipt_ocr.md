# Module spec — receipt OCR capture

**Scope:** scanning a photographed or picked receipt image, extracting a structured prefill for
a new `Entry` (name, amount, date), and handing that prefill to the existing entry form for
review before anything is saved.

**Status:** design spec, pre-implementation. No Swift precursor exists. Every rule below is the
intended behavior for a first implementation, to be verified by its own test suite once built.

**Relationship to the domain layer:** this module never writes to `LedgerState` directly. It
produces prefill values that are handed to the same entry-creation path a manually typed entry
already goes through (`signedEntryForSave` in `entry_form_logic.dart`), so every ledger
invariant and validation rule that applies to a manually entered `Entry` applies here unchanged.

---

## 1. Purpose

Let the user photograph or pick a receipt image and have the entry form's name, amount, and date
fields prefilled from it, cutting typing for the common case, while never saving anything to the
ledger without the user reviewing the result first.

## 2. Stack choice: on-device text recognition, not a custom model

Text recognition from a photo is a commoditized problem. Google's own on-device ML Kit text
recognizer is more accurate than a model built for this feature in a weekend could be, and
training one would spend engineering effort on a problem that is already solved, instead of on
the problem this feature actually needs solved: turning an unstructured wall of recognized text
into three specific structured fields. `google_mlkit_text_recognition` is the intended
dependency.

Running recognition on-device, rather than through a cloud API, also matches this app's existing
architecture: the app is fully local and offline-first, with no backend for any other feature
(persistence is SwiftData/Drift-backed, not server-synced). A cloud OCR call would be the first
network dependency the app has, for a feature that does not need one.

## 3. Pipeline

Given a picked or captured image, in order:

1. **Recognize.** Run the on-device text recognizer, producing a set of recognized text
   blocks/lines in reading order.
2. **Extract amount.** Scan every line for a currency-shaped token (a pattern like `\d+\.\d{2}`).
   Among all matches, prefer the one on a line adjacent to a total-like keyword
   ("total", "amount due", "subtotal") over the first or largest match found in isolation. A
   receipt typically contains several currency-shaped numbers, line items, tax, subtotal, and
   the actual total is usually identified by its keyword, not by its position in the text or by
   being the largest number present.
3. **Extract merchant name.** Take the first non-empty, non-numeric line as the candidate entry
   name. Printed receipts consistently put the merchant name in the first one to three lines,
   before any line items begin.
4. **Extract date.** Scan for common date-format patterns. When more than one date-shaped match
   exists, prefer the one adjacent to a "date" or "time" keyword, a receipt can show both a print
   timestamp and an unrelated due date, and the two should not be treated as equally likely
   candidates.

## 4. Failure handling

Extraction failure is surfaced, never silently guessed past:

- If no currency-shaped token is found anywhere in the recognized text, the amount field is left
  empty rather than filled with an unrelated number. An empty required field blocks save the same
  way it already does for a manually started entry, per `canSaveEntryForm`.
- If the recognized text has too few lines, or contains no currency-shaped token at all, the
  image is treated as unreadable: show a message that the receipt could not be read clearly and
  ask the user to enter the details manually, rather than prefilling the form with a low-quality
  guess.

This mirrors the category classifier's confidence gate (`category_classifier.md` §4): both
modules are built on the same principle, when the evidence is not good enough to support a
specific answer, say so and step back, rather than committing to a guess that looks confident but
is not.

## 5. Integration with the category classifier

The extracted merchant name (§3.3) is placed into the entry form's name field through the same
path a manually typed name would take. This means the category classifier's `predict` call
(`category_classifier.md` §2.4) runs against OCR-derived text exactly as it would against
hand-typed text, with no special-casing, and the user accepting or correcting the resulting
suggestion is a normal `observe` training signal (`category_classifier.md` §3) regardless of
where the name came from. A receipt for a merchant the classifier has already learned produces a
category suggestion immediately, without the user having to type anything.

## 6. UI hook point

A new entry point, for example a camera or gallery picker action on the transactions screen,
runs the pipeline in §3 and then opens the existing `showEntryFormSheet` with the extracted name,
amount, and date passed as initial values. `EntryForm` gains optional initial-value parameters
for this purpose, this is an additive change to its constructor, not a redesign of the form
itself. The form behaves exactly as it does for a new entry started from scratch: every field
stays editable, and nothing is written to the ledger until the user saves, going through
`signedEntryForSave` and `canSaveEntryForm` unchanged.

## 7. Non-goals

- No line-item-level extraction. The feature reads a single total, a single merchant name, and a
  single date, it does not itemize individual receipt lines into separate entries.
- No cloud OCR fallback. Recognition is on-device only, consistent with the app's offline-first
  architecture, a receipt that the on-device recognizer cannot read falls back to manual entry
  per §4, not to a network call.
- No custom-trained recognition model, see §2.
