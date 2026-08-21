# 19. The persistence store corrects three Swift durability gaps

## Status

Accepted

## Context

Three separate durability behaviors in the Swift store were each individually broken in a way that
only shows up under real-world conditions (a backgrounding app, a failing disk, a healthy app that
should stay quiet) rather than in ordinary testing.

## Decision

Three corrections, each deliberate and each verified by a test that would fail against the
original Swift semantics:

- **`flushNow` loops until pending is empty.** Swift ran a single trailing flush that could
  early-return while the buffer still held work, so a backgrounding app could return from its
  durability barrier with data unwritten. The port loops, and the loop terminates only on a
  reported failure — not by spinning forever against a genuinely broken disk — handing recovery to
  the timed retry below.
- **A reported failure schedules its own retry.** Swift reported `failedWillRetry` and then waited
  passively for the next mutation to trigger another attempt; an app that fails to save and is then
  left alone never retried on its own, and the data sat in memory until the process died. The port
  schedules a timed re-flush at the moment it reports the failure.
- **`clear` is reported only after a non-clear state.** Reporting a clear save state
  unconditionally would make a perfectly healthy app emit banner-state transitions for a problem it
  never had. The store tracks whether it has reported a non-clear state and stays silent otherwise.

## Consequences

A backgrounding app is guaranteed to have flushed everything pending before the flush call returns,
a save that keeps failing keeps retrying without user action, and a healthy app never shows a save
banner at all. Any future change to the store's save cycle must preserve all three properties —
each is covered by a test that specifically demonstrates the corrected behavior against the
original (broken) Swift semantics, so a regression here should show up as a failing test rather
than only in production.
