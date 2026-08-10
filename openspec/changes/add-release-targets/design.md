# Design — release targets

## What this phase is

Verification and packaging, not development. The app is finished when this starts; this proves it.

## Decisions

### Mobile first, on real hardware

Android and iOS come first because they are the primary targets and because they are where the
port's riskiest behavior lives — lifecycle transitions driving plan resolution and the durability
flush, and platform storage.

Simulators are exactly where those two things are least faithful. A backgrounding flush that works in
a simulator and loses data on a real device is the failure this ordering exists to catch.

### Web is its own risk, and it comes late

Web runs a different database backend and has no isolates, so the analysis pass computes
synchronously there. Both paths were built with web in mind and both were unit-tested, but neither has
run in a browser until this phase.

Persisting across a page reload is the specific check, since it exercises the backend rather than the
UI.

### One smoke test per platform, not a suite

The integration test is deliberately thin: launch, interact once, assert something rendered. Its job
is to catch a platform that stopped launching — a class of failure no unit test can see and no one
notices until they try that platform by hand.

Deep behavior is already covered by the domain, runtime, persistence and widget suites. Duplicating
that per platform would be slow and would rot.

### The checklist covers what tests cannot reach

Backgrounding and resuming, closing and reopening, window resizing. These are manual because driving
them reliably in an automated test costs more than it returns at this scale — but they are written
down so they are performed consistently rather than remembered.

### A platform failure is a defect, fixed separately

If a platform surfaces wrong behavior, that is a bug the other platforms probably share and the tests
missed. Fixing it inside the release work would hide it in a commit about screenshots and READMEs.

## Test approach

One integration test per platform, run on device or in a browser as appropriate. The checklist is
executed per platform and its results recorded.

The README and screenshots are written last, from the app as it actually behaves — not from these
specs.
