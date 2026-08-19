## MODIFIED Requirements

### Requirement: Add, update and delete an entry

Adding an entry SHALL reject an id already present in the entry table with an id-collision error, then
validate it, then store and return an upsert of the validated entry.

Updating an entry SHALL reject a missing id with an unknown-entry error, validate the new entry against
the stored one, and replace it. Because retargeting can drop the last reference to a reference-only
holder or category, the update SHALL then run the dereference sweep over the holders the entry no longer
references and over its former category when the category changed. The returned changes SHALL be the
entry upsert followed by any sweep changes; when nothing was dropped the list is exactly the one upsert.

An entry carrying a system kind — one the app itself created, such as an opening balance or a balance
adjustment — SHALL reject an update that changes its name, category, or analysis-inclusion flag, with
a system-entry-locked error. Its amount, date and holders remain editable through the same update path
as a user-created entry. This protects the two invariants those synthetic entries exist to hold: a
consistent replayed balance and a name that identifies what created the row.

Deleting an entry SHALL be a hard delete — entries are never archived. A missing id is a no-op. The row
SHALL be removed and the dereference sweep run over the deleted entry's holders and its category. The
returned changes SHALL be the entry deletion followed by any sweep changes.

#### Scenario: Update with no dropped reference emits one change

- **WHEN** an entry's amount is edited without changing its holders or category
- **THEN** exactly one change is returned

#### Scenario: Retargeting revalidates against the new holders

- **WHEN** an entry is retargeted to a source that does not exist
- **THEN** an unknown-holder error is thrown and the stored entry is unchanged

#### Scenario: Delete removes only that entry

- **WHEN** one of several entries is deleted
- **THEN** only that row is removed and the returned changes begin with its deletion

#### Scenario: A system entry's name is locked

- **WHEN** an update to a system-kind entry changes its name, category, or analysis-inclusion flag
- **THEN** a system-entry-locked error is thrown and the stored entry is unchanged

#### Scenario: A system entry's amount stays editable

- **WHEN** an update to a system-kind entry changes only its amount
- **THEN** the update succeeds
