# ledger-analysis Specification

## MODIFIED Requirements
### Requirement: Transfer classification

A plain transfer SHALL NOT produce an analysis item. A transfer SHALL produce one only when its
destination holder exists and is flagged to treat incoming transfers as expenses; that item SHALL
carry the transfer's stored amount and the expense kind.

Such an item SHALL be bucketed by the **type** of its destination account, using that type's
synthetic bucket, rather than carrying no category and falling into the uncategorized bucket. Where
the destination is a pocket, the parent account's type SHALL be used.

#### Scenario: Plain transfer is invisible to analysis

- **WHEN** money moves between two ordinary holders
- **THEN** no analysis item is produced

#### Scenario: Transfer into a treat-as-expense holder counts

- **WHEN** a transfer lands in a holder flagged to treat incoming transfers as expenses
- **THEN** an expense item is produced in that destination type's bucket

#### Scenario: No longer uncategorized

- **WHEN** a transfer counted as an expense is classified
- **THEN** it does not appear in the uncategorized bucket
