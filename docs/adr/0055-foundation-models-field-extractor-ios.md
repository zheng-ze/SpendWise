# 55. Apple's Foundation Models framework, no fallback engine, is iOS's `FieldExtractor`

## Status

Accepted

## Context

ADR-0053 settled Android's field-extraction engine (Gemini Nano via ML Kit's GenAI Prompt SDK) and
explicitly left iOS (#23) and web (#24) as separate tickets, each expected to implement the same
`FieldExtractor` seam without reusing Android's implementation. This ADR is iOS's half of that,
tracked as issue #23.

iOS ships its own on-device path for the same job: Apple's Foundation Models framework, built
directly into the OS from iOS 26 onward on Apple-Intelligence-eligible hardware, backed by Apple's
own on-device model with no bundled model file and no download step to wait on. The framework's
entry points are `SystemLanguageModel` (an availability check) and `LanguageModelSession` (a
prompt/response call), both under `import FoundationModels`. Confirmed against a real, working
third-party Flutter plugin's Swift source
(`github.com/dmakwt/flutter_foundation_models_framework`) and multiple independent Swift code
samples, since Apple's own developer-documentation pages did not fetch as readable text during this
research.

An earlier version of #21/#23's shared framing proposed `flutter_gemma` (Gemma through MediaPipe) as
a cross-platform fallback tier for a device that fails its platform's primary eligibility check.
ADR-0053 records that plan being walked back once each platform turned out to have its own native
on-device model option; this ADR does not reopen that walk-back, it only confirms iOS follows the
same no-fallback shape Android already shipped.

## Decision

**Chain: Foundation Models, if the device passes eligibility, else nothing.** No fallback engine,
same shape as ADR-0053's Android chain. A device that isn't eligible — pre-iOS 26, or iOS 26 without
Apple Intelligence enabled, or hardware below Apple Intelligence's own floor — gets `null` from
`field_extractor_selection.dart`'s `selectFieldExtractor()` once that file is wired to call iOS's
selection function, and the amount/name fields stay blank, the same tier Android's own
`_isNanoAvailable` gives an ineligible device.

**Availability has two states, not four.** `SystemLanguageModel.default.availability` resolves to
either `.available` or `.unavailable(reason:)`; there's no `.downloadable`/`.downloading` pair the
way ML Kit's AICore has, because the model ships with the OS rather than as a separate download.
`FoundationModelsFeatureStatus` (Dart) mirrors this as a two-case enum
(`unavailable`/`available`), sent across the channel as a raw int, rather than reusing Android's
four-case `NanoFeatureStatus` shape — the extra two states would have no native counterpart to map
from. `isFoundationModelsAvailable()` (`foundation_models_field_extractor.dart`) checks the channel
and returns true only for `.available`, matching the `Future<bool> Function()` shape
`field_extractor_selection.dart` already uses for `_isNanoAvailable`, so it plugs into the existing
optional-override parameter without changing that file's signature.

**No Flutter plugin: a hand-rolled platform channel straight to Apple's own Swift framework.** Two
third-party pub.dev packages were checked before deciding this — `foundation_models_framework` and
`native_ai_bridge`. Neither is a stub the way Android's `google_mlkit_genai_prompt` was:
`foundation_models_framework`'s Swift source (checked directly on GitHub) implements a real
`LanguageModelSession.respond(to:options:)` call and returns actual model text, not a
not-yet-implemented error. Both packages were still passed over, for reasons distinct from
Android's stub finding: `foundation_models_framework` ships as beta from an unverified publisher
with modest adoption (25 GitHub stars, 702 total pub.dev downloads) and a Pigeon-generated surface
built for session management, streaming, and tool calling that this app doesn't need; `native_ai_bridge`
is earlier-stage still (version 0.1.0, single-digit weekly downloads). Neither risk applies to
Android's problem (a wrapper hiding a broken SDK) — the risk here is instead the same one ADR-0053
already ruled against for a different reason: depending on a third-party wrapper around a first-party
API that Apple's own Swift already exposes cleanly, for two calls (`checkFeatureStatus`,
`runInference`) neither package's surface materially simplifies. `foundation_models_channel.dart`
calls a single `MethodChannel` (`"spendwise/foundation_models_field_extractor"`, methods
`checkFeatureStatus`/`runInference`) that `FoundationModelsFieldExtractorChannel.swift` answers,
delegating the actual `FoundationModels` calls to `FoundationModelsSdk.swift` — the same
channel-handler/SDK-wrapper split ADR-0053 used for `NanoFieldExtractorChannel.kt`/`NanoPromptSdk.kt`.
Every call site that touches a `FoundationModels` type guards with `#available(iOS 26.0, *)` first;
this app's own iOS deployment target stays at 13.0, below that floor, on purpose — see Consequences.

**Seam: `FieldExtractor`, the same interface Android already implements, not a new one.**
`FoundationModelsFieldExtractor` implements `extractName`/`extractAmount`/`dispose` exactly as
`NanoFieldExtractor` does: each takes the recognized receipt's reading-order text and returns the
field or `null`, throwing `FieldExtractionFailure` on a real engine error and never using an empty or
wrong result to signal "not found."

**Session lifecycle: a fresh session per field, same rule as Android, same reasoning.** Nothing
checked in Apple's own documentation or the third-party plugin's source promises that reusing one
`LanguageModelSession` across unrelated prompts is safe, and issue #18's prototype already found one
on-device engine (MediaPipe/Gemma) that crashed under session reuse. `FoundationModelsSdk.runInference`
creates a new `LanguageModelSession()` and lets it go out of scope once the call finishes, rather than
betting on undocumented reuse safety. This is a conservative default, not a proven requirement for
this specific framework; revisit if per-field latency from repeated session setup becomes a measured
problem.

**Prompts: identical wording to Android's, not independently redesigned.** The extraction task is the
same regardless of which model answers it, so `foundation_models_field_extractor.dart` copies
`nano_field_extractor.dart`'s name and amount prompts verbatim, including the amount prompt's
decoy-exclusion list ("Cash", "Change Due", "Tendered", "Subtotal", "Tax") and total-label priority
("Total", "Grand Total", "Amount Due") from issue #18's finding, and the fixed `"NONE"` not-found
token so a miss is a string compare rather than another parsing pass. The amount response is parsed
into `Decimal` through the same currency-number regex Android uses; a response that doesn't match is
treated as not found, never a thrown error.

## Consequences

No amount/name heuristic exists on iOS to fall back to — it was never built for this platform, unlike
Android where ADR-0053 explicitly deleted one. A device with no eligible Foundation Models model gets
blank fields, the same behavior `receipt_recognizer_selection.dart` already gives the web platform
for OCR recognition itself.

This app's own iOS deployment target (13.0) is left below the Foundation Models framework's iOS 26
floor, deliberately: Foundation Models is a null-gated feature, not an install-time requirement, so a
device below that floor still installs and runs the app with field extraction reporting unavailable,
same as any other ineligible device. Swift's `#available(iOS 26.0, *)` guard is what keeps a device
below that floor from ever reaching a `FoundationModels` type; there's no manifest-merge equivalent to
override the way Android's `AndroidManifest.xml` needed for the GenAI Prompt SDK's own `minSdkVersion`
declaration, since Swift's availability checking is a compile-time and runtime language feature, not a
build-manifest constraint.

`field_extractor_selection.dart` is wired to call `isFoundationModelsAvailable()` and construct
`FoundationModelsFieldExtractor` on the iOS branch, added once both this ADR's and ADR-0054's code
existed (avoiding two concurrent edits to the same selection file). The branch order checks
`kIsWeb` first (web needs the conditional-import split ADR-0054 describes, since iOS's own check
uses `defaultTargetPlatform`, which is safe to import unconditionally), then
`defaultTargetPlatform == TargetPlatform.iOS`, then falls through to Android — no `dart:io` import
needed, since `defaultTargetPlatform` is Flutter's own cross-platform-safe target check.

`docs/specs/ocr-receipt-entry.md`'s "Field extraction" requirement now covers all three platforms,
updated at the `spec-keeper` checkpoint once this ADR, ADR-0054, and the selection wiring all
landed.

This ADR does not decide web (#24) — ADR-0054 covers that platform's equivalent decisions
independently, per ADR-0053's own framing that neither iOS nor web reuses another platform's
implementation even though both implement the same `FieldExtractor` seam.
