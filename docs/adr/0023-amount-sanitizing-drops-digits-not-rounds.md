# 23. Amount input sanitizing drops excess digits instead of rounding

## Status

Accepted

## Context

An amount field needs to reject more than two fraction digits as the user types. Rounding on
keystroke was one option, but it means a partially-typed number mutates under the cursor: typing
`1.005` would watch the field rewrite itself as `1.01` (or similar) mid-entry, which is confusing
and does not match what the user is trying to type.

## Decision

The sanitizer drops a third fraction digit rather than rounding to it. This matches the Swift app's
existing behavior and is judged the correct behavior independent of parity. The sanitizer is a pure
function with a text-input formatter wrapped around it, so the dropping rule is directly unit-
testable without a running widget.

## Consequences

A user typing `1.005` sees `1.00` — the third digit is simply refused, not rounded away after the
fact. Any future change to amount-field input handling must preserve "reject extra input" over
"silently correct it after the fact"; the second approach reintroduces the mutate-under-cursor
problem this decision avoids.
