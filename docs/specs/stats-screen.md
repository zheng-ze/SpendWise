# stats-screen Specification

## Purpose
Defines where spending is understood: how analysis items become proportional slices, what the donut
and legend show, and over what period.

## Requirements

### Requirement: Kind and period selection

The screen SHALL offer income and expense views, defaulting to expense, and a period selection of
month or year. The date selector's label and stepping unit SHALL follow the selected period.

Both controls SHALL be available on every platform. V1 offered them on one platform only, leaving the
others unable to change the period.

The selected date SHALL be held in the same shared month state the rest of the app uses, not in
state private to this screen — so that the month this screen is showing and the month the
transactions screen is showing can be kept in agreement rather than drifting independently.

#### Scenario: Period follows the range

- **WHEN** the annual range is selected
- **THEN** the selector steps by years and the window covers the year

#### Scenario: Selected month is shared

- **WHEN** the shared month state changes from outside this screen
- **THEN** this screen's date selection reflects the new value rather than keeping its own

### Requirement: Analysis source

The screen SHALL read its data from the cached analysis pass rather than scanning entries itself, and
SHALL request a refresh when it appears and re-render when the cache reports new items.

Amounts here are therefore post-gate: category exclusions apply and transfers into treat-as-expense
holders are counted. This screen may consequently disagree with the transactions screen for the same
period.

#### Scenario: Cache updates propagate

- **WHEN** the analysis cache publishes new items
- **THEN** the screen re-renders from them

### Requirement: Total line

The screen SHALL show the total of analysis items of the active kind within the window, labelled for
that kind and colored as a gain for income or a loss for expense.

#### Scenario: Empty period still shows a total

- **WHEN** the window contains no items
- **THEN** the total line shows zero

### Requirement: Slice derivation

Slices SHALL be derived by filtering cached items to the active kind and window, rolling them up to
main buckets so subcategory amounts fold into their parent, and emitting one slice per bucket ordered
by amount descending.

Each slice SHALL carry its fraction of the total. The bucket with no category SHALL be presented as
uncategorized and SHALL include transfers counted as expenses.

A slice's color SHALL come from its category, with uncategorized rendered neutrally.

#### Scenario: Subcategory folds into its parent

- **WHEN** spending exists on both a parent category and its child
- **THEN** one slice carries their combined amount

#### Scenario: Zero total

- **WHEN** the total is zero
- **THEN** fractions are zero rather than undefined

### Requirement: Donut presentation

The donut SHALL render slices in list order starting from the top and proceeding clockwise, separated
by a small gap, with no gap when only one slice exists.

Slices with a zero or negative value SHALL be omitted from the ring.

Each slice SHALL be labelled with its name and rounded percentage, connected by a leader line and
positioned to stay within the canvas.

#### Scenario: Single slice

- **WHEN** only one bucket has value
- **THEN** the ring is drawn without a gap

### Requirement: Empty state

When the window yields no slices, the screen SHALL replace the donut and the legend with an empty
state naming the active kind, while still showing the zero total.

#### Scenario: No expense in the period

- **WHEN** the expense view has no items for the window
- **THEN** an empty state is shown in place of the donut and legend

### Requirement: Legend

The screen SHALL list one row per slice in the same descending order, showing the category icon, the
name, the percentage and the amount.

Tapping a row SHALL open the detail screen for that category. The uncategorized row SHALL NOT be
navigable, since it is a bucket rather than a category.

#### Scenario: Uncategorized is not navigable

- **WHEN** the uncategorized row is tapped
- **THEN** nothing is pushed

### Requirement: Detail routes cover the Stats chrome

Opening a category detail screen or a budget detail screen from Stats SHALL
replace the whole Stats root route, including the month selector and tab row,
while remaining within the Stats tab above the app's bottom navigation.

#### Scenario: Opening a category detail screen

- **WHEN** the user opens a category from the Income or Expense legend
- **THEN** the category detail screen is shown without the Stats month selector or tab row

#### Scenario: Opening a budget detail screen

- **WHEN** the user opens a budget from the Budgets tab
- **THEN** the budget detail screen is shown without the Stats month selector or tab row
