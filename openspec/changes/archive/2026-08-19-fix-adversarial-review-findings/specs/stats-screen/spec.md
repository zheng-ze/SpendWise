## MODIFIED Requirements

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
