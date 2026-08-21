# 37. The plan list gets a deterministic sort tiebreak the Swift app never had

## Status

Accepted

## Context

The Swift app sorts recurring plans by next-occurrence date, with ended plans sorted last and a
name tiebreak applied only between two ended plans. Two live plans sharing the same non-null next
occurrence date had no defined tiebreak at all, so their relative order in the list was unspecified
and could visibly reshuffle between renders for no reason a user could see.

## Decision

The port applies the same name tiebreak uniformly, in both the ended-plans case and the
live-plans-with-equal-dates case. This is flagged explicitly as a strengthening beyond Swift parity,
not left as a silent behavior change — it is strictly more predictable than the original, and the
plan sort's test matrix covers the tiebreak case specifically so it stays covered.

## Consequences

Two plans with the same next-occurrence date always appear in the same relative order across
renders, sorted by name — a user's plan list never visibly reshuffles for reasons they can't see.
Any future change to plan-list sorting must preserve a total order (no case left to unspecified
relative ordering), since an unspecified case is exactly the defect this decision closes.
