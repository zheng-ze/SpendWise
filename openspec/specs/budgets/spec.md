# budgets Specification

## Purpose
Lets a user cap monthly spending against a limit, either for one category or across every
category, with a history of how that limit changed over time and an optional carry of unused or
overspent amounts into the next month.
## Requirements
### Requirement: Create a budget
The system SHALL let a user create a budget naming a single category, or no category to cover
every category, a positive starting monthly limit, and a rollover mode. At most one budget may
exist for a given category, and at most one budget may exist with no category at a time.

#### Scenario: Budget created for a category
- **WHEN** a user creates a budget on an existing, active category with a positive limit
- **THEN** the system creates the budget and that limit applies to every month up to and including
  the month of creation, with no lower bound

#### Scenario: Budget created with no category
- **WHEN** a user creates a budget naming no category
- **THEN** the system creates a budget covering every category

#### Scenario: Duplicate category rejected
- **WHEN** a user creates a budget on a category that already has a budget
- **THEN** the system rejects the request and no budget is created

#### Scenario: Second no-category budget rejected
- **WHEN** a user creates a budget naming no category while one already exists
- **THEN** the system rejects the request and no budget is created

#### Scenario: Non-positive limit rejected
- **WHEN** a user creates a budget with a limit that is zero or negative
- **THEN** the system rejects the request and no budget is created

#### Scenario: Inactive or unknown category rejected
- **WHEN** a user creates a budget naming a category that does not exist or has been deleted
- **THEN** the system rejects the request and no budget is created

### Requirement: Retroactive limit at creation
A budget's starting limit SHALL apply to every past month for its category, with no earliest
month enforced, so that activity recorded before the budget was created — including activity
added after the budget already exists — is still covered.

#### Scenario: Backfilled entry still covered
- **WHEN** a user creates a budget and later adds an entry dated before the budget's creation
- **THEN** the budget's starting limit still applies to the month that entry falls in

### Requirement: Change the monthly limit going forward
The system SHALL let a user change a budget's monthly limit, effective from a chosen month
onward. Changing the limit SHALL NOT alter any month that already resolved to a different limit,
whether from an earlier default or from that month's own override.

#### Scenario: Limit change applies only from its effective month forward
- **WHEN** a user changes a budget's limit to take effect starting a given month
- **THEN** every month at or after that month resolves to the new limit, and every month before it
  keeps resolving to whatever it resolved to previously

### Requirement: Override a single month's limit
The system SHALL let a user set a limit for one specific month that overrides whatever the
budget's ongoing default would otherwise resolve to for that month. An override SHALL take
priority over the default for its month regardless of any default change made before or after the
override.

#### Scenario: Override wins over the default
- **WHEN** a user sets an override for a specific month
- **THEN** that month resolves to the override's value, not the default's

#### Scenario: Later default change does not disturb an overridden month
- **WHEN** a user changes the ongoing default limit after a month already has an override
- **THEN** the overridden month keeps resolving to its override, not the new default

#### Scenario: A new override on the same month replaces the previous one
- **WHEN** a user sets an override for a month that already has an override
- **THEN** the month resolves to the most recently set override's value

### Requirement: Category and rollover mode are fixed at creation
The system SHALL NOT let a user change a budget's category or rollover mode after creation. A
user who wants a different category or rollover mode SHALL delete the budget and create a new
one.

#### Scenario: Category cannot be changed
- **WHEN** a user attempts to change an existing budget's category
- **THEN** the system rejects the request

#### Scenario: Rollover mode cannot be changed
- **WHEN** a user attempts to change an existing budget's rollover mode
- **THEN** the system rejects the request

### Requirement: Rollover carry cap
A budget with a rollover mode other than none SHALL let a user set an optional cap on how much
unused or overspent amount can carry into a following month. The cap, once set at creation, SHALL
NOT change afterward. A cap SHALL be either unset (no limit on carry) or a positive amount; a cap
of zero SHALL be rejected, since it would be indistinguishable from no rollover at all. A budget
with rollover mode none SHALL NOT have a carry cap.

#### Scenario: Cap accepted at creation
- **WHEN** a user creates a rollover-enabled budget with a positive carry cap
- **THEN** the system creates the budget with that cap in effect for every month going forward

#### Scenario: Zero cap rejected
- **WHEN** a user creates a rollover-enabled budget with a carry cap of zero
- **THEN** the system rejects the request and no budget is created

#### Scenario: Carry cap rejected when rollover is off
- **WHEN** a user creates a budget with rollover mode none and specifies a carry cap
- **THEN** the system rejects the request and no budget is created

### Requirement: Delete a budget
The system SHALL let a user delete a budget outright. Deleting a budget SHALL remove its entire
history; nothing else in the system references a budget, so nothing needs to account for a
deleted one continuing to exist in any form.

#### Scenario: Budget deleted
- **WHEN** a user deletes an existing budget
- **THEN** the budget and its full limit history are removed, and no trace of it remains

### Requirement: Deleting a category removes its budget
When a category that a budget names is deleted, the system SHALL delete that budget as part of
the same operation. Deleting a category that is a parent of a budgeted category, without deleting
the budgeted category itself, SHALL NOT delete that budget.

#### Scenario: Budgeted category deleted
- **WHEN** a user deletes a category that has a budget
- **THEN** the system deletes that budget along with the category

#### Scenario: Deleting an unrelated or descendant category leaves the budget intact
- **WHEN** a user deletes a category that is not the exact category a budget names
- **THEN** that budget is unaffected, even if the deleted category is a child of the budget's
  category

