# 51. Receipt OCR runs on-device, split per platform rather than one shared engine

## Status

Accepted

## Context

OCR receipt entry needed a text-recognition engine covering iOS, Android, and web. Two axes were
open: on-device versus a cloud/hosted vision API, and one engine for every platform versus a
per-platform split.

Cloud OCR (a hosted vision API, or a vision-capable LLM) was rejected outright. It would add a
network dependency this app has never had, a per-scan cost, and an external data flow for the
user's own receipt photos — all avoidable, since on-device recognition is accurate enough for the
header fields this capability extracts (merchant, total, date), not full-page structured
extraction.

A single cross-platform on-device engine was investigated next and found not to exist in a form
worth depending on. `google_mlkit_text_recognition` explicitly does not support web at all ("Web or
any other platform is not supported," per its own documentation). Apple's Vision framework is
iOS/macOS-only by construction, so it can never be a single answer either. The most-adopted
Flutter Tesseract wrapper, `flutter_tesseract_ocr`, advertises web support in its package metadata,
but its actual web path requires the app to hand-write its own Tesseract.js interop — it is not a
working binding — and its native (iOS/Android) side carried 18 open issues at the time of research,
including real crash reports, a materially worse maintenance signal than ML Kit's tracker (3 open
issues, all build tooling, none about accuracy or crashes; a release within days of the research).
Full sourcing: `docs/research/ocr-receipt-entry-engine-choice.md`.

## Decision

Recognition runs fully on-device, no network call on any platform, and uses two different engines
by platform rather than one: `google_mlkit_text_recognition` on iOS and Android, and a
directly-wired Tesseract.js integration on web — built against Tesseract.js's own API rather than
routed through a Flutter wrapper package, since no such wrapper actually delivers a working web
binding today.

The web integration calls Tesseract.js with `{ blocks: true }` output so per-line bounding-box
geometry (`rowAttributes.rowHeight`, or `bbox.y1 - bbox.y0` as a fallback) is available to the
merchant-name heuristic on web, matching what `google_mlkit_text_recognition` already exposes on
iOS/Android. This is confirmed present in Tesseract.js's own type definitions and API reference,
not assumed; see `docs/specs/ocr-receipt-entry.md`.

## Consequences

Two separate recognition code paths must be built and kept working, rather than one — a real
ongoing cost, accepted because no single engine actually covers all three platforms today. A
`dart:js`/`package:web` interop layer must marshal Tesseract.js's nested block/paragraph/line/word
result across the JS boundary; this is untested in this repo as of this decision and is flagged as
a spike for whoever implements the web path, not a solved problem.

If a future Flutter package ships a genuinely working, well-maintained Tesseract.js (or other)
web binding, replacing the hand-wired integration becomes a reasonable local change — this decision
is about what's available now, not a permanent rejection of packaged options.
