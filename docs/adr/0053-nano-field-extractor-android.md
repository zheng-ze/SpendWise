# 53. Gemini Nano, no fallback engine, replaces the amount/name heuristics on Android

## Status

Accepted

## Context

Issue #18's resolution settled that the amount and merchant-name fields extract better with an
on-device model reading the receipt's text than with the fixed keyword/pattern heuristics that
shipped first (`docs/specs/ocr-receipt-entry.md`'s prior wording, still correct for the date
field, which stays heuristic). That issue explicitly deferred the production model/runtime choice
to a follow-on ticket, #21, which is what this ADR records.

#21's own body first framed the choice as a primary/fallback pair per platform: Gemini Nano on
Android, Apple Foundation Models on iOS, each with `flutter_gemma` (Gemma running through
MediaPipe) as a shared fallback for a device that fails its platform's primary eligibility check.
Three follow-up comments on the issue walked that back in stages: first gating the Gemma fallback
on an 8GB RAM floor (`flutter_gemma`'s own documented minimum for its smallest text-only variant),
then dropping Gemma entirely as unneeded complexity - an extra runtime engine, an extra dependency,
an extra hardware check - once each platform has its own native on-device model option. The
comment thread is the authoritative record of that walk-back; this ADR exists so the final shape
doesn't only live in an issue thread.

iOS (#23) and web (#24) are separate, blocked tickets, not decided here. This ADR covers the
Android path only.

## Decision

**Chain: Gemini Nano, if the device passes AICore eligibility, else nothing.** No fallback engine.
A device that isn't eligible gets `null` from `field_extractor_selection.dart`'s
`selectFieldExtractor()`, and the amount/name fields stay blank, the same tier
`receipt_recognizer_selection.dart`'s `selectRecognizer()` already uses for the web platform having
no OCR engine yet. `field_extractor_selection.dart` treats `FeatureStatus.downloadable` and
`.downloading` the same as `.unavailable`: this ticket does not build a download-and-wait flow, so
"eligible but not yet downloaded" is not yet usable and gets the same `null` as genuinely
ineligible.

**No Flutter plugin: a hand-rolled platform channel straight to Google's Kotlin GenAI Prompt SDK.**
The pub.dev plugin considered first, `google_mlkit_genai_prompt`, turned out to pin an old SDK
version and ship an unfinished `runInference` (its own source returns an explicit "not yet fully
implemented" error), which confirmed the concern that motivated avoiding a third-party wrapper here
at all. The final shape instead calls `com.google.mlkit:genai-prompt` (Google's own Kotlin SDK,
`GenerativeModel`/`Generation.getClient` API) directly from this app's own Kotlin, through a single
`MethodChannel` (`"spendwise/nano_field_extractor"`, methods `checkFeatureStatus`/`runInference`)
that `nano_channel.dart` calls and `NanoFieldExtractorChannel.kt` answers. Every call site that
touches an SDK type first checks `Build.VERSION.SDK_INT` against the SDK's API 26 floor; this app's
own `minSdk` stays below that floor on purpose; see Consequences.

**Seam: `FieldExtractor`, sibling to `TextRecognizer` (ADR-0052), not an extension of it.**
`extractName(String)`/`extractAmount(String)` take the recognized receipt's reading-order text
(`line_rows.dart`'s `toReadingOrderText`) and return the field or `null`, mirroring
`TextRecognizer.recognize`'s contract shape: throws a typed failure (`FieldExtractionFailure`) on a
real engine error, never returns an empty/wrong result to signal "not found." Two methods, not one
combined call, because the two fields are independent extractions with no shared-session
constraint forcing them together (see the session note below) and each has its own prompt tuned to
its own failure mode (issue #18's amount-decoy-keyword finding doesn't apply to name).

**Session lifecycle: a fresh prompt per field, same rule as the prototype, different reason.**
Issue #18's prototype reused one MediaPipe/Gemma inference session across the sequential per-field
questions and crashed the native engine (SIGABRT). ML Kit's GenAI Prompt SDK is a different engine
with no equivalent constraint documented anywhere checked - so there is no confirmed reason to
expect the same crash. `NanoPromptSdk` (Kotlin) and `NanoFieldExtractor` (Dart) still open a fresh
client per call and close it once that call finishes, rather than betting on undocumented reuse
safety, since nothing in the SDK's own docs promises reuse is safe either. This is a conservative
default, not a proven requirement; revisit if per-field latency from repeated session setup becomes
a measured problem.

**Prompts:** production text for both fields lives in `nano_field_extractor.dart`, informed by
issue #18's finding but not copied from it (the prototype's exact prompt never entered this repo).
The amount prompt names and excludes near-total decoys ("Cash", "Change Due", "Tendered",
"Subtotal", "Tax") and prioritizes "Total"/"Grand Total"/"Amount Due" labels, per that finding. The
name prompt asks plainly for the merchant name, per the same finding's note that name extraction
needed no special-casing. Both prompts ask for a fixed "not found" token (`"NONE"`) rather than
free-form negative phrasing, so a miss is a string compare instead of another parsing pass.

## Consequences

The amount/name heuristics (`amount_extraction.dart`, `name_extraction.dart`) are deleted, not kept
as a fallback tier - a device with no eligible model gets blank fields, identical to today's
recognition-failure path, never a heuristic guess. `date_extraction.dart` is unchanged; issue #18
found the heuristic outright better for that field; this ADR does not revisit that finding.

This app's own `minSdk` is left below the GenAI Prompt SDK's API 26 floor, deliberately: Nano is a
null-gated feature, not an install-time requirement, so a device below that floor still installs and
runs the app with the field-extraction feature reporting unavailable, same as any other ineligible
device. The SDK's AAR declares its own `minSdkVersion 26` in its manifest, which would otherwise fail
this app's manifest merge; `AndroidManifest.xml` overrides that check for exactly those two ML Kit
GenAI packages via `tools:overrideLibrary`, since the runtime `Build.VERSION.SDK_INT` guards already
in place are what actually keeps an old device from reaching the SDK, not the merger.

This ADR does not decide iOS (#23) or web (#24). Each gets its own primary engine and its own ADR
when built; neither reuses `NanoFieldExtractor`, though both are expected to implement the same
`FieldExtractor` seam this ADR introduces, per #21/#23/#24's shared-seam framing.

If a later ticket needs a fallback tier after all (for example, if Nano's real-world eligibility
rate proves too low), that is a new decision, not a reopening of this one - this ADR's whole point
is that the fallback chain was deliberately walked back to nothing, not left off by oversight.
