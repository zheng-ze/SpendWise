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

A subcategory's budget SHALL be grouped next to its parent category's name in the list order and
shown visually indented, even when the parent itself carries no budget, so a user can see which
budgets belong to the same category tree at a glance.

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

#### Scenario: A subcategory's budget is grouped under its parent's name

- **WHEN** the Budgets view lists a budget on a subcategory
- **THEN** it appears next to any budget on that subcategory's parent (or where the parent would
  sort, if the parent has no budget of its own), indented to show the grouping

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

The category picker SHALL offer any active expense category, top-level or subcategory, plus
"Overall", and SHALL exclude a category that already has a budget, since a category may carry at
most one. Income categories SHALL NOT appear, since a budget only ever tracks expense spend.
Rollover mode and category SHALL NOT be editable after creation; changing either requires deleting
and recreating the budget.

Any rejection from the domain layer (unknown budget, category already budgeted, invalid carry
cap, non-positive amount) SHALL be shown to the user in place, without losing the form's entered
values.

#### Scenario: Category already budgeted is excluded from the picker

- **WHEN** the user opens the category picker while creating a budget
- **THEN** categories that already carry a budget do not appear as choices

#### Scenario: Income categories are excluded from the picker

- **WHEN** the user opens the category picker
- **THEN** only expense categories appear as choices; no income category is offered

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

### Requirement: Budget card shows percent of limit, including overshoot

Each budget row in the Budgets view SHALL show a horizontal bar filled to the fraction of limit
spent (capped visually at full width past 100%), labeled with the percent of limit spent (which
MAY exceed 100%), and SHALL show the amount remaining as a signed figure, negative when over
limit.

#### Scenario: A budget under its limit shows remaining as positive

- **WHEN** spend is less than the limit
- **THEN** the remaining figure is shown as a positive amount

#### Scenario: A budget over its limit shows remaining as negative

- **WHEN** spend exceeds the limit
- **THEN** the bar fills fully, the percent label reads over 100%, and the remaining figure is
  shown as a negative amount

### Requirement: Tapping a budget opens its detail screen

Tapping a budget row SHALL open a detail screen scoped to that budget: a category budget scopes to
that category and its children, matching the spend rule in "Budgets list shows configured limit
against spend"; an overall budget scopes to every expense entry.

The detail screen SHALL show, for one calendar year at a time, actual spend as a bar per month
overlaid with a line connecting one dot per month, each dot placed at that month's effective limit
(so a limit change from an override or a new default is visible as a change in the line's slope
between two months). Each dot SHALL align with the horizontal center of that month's bar. A year
selector SHALL let the user move to an adjacent year; moving to a year SHALL keep the same selected
month number in the newly displayed year (e.g. March stays selected when moving from 2025 to
2026), so the entry list stays on the month the user was already looking at.

Every month SHALL be selectable, including one with zero spend — a month is never skipped or made
unselectable because it has nothing to show.

Selecting a month SHALL filter an entry list below the chart to that month's entries within the
budget's scope, and SHALL NOT change which year the chart displays, move any bar's screen
position, or change which months are tappable — tapping a month affects only which month is
selected, never which year is displayed.

The detail screen SHALL show a pencil action that opens the budget's month-by-month limit editor
(see "Edit a budget's limit by month"). Reaching this screen any other way (e.g. from a category
in the Stats or Transactions views, if such an entry point exists) SHALL NOT show the pencil
action, since editing limits only makes sense in the budget context.

#### Scenario: Selecting a month filters the entry list without moving the chart

- **WHEN** the user taps a month's bar on the budget detail screen
- **THEN** the entry list below shows only that month's entries within the budget's scope, the
  chart's displayed year is unchanged, and every other month's bar stays in its same screen
  position and remains tappable

#### Scenario: A limit change moves that month's dot, centered on its bar

- **WHEN** a budget's limit changes from one month to the next (default change or override)
- **THEN** that month's dot sits at the new value, centered on that month's bar, connected by a
  straight line to the dot before and after it

#### Scenario: A month with no spend is still selectable

- **WHEN** the user taps a month whose bar shows zero spend
- **THEN** that month becomes the selected month, the same as tapping any other month

#### Scenario: An overall budget's detail screen scopes to every expense

- **WHEN** the user opens the detail screen for an overall budget
- **THEN** the chart and entry list include every expense entry, not just one category

#### Scenario: Changing the year keeps the same selected month

- **WHEN** the user moves to an adjacent year via the year selector
- **THEN** the chart shows that year's twelve months and the selected month keeps its month number,
  now in the newly displayed year

### Requirement: A budget's default limit is edited separately from any month's figure

A budget's default limit (the `defaultLimit` event with no month-specific override in play) SHALL
be editable as its own action, distinct from editing any single month's effective limit. Changing
the default SHALL take effect starting the next calendar month, never the current one, so a
default change never silently rewrites what the user is already spending against this month.

#### Scenario: Editing the default limit does not change the current month's figure

- **WHEN** the user changes the default limit while the current month has no override of its own
- **THEN** the current month's effective limit is unchanged, and the new default applies starting
  next month

#### Scenario: The default limit is shown independent of any selected year or month

- **WHEN** the user opens the budget's limit editor
- **THEN** the default limit is shown as one figure, not tied to whichever year is currently
  displayed

### Requirement: Edit a budget's limit by month, one year at a time

From a budget's detail screen, a user SHALL be able to open a month-by-month view of that
budget's limit history: the default limit (editable per "A budget's default limit is edited
separately from any month's figure"), and one calendar year's twelve months, listed latest month
first, each showing its effective limit for that year. A year selector SHALL let the user move to
an adjacent year, rather than showing every month across every year on one page. Selecting a month
SHALL let the user set an override for that month, following the same validation and rejection
handling as "Create and edit a budget".

#### Scenario: The month editor shows one year at a time, latest month first

- **WHEN** the user opens the month-by-month limit editor
- **THEN** it shows the twelve months of one calendar year in descending order (December down to
  January), not a flat list spanning multiple years

#### Scenario: Setting an override from the month editor updates that month's figure

- **WHEN** the user sets an override for a specific month from the month editor
- **THEN** that month's row reflects the new value, and the budget detail screen's trend line
  steps to it for that month
