# 43. `limitEvents` persists as a JSON text column, not a child table

## Status

Accepted

## Context

A budget's `limitEvents` list needed a storage shape. Normal relational practice would put it in a
child table with a foreign key to the budget row. But `limitEvents` is typically one to three
entries, is never queried independently of its parent budget (`effectiveLimit` always operates on
the whole list at once, never a single event in isolation), and the existing schema already
denormalizes structured data onto a single row elsewhere (a `RecurringPlan`'s `EntryTemplate` fields
are flattened directly onto the plan row as columns).

## Decision

`Budgets` gets one row per `Budget`. `limit_events` is a single `TextColumn` holding a JSON-encoded
array of `{effectiveFromMonth, value, kind}` objects, decoded and encoded entirely in the mapper.
Within that JSON, `YearMonth` encodes as `"YYYY-MM"`, `Decimal` as its string form (matching every
other money column in the schema), and `LimitEventKind` as its int `code` — never the JSON key name,
so a future rename of the Dart enum value never changes the wire format.

**Alternative considered:** a `budget_limit_events` child table with a foreign key to the budget.
Rejected — it would need its own version-vector story for a sub-row that is not a `SyncedRow` in its
own right, for a list that is always small and never queried independently of its parent.

## Consequences

A future feature needing to query across every budget's override months (for example, "list every
override landing next month") would need to decode every budget row rather than run one SQL query —
accepted, since no such feature is planned and the list stays small. Malformed JSON in the column
cannot be caught by Drift's own type system, only by the mapper; the mapper throws a real,
non-assert error on decode failure, consistent with the project's "unrecognized code fails loudly"
convention rather than defaulting to an empty timeline.
