## MODIFIED Requirements

### Requirement: Save validation

The form SHALL permit saving only when the amount parses to a non-zero value, the name is non-empty,
and a source is selected. A transfer SHALL additionally require a destination that is not the source.

Deeper rules — category kind matching, holder existence — belong to the domain validator and SHALL
surface through the error section rather than being duplicated here. That surfaced message SHALL be
phrased for the user rather than showing the domain error's internal representation verbatim.

#### Scenario: Transfer to itself

- **WHEN** a transfer's destination equals its source
- **THEN** the form cannot be saved

#### Scenario: Domain rejection is shown

- **WHEN** a save is rejected by domain validation
- **THEN** the error is shown in the form rather than dismissed silently

#### Scenario: Domain rejection is phrased for the user

- **WHEN** a save is rejected by domain validation
- **THEN** the message shown names the problem in plain language rather than the domain error's raw
  form

### Requirement: Picker sheets

Selecting a source or a category SHALL use a shared two-column picker presenting parents on the left
and the expanded parent's children on the right.

Tapping a parent that has children and is not yet expanded SHALL expand it. Tapping a childless
parent, or an already-expanded parent again, SHALL select that parent. Tapping a child SHALL select
it. Selection SHALL dismiss the picker.

The source picker SHALL offer active accounts with their active pockets as children and SHALL NOT
offer a none option. The category picker SHALL offer a none option and SHALL NOT be shown for
transfers.

Applying a picker's selection to the form SHALL be a no-op if the form is no longer showing — the
picker's result SHALL NOT be applied to a form that has already been dismissed.

#### Scenario: Second tap selects the parent

- **WHEN** a parent with children is tapped twice
- **THEN** the parent itself is selected

#### Scenario: Transfers skip the category picker

- **WHEN** the kind is transfer
- **THEN** no category picker is offered

#### Scenario: A dismissed form ignores a late picker result

- **WHEN** a picker sheet resolves after the form that opened it is no longer showing
- **THEN** the form does not attempt to update, and no error is raised
