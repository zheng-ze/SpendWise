# 36. Plans are created only from the entry form; a plan's source is immutable

## Status

Accepted

## Context

The settings screen's plan list needed to decide whether to offer its own "add plan" button, or
route plan creation exclusively through the entry form (where a recurring option is one field among
several). A plan is fundamentally a recurring entry, and its template needs every field the entry
form already collects — source, category, amount, the analysis-inclusion flag. A second creation
path in settings would either duplicate that entire form or produce plans with an incomplete
template.

Separately, once a plan exists, its source holder is displayed read-only in the plan edit form.
Changing a plan's source after the fact would silently orphan every entry the plan has already
generated from the holder they were actually posted to — and there is no sensible rule for what
should happen to that already-generated history.

## Decision

The plan list has no add button; plans are created only from the entry form's recurrence option.
The plan edit form shows source as read-only and offers no way to change it — changing a plan's
source requires deleting the plan and creating a new one.

## Consequences

There is exactly one code path that constructs a `RecurringPlan` template, so the template is
always complete by construction; there is no second, leaner creation path to keep in sync with the
first. A user who wants to redirect a recurring entry to a different account must delete and
recreate the plan, losing the option to keep its history attached — this is accepted as the
simpler, safer rule over inventing an answer for what reassignment should do to already-generated
entries.
