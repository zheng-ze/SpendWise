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

Receipt text recognition SHALL run entirely on-device. No image or recognized text SHALL be sent
to a network endpoint.

The recognizer SHALL be `google_mlkit_text_recognition` on iOS and Android, and a directly-wired
Tesseract.js integration on web (see ADR-0051 for why this is a per-platform split rather than one
engine, and why on-device rather than a cloud OCR or vision-LLM API).

The Tesseract.js integration SHALL request `{ blocks: true }` output so per-line geometry
(`rowAttributes.rowHeight`, falling back to `bbox.y1 - bbox.y0`) is available to the merchant-name
heuristic below; omitting this flag SHALL NOT be treated as an error, since the heuristic already
degrades gracefully when line geometry is unavailable.

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

**Amount** SHALL be identified by matching a line against a keyword synonym set indicating a grand
total ("TOTAL", "AMOUNT DUE", "GRAND TOTAL", "BALANCE DUE", "TOTAL DUE"), explicitly excluding any
line matching "SUBTOTAL" or a tax-labeled line as a false match for that set. If no keyword match is
found, the last currency-formatted number on the receipt SHALL be used instead. The matched value
SHALL be parsed into a `Decimal`, never a `double`, before being set on the form.

**Name** SHALL be identified by scanning at most the first 5 recognized lines (or the top ~20-25%
of image height, where geometry is available), skipping any line matching an address pattern, a
phone-number pattern, boilerplate keywords ("STORE #", "REG", "TERM", "THANK YOU", "RECEIPT",
"INVOICE"), a URL/email/@-handle pattern, or a greeting/banner line ("WELCOME TO", "CUSTOMER COPY",
"DUPLICATE"). A surviving line SHALL additionally satisfy: 3-35 characters, at most 6 words, under
20-30% digit density, and at least one alphabetic character. Where per-line height is available
(see the Tesseract.js requirement above; always available from `google_mlkit_text_recognition`),
the tallest surviving line SHALL be preferred over the first; where height is unavailable, the
first surviving line SHALL be used. The name SHALL be left blank if no line survives within the
scan depth, or if 3 or more consecutive lines were skipped before a candidate appeared.

**Date** SHALL be identified from the first date-shaped text found. Where the two numeric
candidates of a date are ambiguous between day and month, a candidate greater than 12 SHALL be
treated as unambiguously the day, regardless of device locale. Where both candidates are 12 or
less, the device locale's date order SHALL decide. Where no date-shaped text is found at all, the
date SHALL default to the current date — the one field permitted to fall back to a guess rather
than blank, since an approximately-right date costs less correction than an empty one.

Any field this section does not resolve SHALL be left blank on the form rather than filled with a
guess, except date's today-default above.

#### Scenario: Subtotal is not mistaken for total

- **WHEN** a receipt's recognized text contains both a "SUBTOTAL" line and a "TOTAL" line
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

#### Scenario: Merchant name heuristic finds nothing usable

- **WHEN** every one of the first 5 recognized lines is skipped by a pattern filter, or 3 or more
  consecutive lines are skipped before any candidate survives
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
