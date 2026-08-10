# Design — accounts screen and holder forms

## Layout

`app/lib/ui/accounts/` splits derivation from presentation as the transactions screen does. Section
grouping, row totals, payable, outstanding and the statement cut are pure functions; the widgets call
them.

The accounts tab owns its own navigation stack, since it pushes the transactions screen with a scope
rather than switching tabs.

## Decisions

### The statement cut must clamp — a V1 defect fixed under sanction

V1 builds the cut date from naive date components. For a statement day of 29 to 31 against a shorter
month, that overflows into the following month, so the "spend since your statement" window silently
starts in the wrong month and outstanding is wrong.

V1's own form caps the day at 1–28, so its UI cannot create the case — but imported or synced data
can, and this port will eventually have both. Dart makes it worse: `DateTime(2026, 2, 31)` rolls over
silently rather than failing.

The port uses the shared clamping helper the domain already has for month-end date math, so the cut
lands on the month's last valid day. The master doc sanctions this fix explicitly.

### `now` is injected, never read inside the calculation

V1 buried `Date()` inside the view model, which makes the statement window untestable — the tests
would depend on the day they ran. Both `statementCut` and `outstanding` take the current time as a
parameter.

### Outstanding and payable measure different things

Payable is the whole negative balance clamped at zero — what you owe. Outstanding is only
non-transfer spend since the cut — what you have charged this cycle. A repayment is a transfer, so it
reduces payable through the balance but leaves outstanding alone. That is correct: the repayment does
not un-spend the money.

Pockets are excluded from outstanding, which is free — cards cannot hold pockets anyway.

### Only what renders gets ported

V1's section subtotal reduce subtracts payables for card rows, but card sections never render that
subtotal — they render the two labelled columns instead. The port implements the two columns and does
not carry the dead branch across.

### The delete confirmation shows the reference count — a deliberate deviation

V1 computes the referencing-entry count for the delete dialog and then never displays it; the alert
has no message. Showing it costs nothing, matches the recycle bin's own wording, and tells the user
what archiving actually preserves. Flagged as a deviation rather than left as an accident.

### The balance field posts an adjustment, never a rewrite

Editing a holder's balance does not touch stored entries. It posts one adjustment entry for the
difference, excluded from analysis. Rewriting history would break replay consistency — the stored
entry log is the source of truth for every balance, and a directly-set balance would disagree with
it the moment anything replayed.

No difference means no entry. That case needs its own test, because posting a zero-value entry would
be invisible in the UI and wrong in the data.

## Test approach

The derivations carry the weight: section grouping, order and empty-type skipping; payable clamping at
zero; the outstanding filter matrix, where a transfer, a positive amount, a pocket-sourced entry and
an out-of-window entry must each be excluded for a different reason; the statement-cut anchor month on
both sides of the statement day; and the balance-adjustment delta including the no-delta case.

The clamp gets its own matrix — statement days 28 through 31 against February, a leap February, a
30-day month and a 31-day month. That is the test that would have caught the V1 defect.

The account row gets a golden test, since the card two-column variant is easy to regress.
