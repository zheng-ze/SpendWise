## MODIFIED Requirements

### Requirement: Creation validation and save

Saving SHALL require a non-blank name, and a subpocket SHALL additionally require a parent.

A statement day SHALL be persisted only for cards. A non-zero opening balance SHALL be posted as the
domain's opening-balance entry after the holder is created.

Failures SHALL surface in the form rather than dismissing it, phrased for the user rather than
showing a domain error's internal representation verbatim.

#### Scenario: Zero opening balance

- **WHEN** an account is created with no opening balance
- **THEN** no opening entry is posted

#### Scenario: Domain rejection is phrased for the user

- **WHEN** a save is rejected by domain validation
- **THEN** the message shown names the problem in plain language rather than the domain error's raw
  form

### Requirement: Editing a holder

The edit form SHALL allow changing a holder's name, and for accounts its type and card statement day.

It SHALL offer a toggle treating incoming transfers as expenses, on both accounts and pockets, and a
toggle including the holder in net worth, on accounts only.

Applying a picker's selection (such as a parent picker) to the form SHALL be a no-op if the form is
no longer showing — the picker's result SHALL NOT be applied to a form that has already been
dismissed.

#### Scenario: Net worth toggle is account-only

- **WHEN** a pocket is edited
- **THEN** no net-worth toggle is shown

#### Scenario: A dismissed form ignores a late picker result

- **WHEN** a picker sheet resolves after the form that opened it is no longer showing
- **THEN** the form does not attempt to update, and no error is raised
