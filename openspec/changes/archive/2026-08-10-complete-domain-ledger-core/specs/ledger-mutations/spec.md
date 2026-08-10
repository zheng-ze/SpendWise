## Purpose

Defines how rows enter and change in the ledger — accounts, pockets, entries and categories — including
what each mutation validates, what it stores, and the changes it reports back to its caller.

## ADDED Requirements

### Requirement: Mutation contract

Every mutation SHALL validate completely, then mutate, then return the ordered list of changes
describing what it changed. When validation fails the mutation SHALL throw and the ledger SHALL be left
untouched.

Delete, restore and purge mutations SHALL NOT throw: a missing id, or a target in the wrong lifecycle,
is a no-op that returns an empty change list.

Ordering guarantees hold between groups of changes, not within a group whose membership is unordered
(the pockets of an account, the rows visited by a sweep).

#### Scenario: Failed validation leaves no trace

- **WHEN** a mutation is rejected after it has already inspected several rows
- **THEN** the ledger is unchanged and the error propagates to the caller

#### Scenario: No-op returns empty

- **WHEN** a delete is called with an id that is absent, or with a target already in the wrong
  lifecycle
- **THEN** no change is made and the returned list is empty

### Requirement: Add and update an account

Adding an account SHALL reject an id already present anywhere in the money-source table, whether it
belongs to an account or a pocket, with an id-collision error. The stored account SHALL have its pocket
links forced empty: links are owned by pocket creation, and a caller-supplied set is discarded.

Updating an account SHALL reject an id that is missing or resolves to a pocket, with an unknown-account
error. The stored account SHALL take every field from the argument except two: its pocket links are
restored from the existing stored account, so the edit surface can never rewrite them; and its
statement day is kept only for a card-type account and forced to null for every other type.

Both SHALL return a single upsert of the stored account.

#### Scenario: Account id collides with a pocket

- **WHEN** an account is added with an id already used by a pocket
- **THEN** an id-collision error carrying that id is thrown

#### Scenario: Passed pocket links are discarded on add

- **WHEN** an account is added carrying a non-empty set of pocket links
- **THEN** the stored account has no pocket links

#### Scenario: Passed pocket links are ignored on update

- **WHEN** an account is updated carrying a bogus set of pocket links
- **THEN** the stored account keeps the links it already had

#### Scenario: Statement day is forced for non-card accounts

- **WHEN** a non-card account is updated with a statement day
- **THEN** the stored account has a null statement day

#### Scenario: Statement day is kept for cards

- **WHEN** a card account is updated with a statement day
- **THEN** the stored account keeps that statement day

A statement day SHALL be clamped to 1 through 28 on both add and update, and SHALL be null for every
non-card type on both. Clamping rather than rejecting is deliberate: the form already enforces the
range, so a value reaching the domain came from a drift row or an import, and dropping one row of a bulk
import over a recoverable field is worse than correcting it. 28 is the ceiling so every month has the
day. Invariant clause 13 catches a row that arrived through the seeding constructor instead.

Neither mutator SHALL accept a caller-supplied lifecycle that revives a row. An incoming lifecycle more
alive than the stored one falls back to the stored value, which keeps reference-only terminal, and
`tombstoned` is persistence-only so it is never writable through a mutator. The delete, purge and
restore mutators own every lifecycle transition, each enforcing its own precondition.

When an update moves an account to a less-alive lifecycle, its pockets SHALL follow, and the pocket
upserts SHALL be appended after the account upsert. A pocket may never be more alive than the account
holding it (invariant clause 15); the pocket write path enforces this by judging the child, so the edit
surface reaching the same state through the PARENT has to cascade instead.

#### Scenario: An out-of-range statement day is clamped

- **WHEN** a card account is added or updated with a statement day of 999 or -5
- **THEN** the stored account has a statement day of 28 or 1 respectively

#### Scenario: Archiving an account through an edit takes its pockets down

- **WHEN** an active account holding an active pocket is updated to archived
- **THEN** the stored pocket is archived too and its upsert follows the account's

### Requirement: Add and update a pocket

Adding a pocket SHALL apply three checks in this exact order, throwing on the first failure. A parent id
that is missing or is not an account throws an unknown-account error; a pocket id already present
anywhere in the money-source table throws an id-collision error; and a parent whose lifecycle is not
active throws an inactive-reference error carrying the parent id. The pocket SHALL be stored and its id
added to the parent's pocket links. The returned changes SHALL be the pocket upsert followed by the
parent account upsert, in that order.

The lifecycle check exists because no mutator may leave an active pocket owned by a non-active account.
That is the orphan-active-pocket family the restore path also closes: an archived or reference-only
account is unselectable, so a live pocket hanging from one is unreachable through the account it belongs
to, and a reference-only account is a row already on its way out once its last pocket goes. Adding under
a non-active parent is the fourth and last public route into that state, and it is closed here rather
than repaired afterwards.

#### Scenario: Adding under a non-active parent is rejected

- **WHEN** a pocket is added to an archived or reference-only account
- **THEN** an inactive-reference error carrying the parent id is thrown and neither the pocket nor the
  parent's links change

Updating a pocket SHALL reject an id that is missing or resolves to an account, with an unknown-holder
error, and SHALL replace the stored pocket wholesale. The parent link SHALL be untouched, since it
lives on the parent. It SHALL return a single pocket upsert.

#### Scenario: Parent check precedes collision check

- **WHEN** a pocket is added with a colliding id under a missing parent
- **THEN** the unknown-account error is thrown, not the id-collision error

#### Scenario: Pocket attaches to its parent

- **WHEN** a pocket is added to an existing account
- **THEN** the pocket is stored, the parent's links contain it, and the changes are the pocket upsert
  then the parent upsert

### Requirement: Entry validation

Validating an entry, optionally against the entry it replaces, SHALL apply the following checks in this
exact order, throwing on the first failure. The order is observable and SHALL NOT be rearranged.

1. An amount of exactly zero SHALL throw a zero-amount error.
2. A source id absent from the money-source table SHALL throw an unknown-holder error.
3. A source that was not already referenced by the replaced entry and whose lifecycle is not active
   SHALL throw an inactive-reference error carrying the source id. A holder the entry already
   referenced stays usable even once archived, so editing an old entry is never blocked by a later
   lifecycle change.
4. When a category id is present: a category absent from the category table SHALL throw an
   unknown-category error; a transfer carrying any category SHALL throw a category-kind mismatch; a
   category whose kind disagrees with the kind implied by the entry's sign SHALL throw a category-kind
   mismatch; and a newly introduced category reference — one that differs from the replaced entry's
   category, including on add — whose category is not active SHALL throw an inactive-reference error.
5. An entry with no destination SHALL be stored as given.
6. A destination id absent from the money-source table SHALL throw an unknown-holder error.
7. A destination equal to the source SHALL throw a self-transfer error.
8. A destination that was not already referenced by the replaced entry and whose lifecycle is not
   active SHALL throw an inactive-reference error carrying the destination id.
9. A transfer with a negative amount SHALL be stored with the amount negated and the source and
   destination exchanged, every other field unchanged. A stored transfer therefore always carries a
   positive amount. A positive transfer SHALL be stored unchanged.

#### Scenario: Zero amount precedes holder lookup

- **WHEN** an entry with a zero amount and an unknown source is validated
- **THEN** the zero-amount error is thrown

#### Scenario: Category checks precede destination checks

- **WHEN** a transfer carries both a category and an unknown destination
- **THEN** the category-kind mismatch is thrown

#### Scenario: Prior reference exempts an archived source

- **WHEN** an entry whose source has since been archived is edited without retargeting
- **THEN** validation passes

#### Scenario: Prior reference is per reference

- **WHEN** an entry whose source is archived is retargeted to an archived destination
- **THEN** an inactive-reference error carrying the destination id is thrown

#### Scenario: Keeping an archived category is exempt

- **WHEN** an entry keeps its category, which has since been archived, and edits another field
- **THEN** validation passes

#### Scenario: Switching to an inactive category is rejected

- **WHEN** an entry is retargeted to a different category that is not active
- **THEN** an inactive-reference error carrying that category id is thrown

#### Scenario: Negative transfer is normalized

- **WHEN** a transfer of a negative amount from one holder to another is validated
- **THEN** the stored entry carries the positive amount with source and destination exchanged

### Requirement: Add, update and delete an entry

Adding an entry SHALL reject an id already present in the entry table with an id-collision error, then
validate it, then store and return an upsert of the validated entry.

Updating an entry SHALL reject a missing id with an unknown-entry error, validate the new entry against
the stored one, and replace it. Because retargeting can drop the last reference to a reference-only
holder or category, the update SHALL then run the dereference sweep over the holders the entry no longer
references and over its former category when the category changed. The returned changes SHALL be the
entry upsert followed by any sweep changes; when nothing was dropped the list is exactly the one upsert.

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

### Requirement: Set an opening balance

Setting an opening balance for a holder SHALL reject a missing holder with an unknown-holder error.
An amount of exactly zero SHALL then be a no-op returning no changes — the holder check comes first, so
a zero amount against an unknown holder still throws.

Otherwise it SHALL add an entry with a fresh id, the given date defaulting to now, the given amount with
its sign preserved, the name "Opening balance", no category, no destination, and excluded from analysis.
It SHALL return that add's changes.

#### Scenario: Unknown holder throws even at zero

- **WHEN** an opening balance of zero is set on an unknown holder
- **THEN** an unknown-holder error is thrown

#### Scenario: Zero records nothing

- **WHEN** an opening balance of zero is set on a known holder
- **THEN** no entry is created and no change is returned

#### Scenario: Opening balance is excluded from analysis

- **WHEN** a non-zero opening balance is set
- **THEN** the stored entry carries the amount, has no category, and is excluded from analysis

### Requirement: Add and update a category

Adding a category SHALL reject an id already present with an id-collision error; updating SHALL reject a
missing id with an unknown-category error.

When a parent is given, both SHALL apply the same checks in this order: a parent absent from the
category table throws an unknown-category error; a parent that itself has a parent throws a
category-too-deep error, capping nesting at two levels; and a parent whose kind differs from the
category's kind throws a category-kind mismatch; and a parent that is reference-only or tombstoned
throws an inactive-reference error carrying the parent id. An ARCHIVED parent SHALL be permitted, so an
active child may be added under one.

The archived case is deliberately the opposite of the pocket rule above, and the difference is in what a
non-active parent does to its children. A pocket is a holder: it carries entries and is reached through
the account that owns it, so an active pocket under a non-active account is unreachable and its parent
may already be a row awaiting removal. A category is a classification label whose parent is only a
naming ancestor, holding no balance and owning nothing. An archived parent therefore costs an active
child nothing, and the purge cascade already sweeps children regardless of their lifecycle, so no active
child can outlive the parent row it hangs from.

A reference-only parent is different again, and is rejected for a reason the archived case does not
share. The dereference sweep deletes a reference-only category outright as soon as its last entry goes,
and unlike the purge cascade it does not look for children, so a child added under one would be left
naming a row that no longer exists. Invariant clause 5 forbids the resulting state, so the write path
refuses to create it.

#### Scenario: Adding under a reference-only parent is rejected

- **WHEN** a category is added or reparented under a reference-only parent
- **THEN** an inactive-reference error carrying the parent id is thrown and the category table is
  unchanged

Updating SHALL reject any change to the category's kind with a category-kind mismatch; a kind left
unchanged is always permitted. Otherwise the category SHALL be stored verbatim and a category upsert
returned.

When an update moves the category to a different parent, the ABANDONED parent SHALL be re-judged by the
dereference sweep and any resulting changes appended after the upsert. A reference-only parent whose
only claim to being referenced was the departing child's link is otherwise left behind unreferenced,
violating invariant clause 11. This mirrors the sweep an entry update already performs for a holder or
category it drops.

PORT FIX: the Swift `updateCategory` stores the category verbatim, so a kind may be swapped after
creation. Nothing propagates the new kind to the category's children, and nothing revisits the entries
already filed under it, so a single edit can strand entries whose sign contradicts their category and
children whose kind no longer matches their parent. Both write-time surfaces, `addEntry` and the plan
template check, already enforce the kind rule, making the edit surface the one door left open. Guarding
on existing references would not close it, since a parent with children breaks the nesting rule even
with no entries anywhere. The port therefore fixes the kind at creation: a user who wants a different
kind creates a new category, and the existing delete and purge paths handle the old one.

#### Scenario: Changing a category's kind is rejected

- **WHEN** an existing category is updated with a kind differing from the stored one
- **THEN** a category-kind mismatch is thrown and the stored category is unchanged

#### Scenario: Third nesting level is rejected

- **WHEN** a category is added whose parent already has a parent
- **THEN** a category-too-deep error is thrown

#### Scenario: Child kind must match its parent

- **WHEN** an income category is added under an expense parent
- **THEN** a category-kind mismatch is thrown

#### Scenario: Update replaces fields in place

- **WHEN** an existing category is updated
- **THEN** its fields are replaced and the category count is unchanged
