# transactions-screen Specification

## Purpose
Defines the app's primary surface: how entries are grouped into days and months, what each grouping
totals, and what the user can do to a row.

The derivations are specified as pure functions of ledger state because that is what makes them
testable without rendering a screen.

## ADDED Requirements
### Requirement: Daily and monthly modes

The screen SHALL offer a daily and a monthly view. The daily view SHALL work over a month window and
the monthly view over a year window, and the selector's step SHALL follow the active view's unit.

The totals bar and both views SHALL derive from the same window, so they can never disagree about
what period is shown.

#### Scenario: Switching mode changes the step

- **WHEN** the user switches to the monthly view
- **THEN** the selector steps by years rather than months

### Requirement: Day sections

Entries SHALL be grouped into day sections by resolving each entry to a row, filtering to the window,
and grouping by the start of its day. Rows within a day SHALL be ordered newest first, and days
themselves newest first.

Window filtering SHALL be half-open, consistent with the rest of the port.

Where a source scope is given, only entries touching a scoped holder — as source or as destination —
SHALL be included.

#### Scenario: Ordering

- **WHEN** a day holds several entries
- **THEN** they are listed newest first, and that day appears above older days

#### Scenario: Scoped to a holder

- **WHEN** the screen is scoped to a holder
- **THEN** only entries with that holder as source or destination appear

### Requirement: Section totals

A day section's income SHALL be the sum of its income rows and its expenses the positive magnitude of
its expense rows. Transfers SHALL count toward neither.

Only entries included in analysis SHALL contribute. Category-level exclusion SHALL NOT be applied
here — this screen gates on the entry alone.

#### Scenario: Transfer is excluded from totals

- **WHEN** a day contains a transfer
- **THEN** it contributes to neither income nor expenses

#### Scenario: Entry excluded from analysis

- **WHEN** an entry is flagged out of analysis
- **THEN** it does not contribute to its section's totals

### Requirement: Row resolution

Each entry SHALL resolve to a row carrying a title, an account line, a symbol, a color and an amount.

A non-transfer SHALL take its title from its category, rendered as parent and child when nested and as
"Uncategorized" when it has none, and its account line from its source, falling back to an unknown
label when the holder cannot be resolved.

A transfer SHALL be titled as a transfer, SHALL show source and destination in its account line, and
SHALL display its amount unsigned and neutral.

#### Scenario: Unresolvable holder

- **WHEN** an entry references a holder that cannot be resolved
- **THEN** its account line shows an unknown label rather than failing

### Requirement: Day headers and empty state

Each day section SHALL carry a header showing the day, its date, and the day's net, colored by sign.
Headers SHALL stay pinned while their section scrolls.

When the window contains no sections, the screen SHALL show an empty state.

#### Scenario: Month with no activity

- **WHEN** the selected month has no entries
- **THEN** the empty state is shown

### Requirement: Row interactions

Tapping a row SHALL open the entry form read-only. Swiping a row SHALL offer a delete action, which
SHALL ask for confirmation before deleting.

The confirmation SHALL identify the entry by its typed note, falling back to its title when the note
is empty.

#### Scenario: Swipe delete is confirmed

- **WHEN** the user swipes a row and chooses delete
- **THEN** a confirmation is shown before the entry is deleted

### Requirement: Month summaries

The monthly view SHALL list months of the selected year up to and including the current calendar
month, newest first. A future year SHALL therefore render no rows, and a fully past year all twelve.

Each month SHALL carry its income and expenses under the same rules as day sections, a flag for the
current month, and the weeks overlapping it.

A week SHALL keep its full range even when it spills into a neighboring month, so a spillover week
appears under both months with identical totals.

#### Scenario: Future year is empty

- **WHEN** a year later than the current one is selected
- **THEN** no month rows are shown

#### Scenario: Spillover week

- **WHEN** a week spans the boundary between two months
- **THEN** it appears under both, with the same full-week totals

### Requirement: Month breakdown interactions

Expanding a month SHALL collapse any other expanded month, so at most one is open at a time.

Tapping a week SHALL switch to the daily view of that week's month. It SHALL NOT scroll to the week
itself.

#### Scenario: Only one month expands

- **WHEN** a month is expanded while another already is
- **THEN** the previously expanded month collapses

### Requirement: Entry creation affordance

The screen SHALL offer an action button that creates an entry directly when it has a single action.
Where a scoped screen adds a second action, the button SHALL expand to offer both, collapsing before
firing the chosen one.

#### Scenario: Single action does not expand

- **WHEN** the button has only the create action
- **THEN** tapping it opens the new entry form immediately
