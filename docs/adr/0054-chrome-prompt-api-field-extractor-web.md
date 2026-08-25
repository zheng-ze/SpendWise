# 54. Chrome's built-in Prompt API, no fallback engine, is web's `FieldExtractor`

## Status

Accepted

## Context

ADR-0053 settled Android's field-extraction engine (Gemini Nano via ML Kit's GenAI Prompt SDK) and
explicitly left iOS (#23) and web (#24) as separate tickets, each expected to implement the same
`FieldExtractor` seam without reusing Android's implementation. This ADR is web's half of that,
tracked as issue #24.

Chrome ships a genuine on-device path for the same job: the Prompt API, built directly into the
browser from Chrome 148 onward, backed by the same Gemini Nano model Android uses, with no bundled
model and no separate Flutter package to add. The API surface is `LanguageModel`, a global object
exposed on `self`/`window` - not the older `window.ai.languageModel` shape from Chrome's earlier
origin trial, which this ADR does not target. Confirmed against Chrome's own developer docs
(`developer.chrome.com/docs/ai/prompt-api`) and the Web Machine Learning group's Prompt API explainer
(`github.com/webmachinelearning/prompt-api`) as of this writing.

## Decision

**Chain: Chrome's Prompt API, if `LanguageModel.availability()` reports `"available"`, else nothing.**
No fallback engine, same shape as ADR-0053's Android chain. A browser that isn't eligible - Firefox,
Safari, or a Chrome build below the API's floor - gets `null` from `field_extractor_selection.dart`'s
`selectFieldExtractor()` once that file is wired to call web's selection function, and the amount/name
fields stay blank. This is the same tier `receipt_recognizer_selection.dart`'s `selectRecognizer()`
already gives the web platform for OCR recognition itself, and the same tier Android's own
`_isNanoAvailable` gives an ineligible device.

**Availability has four states, not two, and only one counts as usable now.**
`LanguageModel.availability()` resolves to `"unavailable"`, `"downloadable"`, `"downloading"`, or
`"available"`. The API object can exist on `self` before the model itself has ever been downloaded
for this origin, so a presence check alone (`'LanguageModel' in self`) is not sufficient - issue #24's
own body flagged this. `chrome_prompt_api_availability.dart`'s `isChromePromptApiAvailable` checks
`kIsWeb` first (mirroring `receipt_recognizer_selection.dart`'s `kIsWeb` branch order), then calls
`availability()` and only returns true for `"available"`. `"downloadable"` and `"downloading"` are
treated the same as `"unavailable"`, matching ADR-0053's Android call: this ticket does not build a
download-and-wait flow, so "eligible but not yet downloaded" is not yet usable. This mirrors Android's
`NanoFeatureStatus` enum almost exactly - the four Prompt API strings map one-to-one onto it - which
is coincidence, not a shared implementation; `PromptApiAvailability` is its own enum, not a reuse of
`NanoFeatureStatus`, since the two engines have no other shared code and forcing a shared enum across
an Android platform-channel result and a Chrome JS string return would couple two unrelated seams for
no benefit.

**Interop: hand-rolled `dart:js_interop` bindings, no wrapper package.** `chrome_prompt_api_interop.dart`
declares `JSLanguageModel` (the `LanguageModel` global, bound via `@JS('LanguageModel')`) and
`JSLanguageModelSession` as `extension type`s over `JSObject`, covering exactly the three calls this
ticket needs: `availability()`, `create()`, and a session's `prompt()`/`destroy()`. No pub.dev package
wraps the Prompt API today, and ADR-0053 already rejected a third-party wrapper for Android's
equivalent call (the `google_mlkit_genai_prompt` plugin shipped an unfinished `runInference`) - the
same reasoning applies here a fortiori, since no such wrapper exists to even consider. This file is
kept purely mechanical: no receipt-domain logic, no prompt text, so a future caller needing a
different Prompt API capability doesn't have to touch extraction code to get it.

**Seam: `FieldExtractor`, same interface Android implements, no changes to it.**
`ChromePromptApiFieldExtractor` in `chrome_prompt_api_field_extractor.dart` implements
`extractName`/`extractAmount`/`dispose` exactly as ADR-0053 defined the contract: throws
`FieldExtractionFailure` on a real engine error, returns `null` (never throws) when a field isn't
found. The JS-interop calls sit behind a small seam, `PromptApiEngine` (one method, `prompt(String)
-> Future<String>`), the same shape `NanoEngine` gives `NanoFieldExtractor` on Android - so a test
fakes `PromptApiEngine` and never touches a real browser global, consistent with
`docs/research/ocr-accuracy-testing-strategy.md`'s framing of vendor-trusting the engine and testing
only this repo's own wrapper code.

**Session lifecycle differs from Android's, and that difference is deliberate.** ADR-0053's Android
implementation opens a fresh ML Kit client per field and closes it immediately after, because nothing
in that SDK's docs promises reuse across calls is safe. Chrome's Prompt API session carries no
equivalent documented hazard, and `LanguageModel.create()` itself has real cost worth not repeating
per field: it re-runs the browser's eligibility check and, for a session whose model isn't yet
downloaded, needs a user-activation gesture to proceed. `LanguageModelEngine` in
`chrome_prompt_api_field_extractor.dart` therefore opens one session lazily on its first `prompt()`
call and keeps it open across both the name and amount extractions for one receipt, destroying it only
when `ChromePromptApiFieldExtractor.dispose()` runs. This is the opposite default from Android's
fresh-per-call rule, for the opposite reason: Android chose fresh-per-call because reuse safety was
unconfirmed and cheap to avoid; here, session creation's own cost and activation requirement make
reuse the safer default, and nothing found in Chrome's docs discourages prompting the same session
more than once - the explainer's own multi-turn examples (`initialPrompts`, follow-up `prompt()`
calls) assume exactly that.

**Prompts: same wording as Android's, verbatim.** The extraction task is identical between the two
platforms; only the engine differs. `chrome_prompt_api_field_extractor.dart`'s `_namePrompt` and
`_amountPrompt` are copied from `nano_field_extractor.dart` unchanged, including the fixed `"NONE"`
not-found token, the amount prompt's decoy-label exclusion list ("Cash", "Change Due", "Tendered",
"Subtotal", "Tax"), and its total-label priority ("Total", "Grand Total", "Amount Due") from issue
#18's finding. The amount response is parsed the same way too: the same currency-number regex, fed
through `Decimal.tryParse`, never a `double`.

**Wired into `field_extractor_selection.dart` behind a conditional import.** `dart:js_interop` is
unavailable outside a web compile target, so `field_extractor_selection.dart` cannot import
`chrome_prompt_api_availability.dart` (or anything that imports it) directly without breaking every
non-web test that transitively reaches that file - which is most of the app's widget tests, via
`receipt_scan_flow.dart`. The fix follows this repo's own precedent
(`app/lib/persistence/database_connection.dart`'s native/web split): a matched pair,
`chrome_prompt_api_selector_web.dart` (calls `isChromePromptApiAvailable` and constructs
`ChromePromptApiFieldExtractor` for real) and `chrome_prompt_api_selector_native.dart` (always
returns `null`, imports nothing web-specific), selected via
`import 'chrome_prompt_api_selector_native.dart' if (dart.library.js_interop) 'chrome_prompt_api_selector_web.dart'`.
`field_extractor_selection.dart` only ever imports the conditional pair, never
`chrome_prompt_api_availability.dart`/`chrome_prompt_api_field_extractor.dart` directly.

## Consequences

A browser without the Prompt API - Firefox, Safari, non-eligible Chrome - gets blank amount/name
fields on receipt scan, identical to today's recognition-failure path and identical to what an
ineligible Android device already gets. No heuristic fallback exists for any platform now that
ADR-0053 deleted Android's.

`chrome_prompt_api_interop.dart`'s bindings only resolve when compiled to JavaScript (or WebAssembly)
for the web platform; they cannot be exercised against a real `dart:js_interop` global under the
Dart VM test runner (`flutter test`'s default target), so unit tests for
`ChromePromptApiFieldExtractor` and `isChromePromptApiAvailable` fake `PromptApiEngine` and the
availability check function respectively rather than loading the interop file's real bindings under
test. This still compiles and runs correctly under `flutter test --platform chrome`, which was used
to confirm the interop file loads under a real JS compile target - but no test in the committed suite
calls a genuine Chrome `LanguageModel` object, matching ADR-0053's Android precedent of never calling
the real AICore SDK from a test either.

This ADR does not decide iOS (#23), which ADR-0053 also left open. Each platform's `FieldExtractor`
gets its own ADR when built, per #21/#23/#24's shared-seam framing; none of the three reuses another
platform's concrete implementation.

`docs/specs/ocr-receipt-entry.md`'s "Field extraction" requirement now covers all three platforms,
updated at the `spec-keeper` checkpoint once this ADR, ADR-0055, and the selection wiring all
landed.
