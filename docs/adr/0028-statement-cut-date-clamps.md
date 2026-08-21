# 28. The card statement-cut date clamps to the month's last valid day

## Status

Accepted

## Context

The Swift app computes a card's statement-cut date from naive date components. For a statement day
of 29–31 against a shorter month, that overflows into the following month, silently starting the
"spend since your statement" window in the wrong month and making the outstanding-balance figure
wrong. The Swift form itself limits the day picker to 1–28, so its own UI can never create this
case — but the domain never validates the range, so imported or synced data (and this port, once it
has both) can still produce it. Dart's date construction makes the failure mode worse, not better:
`DateTime(2026, 2, 31)` rolls over silently rather than raising any error.

## Decision

The statement-cut calculation clamps the day to the target month's last valid day, using the same
clamping helper the domain already has for month-end recurring-plan math. This is a sanctioned
defect fix — a deliberate deviation from the naive Swift behavior, not a porting bug — because the
underlying Swift behavior is wrong, not merely different.

Separately, `now` is injected into the statement-cut and outstanding calculations rather than read
internally via a bare current-time call, specifically so both are unit-testable without depending on
the day the test happens to run.

## Consequences

A statement day of 29, 30 or 31 always lands on a real day in every target month, including a
28-day February, rather than silently overflowing into the next month. The test matrix for this
covers statement days 28 through 31 against February, a leap February, a 30-day month and a 31-day
month — the exact matrix that would have caught the original Swift defect. Any future date math
touching a user-configured day-of-month must use the shared clamping helper rather than naive date
construction.
