## MODIFIED Requirements

### Requirement: Roll-up to main buckets

Items SHALL be foldable into main buckets, where an item's main bucket is its category's parent when
it has one and the category itself otherwise. An item with no category SHALL remain in its own null
bucket. An item naming a category id absent from the ledger SHALL keep that id as its own bucket
rather than falling back to the null bucket — this is what lets a synthetic bucket, such as one a
treat-as-expense transfer resolves to, roll up to itself instead of collapsing into Uncategorized.

A roll-up SHALL sum item amounts by main bucket.

#### Scenario: Child folds into parent

- **WHEN** spending is recorded against both a parent category and its child
- **THEN** the parent's rolled-up total is the sum of the two

#### Scenario: Uncategorized forms its own bucket

- **WHEN** items without a category are rolled up
- **THEN** they total under a bucket distinct from every category

#### Scenario: A synthetic bucket rolls up to itself

- **WHEN** an item names a bucket id that is not a stored category, such as a treat-as-expense
  transfer's synthetic account-type bucket
- **THEN** the item rolls up under that same bucket id rather than the null bucket
