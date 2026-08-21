# 41. Deleting a budget hard-removes it; no tombstone

## Status

Accepted

## Context

`Account` and `Category` soft-delete (archive, then tombstone) because entries reference them by id
and the domain needs a defined answer for what a dangling reference means. `RecurringPlan` hard-
deletes with no lifecycle field at all, since nothing else in the domain references a plan by id.

## Decision

`deleteBudget` removes the budget outright, the same as `deletePlan` does for a `RecurringPlan` —
no lifecycle field, no tombstone row left behind.

Nothing in the domain references a `Budget` by id, so there is no dangling-reference case to guard
against, and adding a tombstone concept would only introduce a lifecycle state nothing else ever
needs to check.

## Consequences

A deleted budget's `LimitEvent` history is gone permanently — there is no recycle-bin entry or
restore path for a budget, unlike accounts and categories. When a category a budget names is itself
deleted or tombstoned, the matching budget is cascade-deleted in the same operation (mirroring how a
plan naming that category is also removed) — there is no partial-cascade case to define, since a
budget names exactly one category.
