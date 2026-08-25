# ocr-receipt-entry Specification

## Purpose
Defines how a photographed or uploaded receipt becomes a pre-filled draft in the existing
`entry-form` (see `entry-form.md`): the entry point, the on-device extraction pipeline, the fields
it may set, and how every non-happy-path case resolves to a form the user can still fill in by
hand.

## Requirements

### Requirement: Entry point

The new-entry form SHALL show a "Scan receipt" and an "Upload photo" action at its top, above the
manual fields, both reachable in a single tap from the form. Neither action SHALL sit behind an
intermediate choice sheet or menu.

"Scan receipt" SHALL be offered only on iOS and Android. "Upload photo" SHALL be offered on every
platform, including web.

A setting SHALL control whether this strip is shown at all, defaulting to shown. Hiding it SHALL
leave the new-entry form otherwise unchanged.

#### Scenario: Strip hidden by setting

- **WHEN** the user has turned the scan/upload strip off in settings
- **THEN** the new-entry form opens with only its manual fields, identical to a build without this
  capability

#### Scenario: Upload available on web

- **WHEN** the app is running on web
- **THEN** "Upload photo" is offered and "Scan receipt" is not

### Requirement: Permission requests are never speculative

Camera access and photo-library access SHALL be requested only at the moment the user taps "Scan
receipt" or "Upload photo" respectively, never in advance of that tap and never both at once.

A denied permission SHALL show a message and leave the user on the new-entry form with its manual
fields still usable. It SHALL NOT block entry creation, and SHALL NOT deep-link to the OS settings
screen.

#### Scenario: Camera denied falls back to manual entry

- **WHEN** the user taps "Scan receipt" and camera access is denied
- **THEN** a message is shown and the new-entry form remains open and fillable by hand

### Requirement: On-device extraction only

Receipt text recognition and field extraction SHALL both run entirely on-device. No image,
recognized text, or field-extraction prompt/response SHALL be sent to a network endpoint.

The recognizer SHALL be `google_mlkit_text_recognition` on iOS and Android, and a directly-wired
Tesseract.js integration on web (see ADR-0051 for why this is a per-platform split rather than one
engine, and why on-device rather than a cloud OCR or vision-LLM API; see ADR-0052 for the
`ReceiptTextRecognizer` seam that keeps the field-extraction logic below decoupled from which
engine is behind it, so the engine can be swapped per platform without touching this section). The
on-device model used for amount/name extraction below (see the Field extraction requirement) is
likewise a local, on-device model, never a cloud/network call.

The Tesseract.js integration SHALL request `{ blocks: true }` output so per-line geometry
(`rowAttributes.rowHeight`, falling back to `bbox.y1 - bbox.y0`) is available to whichever
extraction path runs below; omitting this flag SHALL NOT be treated as an error, since every
extraction path already degrades gracefully when line geometry is unavailable.

The recognized image SHALL be discarded immediately once the three fields below have been
extracted, along with any intermediate raw recognized text. Neither SHALL be retained, logged, or
exposed through a "view raw scan" affordance.

#### Scenario: No network call during recognition

- **WHEN** a receipt image is processed, on any platform
- **THEN** no request is made to any network endpoint as part of extracting its fields

### Requirement: Field extraction

Extraction SHALL attempt to fill exactly three `entry-form` fields — amount, name, date — and
SHALL NOT attempt to infer kind, source, destination, category, or the analysis toggle, since a
receipt does not print any of those and they remain user-chosen.

**Amount and name:** both SHALL be identified by an on-device model rather than a keyword or
pattern heuristic, given the recognized text in reading order (top to bottom, left to right within
a row). Each platform runs its own model, behind the same `FieldExtractor` contract, with no shared
fallback engine between platforms:

- **Android**: Gemini Nano, via Android's ML Kit GenAI Prompt API (see ADR-0053).
- **iOS**: Apple's Foundation Models framework, iOS 26+ on Apple-Intelligence-eligible devices (see
  ADR-0055).
- **Web**: Chrome's built-in Prompt API (`LanguageModel`), Chrome 148+ (see ADR-0054).

The amount prompt SHALL name and exclude near-total decoys ("Cash", "Change Due", "Tendered",
"Subtotal", "Tax") and prioritize a "Total"/"Grand Total"/"Amount Due" label — identical wording on
every platform, since the extraction task doesn't vary with the engine. The model's answer SHALL be
parsed into a `Decimal`, never a `double`, before being set on the form; a response that doesn't
parse as a number SHALL be treated as not found. This choice follows a same-corpus prototype
comparison (issue #18) that found a fixed heuristic reliably mis-picks the total on decimal-dropped
OCR output and can't distinguish a merchant name from an address or boilerplate line the way a model
reading for meaning can, while the same comparison found the reverse true for the date field below,
which stays heuristic-only.

Where no eligible on-device model is available for the current platform or device — pre-iOS 26, a
non-Apple-Intelligence-eligible iOS device, a non-Chrome or non-eligible browser, or an Android
device that fails AICore eligibility — both the amount and the name fields SHALL be left blank, the
same as any other field this section doesn't resolve, rather than falling back to a keyword or
pattern heuristic.

**Date** SHALL be identified from the first date-shaped text found. Where the two numeric
candidates of a date are ambiguous between day and month, a candidate greater than 12 SHALL be
treated as unambiguously the day, regardless of device locale. Where both candidates are 12 or
less, the device locale's date order SHALL decide. Where no date-shaped text is found at all, the
date SHALL default to the current date — the one field permitted to fall back to a guess rather
than blank, since an approximately-right date costs less correction than an empty one.

Any field this section does not resolve SHALL be left blank on the form rather than filled with a
guess, except date's today-default above.

#### Scenario: Subtotal is not mistaken for total

- **WHEN** a receipt's recognized text contains both a "SUBTOTAL" line and a "TOTAL" line, and an
  eligible on-device model extracted the amount
- **THEN** the amount extracted is the value on the "TOTAL" line, not the "SUBTOTAL" line

#### Scenario: A number over 12 resolves the date without consulting locale

- **WHEN** a recognized date reads "13/04/25"
- **THEN** 13 is treated as the day and 04 as the month, regardless of device locale

#### Scenario: Both numbers ambiguous falls back to locale

- **WHEN** a recognized date reads "03/04/25", where neither number exceeds 12
- **THEN** the device's locale date order decides which number is the day and which is the month

#### Scenario: No date found defaults to today

- **WHEN** no date-shaped text is found anywhere in the recognized receipt
- **THEN** the form's date field defaults to the current date rather than being left blank

#### Scenario: No eligible on-device model leaves amount and name blank

- **WHEN** no eligible on-device model is available for the current platform or device
- **THEN** the amount and name fields are left blank rather than filled by a keyword or pattern
  heuristic

#### Scenario: Model finds no merchant name

- **WHEN** an eligible on-device model runs but finds no text it identifies as a merchant name
- **THEN** the name field is left blank rather than filled with a low-confidence guess

### Requirement: Every non-extraction outcome lands on the same draft form

A corrupt or unreadable uploaded file, an image with no recognizable text, and a successfully
processed image whose fields all fail to extract SHALL all produce the same outcome: the new-entry
form opens with whatever fields (zero, some, or all three) were actually resolved. None of these
cases SHALL show a distinct error state, an error dialog, or any UI different from a normal draft
with fewer fields filled in.

Nothing extracted by this capability SHALL ever be saved without the user's own confirmation on the
form; this capability SHALL only ever pre-fill the form defined in `entry-form.md`, never call its
save path directly.

A single loading indicator SHALL be shown during processing, on every platform, regardless of that
platform's typical processing speed.

#### Scenario: Unreadable upload produces a blank draft, not an error

- **WHEN** the user uploads a file that cannot be decoded as an image
- **THEN** the new-entry form opens with all three fields blank, with no error dialog shown

#### Scenario: Partial extraction is shown as a partial draft

- **WHEN** only the amount is confidently extracted from a receipt
- **THEN** the new-entry form opens with the amount field filled and name/date left at their
  defaults, with no indication that this differs from any other partially-filled draft
