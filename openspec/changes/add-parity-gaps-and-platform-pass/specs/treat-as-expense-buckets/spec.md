# treat-as-expense-buckets Specification

## Purpose
Defines where a transfer counted as spending actually lands in analysis: a bucket named for the kind
of destination it went to, rather than a single undifferentiated pile.

## ADDED Requirements
### Requirement: Eligible account types

Two account types SHALL be added for destinations that represent money leaving the user's control —
a loan and an overdraft. They SHALL be appended to the existing type list so that every stored type
code keeps its current meaning.

Only eligible types SHALL be allowed to treat incoming transfers as expenses. Everyday spending
holders — cash, checking, card and prepaid — SHALL NOT be eligible, and the flag SHALL be forced off
when such a type is saved.

#### Scenario: Existing codes are unchanged

- **WHEN** data written before this change is loaded
- **THEN** every account keeps the type it had

#### Scenario: Changing to an ineligible type

- **WHEN** an account with the flag set is changed to an ineligible type
- **THEN** the flag is turned off on save

### Requirement: Bucketing by destination type

A transfer counted as an expense SHALL be bucketed by the **type** of its destination account, not by
the destination's name and not into the uncategorized bucket.

Where the destination is a pocket, the type SHALL be that of its parent account.

Each type's bucket SHALL have a deterministic synthetic identity, so that the same type always
produces the same bucket without storing one.

#### Scenario: Two accounts of one type

- **WHEN** transfers go to two different accounts of the same eligible type
- **THEN** they land in the same bucket

#### Scenario: Transfer into a pocket

- **WHEN** a transfer lands in a pocket of an eligible account
- **THEN** it is bucketed by the parent account's type

### Requirement: These buckets are expense-only

Synthetic type buckets SHALL appear only in expense analysis. A transfer SHALL never produce an
income item through this mechanism.

#### Scenario: Income view excludes them

- **WHEN** income analysis is viewed
- **THEN** no synthetic type bucket appears

### Requirement: Presentation of synthetic slices

A synthetic bucket's slice SHALL carry its own name and symbol rather than borrowing a category's,
SHALL render in a neutral color, and SHALL NOT be navigable — there is no category behind it to open.

#### Scenario: Tapping a synthetic slice

- **WHEN** a synthetic type slice is tapped in the legend
- **THEN** nothing is pushed
