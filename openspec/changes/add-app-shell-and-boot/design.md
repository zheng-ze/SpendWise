# Design — app shell and UI foundation

## Layout

`app/lib/ui/shell/` holds the adaptive shell, boot chrome and banner overlay. `app/lib/ui/format/`
holds currency, date, color and amount formatting. `app/lib/ui/common/` holds the shared widgets.

Screens land in `app/lib/ui/<tab>/` in their own changes. This one deliberately ships no screens — it
is the foundation four later changes build on, and splitting it out is what stops each of them
inventing its own currency formatter.

## Decisions

### View-model lifetime moves to providers — not a copy of V1

In the Swift app, view models are constructed inline in view bodies, so their lifetime hangs off view
identity. That is why V1 shipped zero view-model tests: there was no way to hold one without a view.
It is also a correctness problem — a rebuild can recreate a view model and silently reset the
selected month.

Screen state lives in providers instead. Form controllers are per-sheet and auto-dispose; derived
lists are pure functions of state and parameters, which is what makes them testable without pumping a
widget.

### Amount sanitizing drops excess digits rather than rounding

Typing a third fraction digit drops it. Rounding on keystroke would mean a partially-typed number
mutates under the cursor — type `1.005` and watch the field rewrite what you already entered. Dropping
is what V1 does and it is the right behavior.

The sanitizer is a pure function with a formatter wrapped around it, so the rules are testable
directly.

### Negatives are allowed in exactly one place

Only the balance field on the account and pocket edit forms accepts a leading minus. Every other
amount field takes a magnitude, and the entry's kind carries the sign. Allowing negatives broadly
would create two ways to express an expense.

### Theme colors, never hardcoded black

V1 hardcodes black for total values and label colors, which breaks in dark mode. Neutral text uses
the theme's on-surface color. Semantic gain/loss/neutral colors stay, in theme-aware shades — they
carry meaning, so they are not decoration to be themed away.

### Stored symbols stay SF Symbol names

Categories store SF Symbol names, and they keep storing them. The map from name to Material icon is a
presentation concern only. Rewriting stored values to Material names would break round-tripping with
the native app, which still reads the same data.

Unknown names resolve to a fallback rather than throwing, because imported or synced data can carry
names this build has never seen. A test asserts the whole catalog resolves, so a missing mapping is
caught at build time rather than appearing as a fallback icon in the UI.

### The save banner is not a snackbar

A snackbar is transient; the save state is an ongoing condition that should stay visible until it
clears. It is a root-level overlay layer driven by the Phase 3 banner state.

## Test approach

The formatting and sanitizing rules are pure functions and get unit tests — the sanitizer's
drop-not-round behavior, the hex parser's gray fallback, the week-range end being decremented from a
half-open window, and the net-color rule at exactly zero.

The symbol map gets a test asserting every catalog name resolves, which is the one that stops a
missing icon reaching a screen.

The shell gets widget tests for the three boot phases and for per-tab stack preservation: drill in,
switch tab, switch back, assert the detail is still there.
