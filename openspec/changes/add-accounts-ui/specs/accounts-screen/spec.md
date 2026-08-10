# accounts-screen Specification

## Purpose
Defines where balances are seen: how accounts are grouped and totalled, what a credit card owes and
has spent since its statement, and how a holder's own history is reached.

## ADDED Requirements
### Requirement: Net worth summary

The screen SHALL show assets, liabilities and their difference, taken from the domain's net worth
calculation rather than recomputed here.

#### Scenario: Summary reflects the domain

- **WHEN** an account's total is negative
- **THEN** it raises the liabilities figure rather than lowering assets

### Requirement: Grouped sections

Active accounts SHALL be grouped by type and rendered in a fixed type order, with types having no
accounts skipped entirely.

A non-card section SHALL show a subtotal of its rows, colored when negative. A card section SHALL
instead show two labelled figures, payable and outstanding, each summed over its rows.

#### Scenario: Empty type is skipped

- **WHEN** no account of a given type exists
- **THEN** that section is not rendered

### Requirement: Account rows

An account row SHALL show its name and its total, where the total is its own balance plus the
balances of its active pockets. A card row SHALL instead show payable and outstanding.

A row SHALL also expose its own balance excluding pockets, for use when expanded.

An expansion control SHALL be present only when the account has pockets, and SHALL have its own hit
target distinct from the row body.

#### Scenario: Account without pockets

- **WHEN** an account has no pockets
- **THEN** no expansion control is shown

### Requirement: Card payable and outstanding

Payable SHALL be the account's negated total clamped at zero, so a card in credit shows nothing
owed.

Outstanding SHALL be the negated sum of amounts for entries that are sourced from the card account
itself, are not transfers, are negative, and fall on or after the statement cut and not after now.
Transfers SHALL never reduce outstanding — a repayment reduces payable through the balance instead.

#### Scenario: Card in credit

- **WHEN** a card's total is positive
- **THEN** its payable is zero rather than negative

#### Scenario: Repayment does not reduce outstanding

- **WHEN** a transfer repays a card
- **THEN** outstanding is unchanged while payable falls

### Requirement: Statement cut

The statement cut SHALL be the statement day of the current month when today's day is on or after
it, and of the previous month otherwise.

The cut date SHALL be built with day clamping, so that a statement day beyond the length of the
target month resolves to that month's last day rather than overflowing into the next.

The calculation SHALL take the current time as a parameter rather than reading the clock internally.

#### Scenario: Statement day beyond month length

- **WHEN** a statement day of 31 is resolved against a 30-day month
- **THEN** the cut lands on the 30th, not the 1st of the following month

#### Scenario: Anchor month

- **WHEN** today falls before the statement day
- **THEN** the cut is in the previous month

### Requirement: Navigation to scoped history

Tapping a row's body SHALL open the transactions screen titled with the account name and scoped to
the account together with all its pockets.

An expanded account SHALL offer a row scoped to the account alone, showing its balance excluding
pockets, and one row per pocket scoped to that pocket.

At most one account SHALL be expanded at a time.

#### Scenario: Scoped to the account alone

- **WHEN** the user opens the excluding-subpockets row
- **THEN** the transactions screen is scoped to the account without its pockets

### Requirement: Deleting a holder

Accounts and pockets SHALL be deletable by swipe, behind a confirmation naming the holder. Deletion
SHALL archive to the recycle bin rather than destroying data.

The confirmation SHALL state how many entries keep the holder's name.

Deleting an expanded account SHALL collapse it.

#### Scenario: Confirmation reports references

- **WHEN** entries reference the holder being deleted
- **THEN** the confirmation states how many
