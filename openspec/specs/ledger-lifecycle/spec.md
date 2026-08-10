# ledger-lifecycle Specification

## Purpose
Governs how ledger rows leave and re-enter circulation — archiving, restoring, permanent purge, and the
reference rules that decide whether a purged row survives as a name-resolving stub or disappears
entirely, without ever destroying entry history.
## Requirements
### Requirement: Lifecycle machine

A money source or category SHALL move through the lifecycle states active, archived, reference-only and
tombstoned under these rules:

- Deleting a holder or category archives it. Nothing is removed and entries are always retained; only
  entries hard-delete.
- Restoring an archived row returns it to active.
- Purging an archived row forks: a referenced row becomes reference-only, an unreferenced row is
  tombstoned, meaning its row is removed from its table.
- Reference-only is terminal but one: there is no restore from it, and its only exit is tombstoning by
  the dereference sweep when the last referencing entry is deleted or retargeted away.
- Every stored entry is active; an entry is either present or gone.

#### Scenario: Delete never removes a holder

- **WHEN** an account with entries is deleted
- **THEN** the account is archived, its row remains, and every entry is retained

#### Scenario: Reference-only has no restore

- **WHEN** a restore is attempted on a reference-only row
- **THEN** it is a no-op returning no changes

### Requirement: Archive an account, a pocket or a category

Deleting an account SHALL be a no-op unless the id resolves to an account whose lifecycle is active; a
pocket id or an already-archived account SHALL be ignored. It SHALL archive the account and emit its
upsert, then archive each of its active pockets and emit an upsert for each, leaving non-active pockets
untouched. Pocket links SHALL be kept so that restore can find them. Entries SHALL NOT be touched and no
money-source deletion SHALL be emitted.

Deleting a pocket SHALL be a no-op unless the target is an active pocket. It SHALL archive the pocket
and return that upsert alone; the parent SHALL NOT be re-emitted and the parent's link SHALL be kept.

Deleting a category SHALL be a no-op unless the target is an active category. It SHALL archive the
category, emit its upsert, then archive each of its active children and emit an upsert for each. Entries
SHALL keep their category id and SHALL NOT be rehomed to null.

#### Scenario: Wrong-flavor id is ignored

- **WHEN** an account delete is called with a pocket id, or a pocket delete with an account id
- **THEN** nothing changes and no change is returned

#### Scenario: Archive cascades to active pockets only

- **WHEN** an account with one active and one already-archived pocket is deleted
- **THEN** the account and the active pocket are archived, and the changes contain no money-source
  deletion and no entry change

#### Scenario: Category archive keeps entry references

- **WHEN** a category with children and entries is deleted
- **THEN** the category and its active children are archived and every entry keeps its category id

### Requirement: Restore an account, a pocket or a category

Restoring an account SHALL be a no-op unless the target is an archived account. It SHALL make the
account active, emit its upsert, then make each of its archived pockets active and emit an upsert for
each. Reference-only pockets SHALL be left as they are, having permanently left the bin.

Restoring a pocket SHALL be a no-op unless the target is an archived pocket, and SHALL additionally be a
no-op while the owning account is archived — the account must be restored first. Otherwise the pocket
becomes active and its upsert is returned.

Restoring a category SHALL be a no-op unless the target is an archived category, and SHALL additionally
be a no-op when it has a parent whose lifecycle is archived. Otherwise the category becomes active, its
upsert is emitted, and each archived child becomes active with an upsert emitted for each.

#### Scenario: Pocket restore is blocked by an archived parent

- **WHEN** a pocket restore is attempted while its account is archived
- **THEN** the pocket stays archived and no change is returned

#### Scenario: Archive then restore round-trips the link

- **WHEN** a pocket is archived and then restored through its account
- **THEN** the pocket is active again and the parent's link was never broken

### Requirement: Account reference rule

An account SHALL count as referenced while it has at least one direct entry reference, or at least one
id in its pocket links still present in the money-source table in any lifecycle. A pocket SHALL count as
referenced only by direct entry references.

This corrects a defect in the source implementation, where an account funded solely through its pockets
counted as unreferenced and could be removed while its referenced pockets survived, leaving them owned by
nobody.

#### Scenario: Account is referenced through a surviving pocket

- **WHEN** an account has no direct entry references but a pocket of its own still exists
- **THEN** it counts as referenced

### Requirement: Purge a holder

Purging SHALL never touch entries.

Purging an account SHALL be a no-op unless the target is an archived account. It SHALL purge each of its
pockets first and the account last, so that each pocket's survival is settled before the account's
referencedness is evaluated. The change list SHALL carry all pocket-purge changes before the account's.

Purging a pocket SHALL be a no-op unless the target is an archived pocket.

Purging a holder SHALL apply this rule: a referenced holder becomes reference-only and its upsert is
emitted; an unreferenced holder is tombstoned, meaning its row is removed and its deletion emitted. A
tombstoned pocket SHALL additionally leave its parent's links in the same mutation, emitting the parent's
upsert before its own deletion, so that no dangling link exists between two changes.

#### Scenario: Referenced holder survives as reference-only

- **WHEN** an archived holder with referencing entries is purged
- **THEN** it becomes reference-only and its row remains

#### Scenario: Unreferenced holder is tombstoned

- **WHEN** an archived holder with no referencing entries is purged
- **THEN** its row is removed and its deletion is emitted

#### Scenario: Pocket detaches atomically

- **WHEN** an unreferenced archived pocket is purged
- **THEN** the parent upsert without the link is emitted before the pocket's deletion

#### Scenario: Account funded only through its pockets survives its own purge

- **WHEN** an account whose only entries reference its pocket is archived and then purged
- **THEN** both the account and the pocket end reference-only and all invariants hold

### Requirement: Purge a category

Purging a category SHALL be a no-op unless the target is an archived category. It SHALL purge the
category row and then every child row, regardless of each child's lifecycle, so that an active child of
an archived parent is purged too.

Each category row SHALL follow this rule: if the category is referenced it becomes reference-only and its
upsert is emitted; otherwise its row is removed and its deletion emitted.

A category SHALL count as referenced when any entry carries its id, **or** when any of its descendant
categories is itself referenced under this same rule. The walk SHALL be guarded against revisiting an id
so that a malformed cycle terminates. The recursion is load-bearing: under a direct-entries-only rule a
parent row would be deleted while a still-referenced child survived pointing at it, leaving a category
with an unknown parent and violating the nesting invariant. Children SHALL therefore sweep before the
parent is judged, so a child kept as reference-only is visible when its parent is weighed, while the
parent's changes are still emitted first.

#### Scenario: Children are purged regardless of lifecycle

- **WHEN** an archived category with an active child is purged
- **THEN** the child is purged under the same rule as the parent

#### Scenario: A referenced child keeps its parent alive

- **WHEN** an archived category is purged whose only entry references a child category rather than the
  parent itself
- **THEN** both the parent and the child end reference-only and all invariants hold

### Requirement: Dereference sweep

Deleting or retargeting an entry SHALL run a dereference sweep over the holders the entry no longer
references and over the category it no longer carries. The sweep is the only path from reference-only to
tombstoned.

The sweep SHALL visit holders first and the category last. For each holder that is stored, is
reference-only, and is now unreferenced under the account reference rule, it SHALL tombstone that holder.
It SHALL NOT tombstone a reference-only account that still has surviving pockets, even at zero direct
references. When a pocket tombstones, its former parent SHALL be re-checked: a parent that is
reference-only, has no direct references and now has no pockets left SHALL be tombstoned in the same
mutation, emitting the parent's detaching upsert, then the pocket's deletion, then the parent's deletion,
in that order.

Then, when the swept category is stored, reference-only, and unreferenced under the recursive rule of the
purge requirement above — carried by no entry and having no referenced descendant — its row SHALL be
removed and its deletion emitted. That removal SHALL then cascade upward: the category's parent may have
been held up solely by the row just removed, so it SHALL be re-judged under the same rule and removed too
if it now qualifies, continuing up the chain. This mirrors the pocket-to-parent re-check on the holder
side.

#### Scenario: Last referencing entry tombstones the holder

- **WHEN** the last entry referencing a reference-only holder is deleted
- **THEN** the holder's row is removed and its deletion is emitted

#### Scenario: Retargeting away tombstones the old holder

- **WHEN** an entry is retargeted off a reference-only holder that no other entry references
- **THEN** the holder is tombstoned and all invariants hold

#### Scenario: Account survives while a pocket is still referenced

- **WHEN** the last entry referencing a reference-only account directly is deleted while a referenced
  pocket of that account survives
- **THEN** the account stays reference-only and the pocket is untouched

#### Scenario: Last pocket tombstone cascades to its parent

- **WHEN** the only remaining entry references a reference-only pocket of a reference-only account and
  that entry is deleted
- **THEN** the changes carry the detaching account upsert, then the pocket deletion, then the account
  deletion, and the money-source table ends empty

#### Scenario: Last child deletion cascades to its parent category

- **WHEN** the only remaining entry carries a reference-only child of a reference-only parent category
  and that entry is deleted
- **THEN** both the child and the parent are removed and their deletions are emitted, child first

