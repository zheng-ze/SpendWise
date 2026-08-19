# app-shell Specification

## Purpose
Defines the frame the app lives in: how the four sections are reached, what is shown while the app is
starting or has failed to start, and how background errors are surfaced without interrupting work.

## ADDED Requirements
### Requirement: Adaptive navigation

The shell SHALL present four destinations — transactions, stats, accounts and settings, in that
order. It SHALL use a bottom navigation bar on compact widths and a side rail on wide ones, with the
same destinations and labels in both.

#### Scenario: Wide window

- **WHEN** the window is wide
- **THEN** navigation is presented as a side rail rather than a bottom bar

### Requirement: Per-destination navigation stacks

Each destination SHALL own its navigation stack, and switching destinations SHALL preserve each one's
stack. Returning to a destination SHALL show it where the user left it, not reset to its root.

#### Scenario: Returning to a drilled-in tab

- **WHEN** the user drills into a detail view, switches destination, and switches back
- **THEN** the detail view is still shown

### Requirement: Boot chrome

While starting, the shell SHALL show a progress indicator. On failure it SHALL show a message that
data could not be loaded, the error description, and a retry control that restarts the whole boot
sequence. When ready, it SHALL show the navigation shell.

#### Scenario: Startup failure offers retry

- **WHEN** startup fails
- **THEN** the failure message, its cause, and a retry control are shown

### Requirement: Screen state survives rebuilds

State a screen depends on — the selected month, the active sub-tab, an expanded row — SHALL live in
providers rather than in widget-local state, so that a shell rebuild cannot silently reset it.

#### Scenario: Shell rebuild preserves selection

- **WHEN** the shell rebuilds while a non-current month is selected
- **THEN** that month is still selected

### Requirement: Status banner

The shell SHALL show a persistent banner while a save problem or a plan-resolution failure is
outstanding, with the plan-error message taking precedence when both apply.

The save banner SHALL persist for as long as the state is non-clear rather than disappearing on a
timer, since it reflects an ongoing condition.

#### Scenario: Save trouble persists

- **WHEN** the store reports it is retrying
- **THEN** the banner stays visible until the store reports the problem cleared

#### Scenario: Plan error takes precedence

- **WHEN** a plan failure and a save problem are outstanding at once
- **THEN** the plan message is the one shown

### Requirement: First run is not empty

First launch seeds sample data before state is loaded, so the first render SHALL show content rather
than empty states.

Empty states SHALL still be built, since they remain reachable by deleting everything or by
navigating to a month with no activity.

#### Scenario: Reachable empty state

- **WHEN** the user views a month with no entries
- **THEN** the empty state is shown
