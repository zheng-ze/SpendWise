# 27. A week spanning two months appears in full under both, not clipped

## Status

Accepted

## Context

The month-breakdown view groups transactions by week within a month. A week can span a month
boundary — a few of its days in one month, the rest in the next. Two choices: clip the week's range
and total to just the days inside the current month (so the same week could show two different
totals depending on which month you view it from), or show the whole week, full range and full
total, under both months it touches.

## Decision

A spillover week is listed in full under both months it overlaps, with an identical range and total
in each listing. This matches the Swift app's behavior and is judged the lesser evil: clipping would
make the week's own total disagree with itself depending on which month it was opened from, which is
more confusing than seeing the same week twice.

## Consequences

A user scrolling through two consecutive months' breakdowns sees one week duplicated in full between
them, with matching totals in both places — this is by design, not a rendering bug. Any future
change to month/week grouping must preserve full-range duplication for a spillover week rather than
clipping it to the viewing month.
