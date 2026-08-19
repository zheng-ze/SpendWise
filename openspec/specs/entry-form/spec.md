# entry-form Specification

## Purpose
Defines the only surface that creates and edits entries: its modes, its fields, what makes it
saveable, how a sign is derived, and how a recurrence becomes a plan.

## Requirements

### Requirement: Read-only-first viewing

Opening an existing entry SHALL show it read-only, with an explicit control to enter edit mode. This
is the shipped design and SHALL NOT be changed to open directly in edit mode.

Cancelling an edit SHALL revert the fields to their persisted values and return to the read-only
view with the sheet still open, rather than dismissing it.

In the read-only view all fields SHALL be non-interactive while still rendering normally.

#### Scenario: Cancelling an edit

- **WHEN** the user edits fields and then cancels
- **THEN** the fields return to their stored values and the sheet remains open, read-only

### Requirement: Form fields

The form SHALL offer a kind selection of expense, income or transfer; an amount; a name; a date; a
source; either a destination for transfers or a category otherwise; and an analysis inclusion toggle
defaulting to on.

Changing the kind SHALL clear the selected category, since categories are bound to a kind.

The amount field SHALL NOT accept negatives — the sign is derived from the kind on save.

#### Scenario: Kind change clears category

- **WHEN** the user changes the kind after selecting a category
- **THEN** the category selection is cleared

### Requirement: Save validation

The form SHALL permit saving only when the amount parses to a non-zero value, the name is non-empty,
and a source is selected. A transfer SHALL additionally require a destination that is not the source.

Deeper rules — category kind matching, holder existence — belong to the domain validator and SHALL
surface through the error section rather than being duplicated here.

#### Scenario: Transfer to itself

- **WHEN** a transfer's destination equals its source
- **THEN** the form cannot be saved

#### Scenario: Domain rejection is shown

- **WHEN** a save is rejected by domain validation
- **THEN** the error is shown in the form rather than dismissed silently

### Requirement: Sign derivation

The stored amount's sign SHALL be derived from the kind: income positive, expense negative, and a
transfer positive with a destination set and no category.

#### Scenario: Expense is stored negative

- **WHEN** an expense is saved
- **THEN** its stored amount is negative

### Requirement: Save outcomes

Editing an existing entry SHALL update it and return to the read-only view, keeping the sheet open.

Creating an entry without a recurrence SHALL add it and dismiss.

Creating an entry with a recurrence SHALL create a plan instead, anchored at the chosen date with the
optional end date, and SHALL then resolve plans immediately so that due occurrences — including the
anchor day itself, when not future-dated — appear at once.

#### Scenario: Anchor materializes immediately

- **WHEN** an entry is created with a recurrence anchored today
- **THEN** the occurrence for today appears in the list without waiting for a later resolve

### Requirement: Deletion from the form

The form SHALL offer deletion only while editing an existing entry, and that path SHALL delete and
dismiss without a confirmation. The confirmed path is the swipe action on the list.

#### Scenario: Delete from the form

- **WHEN** the user deletes from the form
- **THEN** the entry is deleted and the sheet dismisses without a confirmation prompt

### Requirement: Picker sheets

Selecting a source or a category SHALL use a shared two-column picker presenting parents on the left
and the expanded parent's children on the right.

Tapping a parent that has children and is not yet expanded SHALL expand it. Tapping a childless
parent, or an already-expanded parent again, SHALL select that parent. Tapping a child SHALL select
it. Selection SHALL dismiss the picker.

The source picker SHALL offer active accounts with their active pockets as children and SHALL NOT
offer a none option. The category picker SHALL offer a none option and SHALL NOT be shown for
transfers.

#### Scenario: Second tap selects the parent

- **WHEN** a parent with children is tapped twice
- **THEN** the parent itself is selected

#### Scenario: Transfers skip the category picker

- **WHEN** the kind is transfer
- **THEN** no category picker is offered

### Requirement: Recurrence selection

Recurrence SHALL be chosen from a fixed list offering no repetition plus weekly, biweekly, monthly,
quarterly and yearly. Choosing one SHALL set it and dismiss.

Recurrence SHALL be offered only when creating an entry, not when editing an existing one.

#### Scenario: Editing an entry offers no recurrence

- **WHEN** an existing entry is edited
- **THEN** no recurrence control is shown
