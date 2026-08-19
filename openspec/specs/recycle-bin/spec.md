# recycle-bin Specification

## Purpose
Defines what archiving is for: a place archived accounts, pockets and categories can be seen,
restored, or finally removed.

Without this surface, deletion is indistinguishable from destruction from the user's point of view.

## Requirements

### Requirement: Bin contents

The bin SHALL list archived accounts, pockets and categories in three sections, each hidden when
empty, with a whole-screen message when nothing is archived.

Rows SHALL be ordered by name within their section, and SHALL show how many entries reference the
row, so the user can see what keeps the name alive.

A pocket SHALL be shown with its qualified name when its parent still resolves.

#### Scenario: Empty section is hidden

- **WHEN** no categories are archived
- **THEN** the categories section is not shown

#### Scenario: Reference count is shown

- **WHEN** entries reference an archived holder
- **THEN** its row shows how many

### Requirement: Restoring

A row SHALL offer restore, returning the row to active use.

Restoring a pocket whose parent account is still archived SHALL do nothing, per the domain's rule
that the parent must be restored first.

#### Scenario: Pocket under an archived parent

- **WHEN** a pocket is restored while its parent account is still archived
- **THEN** nothing changes

### Requirement: Purging

A row SHALL offer permanent removal behind a confirmation that names the row and explains that
existing entries keep the name but the row can no longer be restored.

Purging SHALL route to the appropriate domain operation for the kind of row, and the domain SHALL
decide whether the row becomes reference-only or is removed entirely.

#### Scenario: Purge keeps entry names readable

- **WHEN** a referenced holder is purged
- **THEN** entries that referenced it still display its name
