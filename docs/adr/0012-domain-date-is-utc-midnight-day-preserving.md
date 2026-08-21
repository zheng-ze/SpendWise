# 12. A domain date is UTC midnight of the calendar day it names, normalized day-preserving

## Status

Accepted

## Context

Every `DateTime` the domain stores represents a calendar day, not an instant — a date is "1 May
2026", not a specific moment in time. Dart's `DateTime.now().toUtc()` looked like the obvious way
to normalize a date to UTC, but it preserves the *instant* and moves the *calendar day*: a
Singapore local midnight on 1 May becomes `2026-04-30T16:00Z`, shifting the entry into the previous
month for every user east of Greenwich. Window filters compare against UTC bounds and occurrence
ids hash the normalized day, so an un-normalized local midnight would both land in the wrong month
at a boundary and re-mint occurrence ids after a timezone move.

## Decision

Normalization is day-preserving, not instant-preserving, implemented once as
`startOfDayUtc` in `calendar_day.dart`:

```dart
DateTime startOfDayUtc(DateTime date) => DateTime.utc(date.year, date.month, date.day);
```

This reads the date's own year/month/day components and reconstructs them as UTC midnight,
keeping 1 May as 1 May regardless of the timezone the input carried. `.toUtc()` is never a
substitute for this and must not be used on a domain date.

Normalization happens at construction, the same house rule the id-normalization convention
follows: make the illegal state (a non-normalized date) unreachable by construction, rather than
correcting it at every comparison site. `RecurringPlan`'s `anchor`/`endDate`/`lastResolvedDate` and
`OccurrenceID.make` already normalized this way; `Entry.date` and `AnalysisItem.date` were the
remaining gap this decision closed.

## Consequences

Every date-bearing model normalizes at its own construction boundary, so a date read back out of
any domain type is guaranteed to already be UTC midnight — no call site needs to re-normalize
defensively. Persistence inherits this for free: a stored date round-trips as UTC midnight with no
timezone information needing to travel alongside it. Any future code that touches a device-local
`DateTime` before it reaches the domain must convert with `startOfDayUtc`, never `.toUtc()`.
