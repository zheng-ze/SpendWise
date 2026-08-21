# 5. Recurring-plan month-end strides clamp instead of overflowing

## Status

Accepted

## Context

Swift's `Calendar.date(byAdding:)` clamps a monthly stride off 31 January to the end of February —
adding one month to 31 January yields 28 or 29 February, not 3 March. Dart's `DateTime`
constructor has no such clamping: `DateTime(2026, 2, 31)` silently overflows into March instead of
raising an error or clamping.

A straight translation of the Swift stride math would therefore either overflow silently (wrong
date, no error) or need its own clamp to reproduce Swift's actual behavior.

## Decision

The port adds an explicit clamp so a monthly (or other month-based) stride off a day near month-end
lands on the target month's last valid day, matching Foundation's clamping behavior. Every stride
is measured from the plan's anchor date, never from the previous occurrence, so the clamping never
accumulates drift across many occurrences — each occurrence is computed independently from the
same anchor.

## Consequences

A plan anchored on the 31st recurs on the last day of every shorter month, exactly as it would
under Swift's calendar, but the port's clamp is explicit code rather than an incidental platform
behavior. Any future change to the stride math must preserve measuring from the anchor, not the
previous occurrence — measuring from the previous occurrence would let a clamped short month
permanently shift the anchor day for every later occurrence.
