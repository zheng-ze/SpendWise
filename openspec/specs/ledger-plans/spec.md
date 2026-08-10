# ledger-plans Specification

## Purpose
Defines recurring plans: templates that materialize entries on a schedule, the mutations that manage
them, and the sweep that resolves due occurrences into stored entries.

Plans are regenerable configuration rather than history, so they hard-delete instead of archiving and
never carry a lifecycle.
## Requirements
### Requirement: Recurrence schedule

A plan SHALL compute its occurrences as `anchor + k * step` for ascending whole `k`, where the step is
fixed by the frequency: weekly adds 7 days, biweekly 14 days, monthly 1 month, quarterly 3 months, and
yearly 1 year.

Month-based strides SHALL clamp to the last valid day of the target month rather than overflowing into
the following one.

#### Scenario: Month-end anchor clamps

- **WHEN** a monthly plan is anchored on 31 January
- **THEN** its next occurrence is the last day of February, not a date in March

#### Scenario: Occurrence window is exclusive of its start

- **WHEN** occurrences are requested after a date and up to a ceiling
- **THEN** an occurrence falling exactly on the start date is excluded and one falling exactly on the
  ceiling is included

#### Scenario: End date caps the window

- **WHEN** a plan has an end date earlier than the requested ceiling
- **THEN** no occurrence after the end date is returned

### Requirement: Deterministic occurrence ids

An entry materialized from a plan SHALL take a deterministic id derived from the plan id and the day
of the occurrence, so that two devices resolving the same occurrence converge on a single entry
instead of minting duplicates.

The plan id SHALL enter that derivation in lowercase normalized form, per the project-wide id rule.
Swift renders the same id uppercase, and the derivation hashes its input, so the same plan and day
produce a different occurrence id in each app. That divergence is intentional and SHALL NOT be
"corrected" toward the Swift output: the frozen app is a behavioral reference rather than a
conformance target, nothing cross-reads occurrence ids between the two, and normalizing here is what
keeps an id's identity independent of the case it was written in.

#### Scenario: Same occurrence yields the same id

- **WHEN** the same plan and occurrence day are resolved twice
- **THEN** both produce the same entry id

#### Scenario: Occurrence id satisfies the id rule

- **WHEN** an occurrence id is generated
- **THEN** it is a lowercase uuid string requiring no further normalization

### Requirement: Plan mutations

`addPlan` SHALL reject a duplicate id and `updatePlan` SHALL reject an unknown id. Both SHALL validate,
in order: the template's source resolves and is active, its destination likewise when present, its
category resolves, matches the kind the template implies, and is active when present, and the plan is
not already exhausted.

Unlike entry mutations, plan mutations SHALL NOT exempt holders already referenced by the stored
version: a plan template always requires active holders, on update as well as on add.

PORT FIX: the Swift `validate(_ plan:)` omits the category kind check, deferring a mismatch to a
per-occurrence failure from the resolve sweep. A template's kind is fixed by its own `amount` and
`destinationID`, so a mismatch fails every occurrence identically and forever; the sweep reports it
only after the fact, when the user is no longer editing the plan. The check is therefore hoisted to
write time, where the user can still act on it.

#### Scenario: Category kind mismatch is rejected at write time

- **WHEN** a plan is added whose template names a category whose kind contradicts the template's amount
  sign, or names any category while the template is a transfer
- **THEN** the mutation throws and no plan is stored

#### Scenario: Inactive holder is rejected on update

- **WHEN** a stored plan is updated and its template still names a holder that has since been archived
- **THEN** the mutation throws and the ledger is unchanged

#### Scenario: Exhausted plan is rejected

- **WHEN** a plan is added or updated whose last resolved date is at or past its end date
- **THEN** the mutation throws

#### Scenario: Deleting a plan is a hard delete

- **WHEN** a stored plan is deleted
- **THEN** its row is removed outright and a plan delete is reported

#### Scenario: Deleting an unknown plan is a no-op

- **WHEN** a plan id that is not stored is deleted
- **THEN** nothing changes and an empty change list is returned

### Requirement: Resolving due occurrences

The resolve sweep SHALL, for each stored plan, materialize every occurrence due since the plan's cursor
in ascending date order, then advance the plan's cursor.

An occurrence whose id is already present in the entry table SHALL be skipped silently, since it has
already been materialized. An occurrence that fails entry validation SHALL be recorded as a failure and
the sweep SHALL continue.

After materializing, a plan that has become exhausted SHALL be removed and reported as a plan delete;
otherwise a plan with due occurrences SHALL be stored with its advanced cursor. A plan with nothing due
that is not exhausted SHALL leave no state change and report nothing.

Within a single plan, entry upserts SHALL precede that plan's own upsert or delete.

#### Scenario: Already materialized occurrence is skipped

- **WHEN** the sweep reaches an occurrence whose entry id is already stored
- **THEN** no entry is written and no change is reported for that occurrence

#### Scenario: A failing occurrence does not abort the sweep

- **WHEN** one occurrence fails validation and later occurrences would succeed
- **THEN** the failure is recorded and the later occurrences are still materialized

#### Scenario: Idle plan is not re-persisted

- **WHEN** a plan has no occurrence due and has not become exhausted
- **THEN** the plan is left untouched and no change is reported for it

#### Scenario: Exhausted plan is retired

- **WHEN** advancing a plan's cursor leaves it unable to emit again
- **THEN** the plan is removed and a plan delete is reported

### Requirement: Archiving an account removes its plans

Archiving an account SHALL hard-remove every plan whose template references that account or any of its
pockets, reporting a plan delete for each.

Plans are configuration rather than history, so they do not archive alongside the holders they name.

#### Scenario: Plans referencing a pocket of the account go too

- **WHEN** an account is archived and a plan's template names one of its pockets
- **THEN** that plan is removed and reported deleted

### Requirement: Archiving a pocket or category freezes its plans

Archiving a pocket or a category SHALL NOT remove plans that reference it. The plan stays, its
occurrences fail validation while the row is inactive, and resolving reports those failures rather than
throwing. Restoring the row returns a holder that still has its plans.

This is deliberately narrower than the account rule above. Archiving an account is a whole-holder
retirement that takes its pockets with it, whereas archiving a single pocket or category is routine
tidying a user is expected to undo. Removing plans on the archive step would make restore silently
lossy, since nothing holds an archived plan to bring back.

#### Scenario: A plan naming an archived pocket survives and reports failures

- **WHEN** a pocket named by a plan's template is archived and plans are resolved
- **THEN** the plan is still stored, no entry is materialized, and a plan failure is reported for each
  due occurrence

### Requirement: Deleting a row out from under a plan removes the plan

Whenever a holder or category row is DELETED outright rather than archived, every plan whose template
names it SHALL be removed and a plan delete reported. This covers the dereference sweep, which deletes a
reference-only row once its last entry goes, and the purge paths that delete an unreferenced row.

Without this a plan is left naming a row that no longer exists, violating invariant clause 7. The
distinction from the freeze rule above is deletion versus archival: an archived row can come back, a
deleted one cannot.

#### Scenario: The dereference sweep takes the plan with the row

- **WHEN** deleting an entry leaves a reference-only holder or category unreferenced, so the sweep
  deletes it, and a stored plan's template names that row
- **THEN** the plan is removed and a plan delete is reported alongside the row's deletion

