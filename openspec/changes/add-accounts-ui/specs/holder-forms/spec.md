# holder-forms Specification

## Purpose
Defines how accounts and pockets are created and edited, including the one place a user can state a
balance directly without the app rewriting what already happened.

## ADDED Requirements
### Requirement: Creating a holder

The creation form SHALL offer a choice between an account and a subpocket. That choice SHALL be
locked to account when no account can hold a pocket.

An account SHALL take a name, a type, an optional opening balance, and a statement day offered only
for cards. A subpocket SHALL take a name and a parent.

Cards SHALL NOT be offered as pocket parents.

#### Scenario: No eligible parents

- **WHEN** no account can hold a pocket
- **THEN** the form is locked to creating an account

#### Scenario: Statement day is card-only

- **WHEN** a non-card type is selected
- **THEN** no statement day control is shown

### Requirement: Creation validation and save

Saving SHALL require a non-blank name, and a subpocket SHALL additionally require a parent.

A statement day SHALL be persisted only for cards. A non-zero opening balance SHALL be posted as the
domain's opening-balance entry after the holder is created.

Failures SHALL surface in the form rather than dismissing it.

#### Scenario: Zero opening balance

- **WHEN** an account is created with no opening balance
- **THEN** no opening entry is posted

### Requirement: Editing a holder

The edit form SHALL allow changing a holder's name, and for accounts its type and card statement day.

It SHALL offer a toggle treating incoming transfers as expenses, on both accounts and pockets, and a
toggle including the holder in net worth, on accounts only.

#### Scenario: Net worth toggle is account-only

- **WHEN** a pocket is edited
- **THEN** no net-worth toggle is shown

### Requirement: Balance adjustment

The edit form SHALL show the holder's current derived balance in an editable field that accepts
negative values.

Changing it SHALL NOT rewrite history. On save, when the entered balance differs from the current
one, the form SHALL post a single adjustment entry for the difference, excluded from analysis, so the
running balance stays consistent with a replay of the entry log.

When the entered balance is unchanged, no entry SHALL be posted.

An empty balance field SHALL count as zero.

#### Scenario: Adjusting a balance

- **WHEN** the user changes the balance to a higher figure and saves
- **THEN** one adjustment entry for the difference is posted, excluded from analysis

#### Scenario: Unchanged balance

- **WHEN** the balance field is saved unchanged
- **THEN** no entry is posted
