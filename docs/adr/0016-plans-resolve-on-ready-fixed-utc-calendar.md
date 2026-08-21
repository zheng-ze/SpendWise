# 16. Plans resolve once on entering ready, always against a fixed UTC calendar

## Status

Accepted

## Context

iOS fires an initial activation event that races the app's async boot sequence and is usually
swallowed by a "ready" guard — V1 frequently did **not** resolve recurring plans on a cold start,
and occurrences only materialized on the next foregrounding. Flutter does not fire a resume event
for the initial launch at all, so a literal translation of "resolve plans on resume" would resolve
even less often than the already-flawed V1 behavior.

Separately, plan-occurrence math must never depend on the device's local calendar: resolving
against a device-local calendar would recreate exactly the timezone-dependent occurrence ids the
UUIDv5 lowercase-normalization decision exists to eliminate.

## Decision

The runtime resolves plans once, explicitly, on entering the ready boot phase — at boot, on every
resume, and immediately after creating a plan from the entry form. This is a flagged deviation from
V1, not parity: it is strictly more reliable than the Swift original's race-prone behavior, and
that reliability is deliberate rather than incidental.

Every resolution call passes a fixed UTC calendar, never the device calendar, at every one of
those call sites without exception.

## Consequences

A cold start in this port always resolves due occurrences immediately, where V1 often deferred them
to the next foregrounding — anyone comparing behavior against the Swift app should expect this
difference and not treat it as a bug. Any future call site that triggers `resolvePlans` must pass
the fixed UTC calendar; a device-local calendar at even one call site would reintroduce
timezone-dependent occurrence ids for plans resolved through that path.
