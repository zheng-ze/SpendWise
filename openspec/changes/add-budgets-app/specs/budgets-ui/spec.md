## Purpose

Lets a user see how their spending compares to a limit they set, and create, edit, or delete that
limit, with the configuration surviving an app restart.

## ADDED Requirements

### Requirement: Budgets survive restart

A budget created, updated, or deleted SHALL be persisted, and SHALL be present (or absent, for a
delete) in the state loaded on the next app launch, with every field — category, limit history,
rollover mode, carry cap — unchanged from what was last saved.

#### Scenario: A created budget survives restart

- **WHEN** a budget is created and the app is relaunched
- **THEN** the budget appears with the same category, limit, and rollover mode it was created with

#### Scenario: A deleted budget stays gone after restart

- **WHEN** a budget is deleted and the app is relaunched
- **THEN** the budget does not appear in the loaded state

#### Scenario: A month override survives restart

- **WHEN** a budget is given a one-month override and the app is relaunched
- **THEN** the effective limit for that month still reflects the override

### Requirement: Budgets list shows configured limit against spend

The Budgets view SHALL list every budget for the selected month, each showing its category (or
"Overall" for a null-category budget), its effective limit for that month, and the amount spent
against it. Spend SHALL be computed from existing entries for the selected month, not stored on
the budget itself.

A category budget can be set on a top-level category or a subcategory. Its spend SHALL include
spend in that category itself and, if it has children, spend in those children. A subcategory's
spend SHALL count toward its own budget and its parent's budget independently when both exist —
the two totals are separate limits and are allowed to overlap, not deduplicated against each
other. An overall budget's spend SHALL include every expense entry in the month, categorized or
not.

If a budget's category has since been deleted, the view SHALL still show the budget with a clear
indication its category is gone, rather than failing to render or crashing.

#### Scenario: Category budget spend includes child categories

- **WHEN** a budget is set on a category and the user spends in one of its child categories that
  month
- **THEN** the child's spend counts toward that budget's spend total

#### Scenario: A subcategory's spend counts toward both its own and its parent's budget

- **WHEN** both a subcategory and its parent category have a budget, and the user spends in the
  subcategory that month
- **THEN** the spend appears in both budgets' totals independently

#### Scenario: A budget survives its category being deleted

- **WHEN** the category a budget is set on is deleted
- **THEN** the budget still appears in the Budgets view, indicating its category is gone, until the
  category-tombstone cascade removes the budget entirely

#### Scenario: The year-range toggle does not apply to budgets

- **WHEN** the user is on the Budgets segment
- **THEN** there is no control to switch to a year range; figures are always for the selected month

#### Scenario: No budgets configured

- **WHEN** the user opens the Budgets view with no budgets created
- **THEN** the view explains how to create one instead of showing an empty list

#### Scenario: Changing the selected month updates every budget's figures

- **WHEN** the user changes the selected month
- **THEN** every listed budget's effective limit and spend total recompute for the new month

### Requirement: Create and edit a budget

A user SHALL be able to create a budget by choosing a category (or "Overall") and an initial
limit, and choosing a rollover mode at creation. A user SHALL be able to change a budget's limit,
taking effect either immediately or from a chosen future month, and set or clear a one-month
override.

The category picker SHALL offer any active category, top-level or subcategory, plus "Overall", and
SHALL exclude a category that already has a budget, since a category may carry at most one.
Rollover mode and category SHALL NOT be editable after creation; changing either requires deleting
and recreating the budget.

Any rejection from the domain layer (unknown budget, category already budgeted, invalid carry
cap, non-positive amount) SHALL be shown to the user in place, without losing the form's entered
values.

#### Scenario: Category already budgeted is excluded from the picker

- **WHEN** the user opens the category picker while creating a budget
- **THEN** categories that already carry a budget do not appear as choices

#### Scenario: A subcategory can be budgeted even when its parent already is

- **WHEN** the user opens the category picker and the parent of an unbudgeted subcategory already
  has a budget
- **THEN** the subcategory still appears as a choice

#### Scenario: A rejected save keeps the form's entered values

- **WHEN** saving a budget is rejected by the domain layer
- **THEN** the error is shown and the form's fields keep what the user entered

#### Scenario: Rollover mode is fixed after creation

- **WHEN** the user edits an existing budget
- **THEN** the rollover mode and category are shown but not editable

### Requirement: Delete a budget

A user SHALL be able to delete a budget from the Budgets view. Deleting a budget SHALL only remove
the budget configuration; it SHALL NOT alter any entry or category.

#### Scenario: Deleting a budget leaves entries untouched

- **WHEN** a budget is deleted
- **THEN** every entry previously counted toward its spend total is unchanged
