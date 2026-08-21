## MODIFIED Requirements

### Requirement: Entry gating

An entry SHALL be counted only when its source holder is present in the supplied id set. A transfer
SHALL be counted only when **both** of its endpoints are present; an entry with no destination
qualifies on its source alone.

Callers SHALL supply the existence set — every holder the ledger knows, archived and reference-only
rows included — rather than the active set. Removing a holder from the ledger entirely is therefore
what un-applies its entries, and archiving one is not.

This gate applies uniformly to every derived money calculation defined in this capability,
including a window's income/expense totals, not only to a holder's balance or to per-entry
classification.

#### Scenario: Transfer to a removed holder stops counting

- **WHEN** one endpoint of a transfer is no longer present in the ledger
- **THEN** the transfer stops applying, and the surviving endpoint's balance returns to what it was
  before the transfer

#### Scenario: Archived holder still counts

- **WHEN** a holder is archived but still present in the ledger
- **THEN** its entries continue to apply

#### Scenario: Removed holder stops counting toward income/expense totals

- **WHEN** an entry's source holder, or a transfer's destination holder, is no longer present in
  the ledger
- **THEN** that entry contributes nothing to a window's income/expense totals, consistent with
  its exclusion from per-entry classification
