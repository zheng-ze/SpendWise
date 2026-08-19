# ledger-analysis Specification

## Purpose
Defines how entries become analysis items — which entries qualify, which bucket each falls into, and
how the resulting items are filtered, totalled and rolled up for reporting.

Classification is a single window-independent pass so that it can be computed once and cached, with
every window and category view derived cheaply from its result.

## ADDED Requirements
### Requirement: Analysis classification pass

Analysis SHALL be produced by one pass over every entry in the ledger, mapping each through
classification and dropping those that do not qualify. The pass SHALL apply the accounting entry gate
using the existence set of holders, and SHALL drop any entry not flagged for inclusion in analysis.

The order of the resulting items is unspecified.

#### Scenario: Excluded entry produces nothing

- **WHEN** an entry is flagged out of analysis
- **THEN** no analysis item is produced for it

### Requirement: Analysis item shape

An analysis item SHALL carry a bucket, an amount, a date and a kind. Its amount SHALL always be
positive, and its kind SHALL be decided by the sign of the entry's **stored** amount before the
absolute value is taken. A null bucket SHALL mean the Uncategorized bucket.

#### Scenario: Expense yields a positive amount

- **WHEN** an expense entry with a negative stored amount is classified
- **THEN** the item's amount is the absolute value and its kind is expense

#### Scenario: Income and expense are tagged apart

- **WHEN** a ledger holds both income and expense entries
- **THEN** each item carries the kind matching its entry's sign, and totals of one kind exclude the
  other

### Requirement: Transfer classification

A plain transfer SHALL NOT produce an analysis item. A transfer SHALL produce one only when its
destination holder exists and is flagged to treat incoming transfers as expenses; that item SHALL
carry the transfer's stored amount, no category, and the expense kind.

#### Scenario: Plain transfer is invisible to analysis

- **WHEN** money moves between two ordinary holders
- **THEN** no analysis item is produced

#### Scenario: Transfer into a treat-as-expense holder counts

- **WHEN** a transfer lands in a holder flagged to treat incoming transfers as expenses
- **THEN** an expense item is produced with no category

### Requirement: Category resolution

Resolving an entry's category SHALL yield one of three outcomes: excluded from analysis entirely,
Uncategorized, or a specific category. The outcomes SHALL be distinguishable as separate cases rather
than encoded as an absent value, since "excluded" and "Uncategorized" are different results.

Resolution SHALL apply in order: an entry with no category is Uncategorized; a category id absent from
the ledger is Uncategorized rather than an error; a category flagged out of analysis is excluded; a
category whose parent is flagged out of analysis is excluded even when the child itself is included;
otherwise the entry resolves to its own category.

An archived category SHALL NOT be special-cased — entries still bucket under it. Only true absence
from the ledger falls back to Uncategorized.

#### Scenario: Excluded category hides its entries

- **WHEN** a category is flagged out of analysis
- **THEN** entries in it produce no analysis items

#### Scenario: Excluded parent hides its children

- **WHEN** a parent category is flagged out of analysis and its child is not
- **THEN** entries in the child still produce no analysis items

#### Scenario: Missing category degrades gracefully

- **WHEN** an entry names a category that is no longer in the ledger
- **THEN** it is reported as Uncategorized rather than failing

#### Scenario: Archived category keeps its bucket

- **WHEN** a category is archived but still present
- **THEN** its entries continue to bucket under it

### Requirement: Filtering and totals

Analysis items SHALL be filterable by kind, by a set of buckets, and by a date window, with any
omitted constraint meaning no constraint. The bucket set SHALL accept the null bucket so that
Uncategorized is selectable alongside real categories. A total SHALL be the sum of the amounts
surviving the same filters, and SHALL be zero when nothing survives.

Date windows SHALL be half-open — an item on the start instant is included and one on the end instant
is not — so that adjacent windows never double-count a boundary item.

#### Scenario: Boundary item lands in exactly one window

- **WHEN** an item falls exactly on the instant shared by two adjacent windows
- **THEN** it is counted in the later window only

#### Scenario: Uncategorized is selectable

- **WHEN** a filter names the null bucket
- **THEN** items with no category are returned

### Requirement: Roll-up to main buckets

Items SHALL be foldable into main buckets, where an item's main bucket is its category's parent when
it has one and the category itself otherwise. An item with no category, or one naming a category
absent from the ledger, SHALL remain in its own null bucket.

A roll-up SHALL sum item amounts by main bucket.

#### Scenario: Child folds into parent

- **WHEN** spending is recorded against both a parent category and its child
- **THEN** the parent's rolled-up total is the sum of the two

#### Scenario: Uncategorized forms its own bucket

- **WHEN** items without a category are rolled up
- **THEN** they total under a bucket distinct from every category
