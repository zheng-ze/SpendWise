# ledger-accounting Specification

## Purpose
Defines the derived money math over a ledger: which entries count, what a holder's balance is, what an
account totals once its pockets are folded in, and how those totals split into net worth.

Balances are always recomputed from the entry log and never stored, so that an edit to any entry is
reflected everywhere without a reconciliation step.

## ADDED Requirements
### Requirement: Entry gating

An entry SHALL be counted only when its source holder is present in the supplied id set. A transfer
SHALL be counted only when **both** of its endpoints are present; an entry with no destination
qualifies on its source alone.

Callers SHALL supply the existence set — every holder the ledger knows, archived and reference-only
rows included — rather than the active set. Removing a holder from the ledger entirely is therefore
what un-applies its entries, and archiving one is not.

#### Scenario: Transfer to a removed holder stops counting

- **WHEN** one endpoint of a transfer is no longer present in the ledger
- **THEN** the transfer stops applying, and the surviving endpoint's balance returns to what it was
  before the transfer

#### Scenario: Archived holder still counts

- **WHEN** a holder is archived but still present in the ledger
- **THEN** its entries continue to apply

### Requirement: Holder balance

A holder's balance SHALL be the sum, over every applying entry, of that entry's effect on it: a
transfer contributes its amount to the destination and the negation of its amount to the source, while
a non-transfer contributes its stored signed amount to its source and nothing to any other holder.

Expense amounts are stored negative, so summing the stored sign requires no per-kind branching.

#### Scenario: Balance nets signed entries

- **WHEN** a holder has both income and expense entries
- **THEN** its balance is their signed sum

#### Scenario: An entry moves only its own holder

- **WHEN** a non-transfer entry is recorded against one holder
- **THEN** no other holder's balance changes

#### Scenario: A transfer moves both endpoints

- **WHEN** a transfer is recorded between two holders
- **THEN** the destination rises by the amount and the source falls by the same amount

### Requirement: Account total

An account's total SHALL be its own balance plus the balance of each of its sub-pockets that is
currently active. Pockets that are archived SHALL be excluded from the total while remaining linked to
the account, so that restoring one brings its balance back.

#### Scenario: Funding a pocket is total-neutral

- **WHEN** money moves from an account into one of its own pockets
- **THEN** the pocket's balance rises, and the account's total is unchanged

#### Scenario: Spending from a pocket reduces the total

- **WHEN** an expense is recorded against a pocket
- **THEN** both the pocket's balance and the parent account's total fall

#### Scenario: Archived pocket drops out

- **WHEN** a pocket holding money is archived
- **THEN** the parent account's total falls by that pocket's balance, and the pocket stays linked to
  the account

### Requirement: Net worth

Net worth SHALL be reported as an asset figure and a liability figure, computed over accounts only.
An account SHALL be included only when it is active and flagged for inclusion in net worth.

Each included account's total SHALL be assigned by the **sign of that total**, not by the account's
type: a negative total adds its magnitude to liability, and a zero or positive total adds to asset.
Liability SHALL be carried as a positive magnitude.

Pockets SHALL NOT be counted at top level; their money enters only through their parent account's
total, since money set aside in a pocket still belongs to the account.

#### Scenario: Sign decides the side

- **WHEN** an account of any type has a negative total
- **THEN** its magnitude is reported as liability rather than asset

#### Scenario: Excluded account is skipped

- **WHEN** an account is not flagged for inclusion in net worth
- **THEN** it contributes to neither figure

#### Scenario: Archived account is skipped

- **WHEN** an account is archived
- **THEN** it contributes to neither figure, while still counting as an endpoint for transfers

#### Scenario: Transfer between accounts is neutral

- **WHEN** money moves between two included accounts
- **THEN** neither figure changes

#### Scenario: Empty ledger

- **WHEN** the ledger holds no accounts
- **THEN** both asset and liability are zero
