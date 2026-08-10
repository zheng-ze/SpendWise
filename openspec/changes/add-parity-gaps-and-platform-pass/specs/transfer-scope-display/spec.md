# transfer-scope-display Specification

## Purpose
Defines how a transfer reads depending on what you are looking at, so that money leaving the account
on screen does not look identical to money arriving in it.

## ADDED Requirements
### Requirement: Scope-aware transfer sign

When a transaction list is scoped to a holder, a transfer SHALL be displayed relative to that scope:
leaving the scope reads as a loss, entering it reads as a gain.

A transfer with both endpoints inside the scope, and any transfer viewed in an unscoped list, SHALL
read neutrally as it does today.

#### Scenario: Transfer out of the viewed account

- **WHEN** a transfer moves money from the scoped account to another
- **THEN** it displays as a loss

#### Scenario: Both endpoints in scope

- **WHEN** a transfer moves money between an account and its own pocket, viewed at account scope
- **THEN** it displays neutrally

### Requirement: Pocket scope membership

An account's scope SHALL comprise the account together with its active pockets, so a transfer between
an account and its own pocket is internal to that scope.

A pocket's own scope SHALL comprise only that pocket.

#### Scenario: Viewed at pocket scope

- **WHEN** the same account-to-pocket transfer is viewed scoped to the pocket alone
- **THEN** it displays as a gain
