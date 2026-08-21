# 22. Screen state lives in providers, not widget-body-constructed view models

## Status

Accepted

## Context

In the Swift app, view models were constructed inline in view bodies, so a view model's lifetime
was tied to view identity. This is why the Swift app shipped zero view-model tests — there was no
way to hold a view model without a running view to hold it. It is also a correctness problem, not
just a testing one: a widget rebuild can recreate a view model from scratch, silently resetting
state like the selected month.

## Decision

Screen-level derived state (the selected month, the active display mode, per-scope selection) lives
in Riverpod providers, constructed once and outliving any individual widget rebuild. Form
controllers stay per-sheet and auto-dispose, since a form's state genuinely should not survive past
its sheet. Derived lists and computations are pure functions of `(LedgerState, params)`, which is
what makes them unit-testable without pumping a widget at all.

This rule applies across every screen: no screen introduces its own month state, its own formatter,
or its own symbol map — they all read from the shared providers this foundation change establishes.

## Consequences

A widget rebuild can never silently reset a user's place in the app (selected month, active tab
mode), because that state does not live in the widget being rebuilt. The derivation functions behind
every screen are unit-testable in isolation, which is a real capability gap the Swift app never had.
Any new screen must put its cross-rebuild state in a provider rather than local `State` fields; an
adversarial review later confirmed this rule is enforced project-wide and flagged the one screen
that skipped it (Stats retaining its own local month/kind/range state instead of the shared
provider) as a defect to fix, not an acceptable exception.
