# plan-management Specification

## Purpose
Defines the only surface where existing recurring plans are seen, changed and removed — plans are
created from the entry form, never here.

## Requirements

### Requirement: Plan list

Plans SHALL be listed in ascending order of next occurrence, with plans that have ended sorted last.
Plans sharing an ordering position SHALL be broken by name, so the order is deterministic rather than
arbitrary.

Each row SHALL show the plan's name, its frequency and source, its next occurrence or that it has
ended, and its template amount as a magnitude, colored to distinguish an income plan from an expense
one.

The list SHALL NOT offer plan creation. Plans are created from the entry form's recurrence flow.

#### Scenario: Ended plans sort last

- **WHEN** some plans have no next occurrence
- **THEN** they appear after every plan that does

#### Scenario: No creation affordance

- **WHEN** the plan list is shown
- **THEN** it offers no way to add a plan

### Requirement: Editing a plan

The plan form SHALL allow changing the name, the amount, the frequency, the first date and the end
date.

The amount SHALL be entered as a magnitude, and saving SHALL preserve the template's original sign —
an expense plan stays an expense.

The source SHALL be shown but SHALL NOT be editable.

Saving SHALL require a non-blank name and a non-zero amount.

#### Scenario: Sign survives an amount edit

- **WHEN** the amount of an expense plan is changed
- **THEN** the stored template amount remains negative

#### Scenario: Source is fixed

- **WHEN** a plan is edited
- **THEN** its source is displayed read-only

### Requirement: Editing does not regenerate history

Changing a plan's first date or frequency SHALL NOT retroactively generate or remove entries that
already exist. The plan's resolution cursor governs what is generated next.

#### Scenario: Moving the anchor backwards

- **WHEN** a plan's first date is moved earlier
- **THEN** no past occurrences are generated for the intervening period

### Requirement: Deleting a plan

Deleting a plan SHALL ask for confirmation and SHALL state that entries already generated are kept.

Deletion SHALL be permanent — plans have no recycle bin.

#### Scenario: Generated entries survive

- **WHEN** a plan is deleted
- **THEN** the entries it already produced remain in the ledger
