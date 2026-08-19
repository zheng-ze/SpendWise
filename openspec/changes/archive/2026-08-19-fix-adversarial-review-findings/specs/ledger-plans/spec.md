## MODIFIED Requirements

### Requirement: Resolving due occurrences

The resolve sweep SHALL, for each stored plan, materialize every occurrence due since the plan's cursor
in ascending date order, then advance the plan's cursor.

An occurrence whose id is already present in the entry table SHALL be skipped silently, since it has
already been materialized. An occurrence that fails entry validation SHALL be recorded as a failure and
the sweep SHALL continue.

The cursor SHALL advance only past occurrences that were either materialized or already present. An
occurrence that failed validation SHALL NOT be treated as resolved: the cursor SHALL stop at the
earliest failed occurrence for that plan, so that a later sweep — run after whatever caused the
failure is fixed — can still regenerate it. When every failing occurrence for a plan is followed only
by other failures or nothing due, the cursor advances to just before the first failure; when a later
occurrence in the same sweep succeeds after an earlier one failed, the successful occurrence is still
materialized, but the cursor does not advance past the earlier failure.

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

#### Scenario: A failed occurrence is retried on a later sweep

- **WHEN** an occurrence fails validation, whatever caused the failure is fixed, and the plan is
  resolved again
- **THEN** that occurrence is materialized on the later sweep rather than having been permanently
  skipped

#### Scenario: Idle plan is not re-persisted

- **WHEN** a plan has no occurrence due and has not become exhausted
- **THEN** the plan is left untouched and no change is reported for it

#### Scenario: Exhausted plan is retired

- **WHEN** advancing a plan's cursor leaves it unable to emit again
- **THEN** the plan is removed and a plan delete is reported
