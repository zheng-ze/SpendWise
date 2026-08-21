# 48. A plan's resolution cursor stops at the earliest failed occurrence

## Status

Accepted

## Context

An adversarial review found that `resolvePlans` permanently dropped occurrences that failed
validation: it recorded a `PlanFailure` for a failing occurrence but still advanced the cursor
(`lastResolvedDate`) past it unconditionally, since the advance and the per-occurrence failure
tracking were not linked. Concretely: a recurring rent plan whose source account gets archived on
its due date throws for that occurrence, records the failure, but the cursor moves past that date
anyway — restoring the account afterward and re-running resolution can never regenerate a date the
cursor has already passed, since occurrence generation is exclusive of the cursor.

## Decision

`resolvePlans` computes the earliest failed date within the current sweep's due list, if any exists,
and advances the cursor only to that date rather than to "now" — since setting the cursor to a date
makes generation exclusive of that date, this makes the failed date (and everything chronologically
after it, even occurrences that "succeeded" within this same sweep) eligible again on the next
sweep.

**Alternative considered:** track a separate sparse set of failed dates for individual retry,
rather than moving the single cursor backward. Rejected as a deliberate simplification — the sparse-
set approach avoids one redundant lookup (a day that already succeeded and materialized an entry
gets re-checked and skipped as "already materialized" on the next sweep under the cursor approach),
but it adds real state-shape complexity (a set that itself has to survive persistence) for a cost
that is one cheap idempotent check.

## Consequences

A plan that hits a validation failure never permanently loses that occurrence — resolving again
after the underlying problem is fixed regenerates it. The cost accepted is that occurrences after
the failure that already succeeded in the same sweep get redundantly re-checked (and skipped as
already-materialized) on the next sweep, rather than being tracked as individually already-done.
