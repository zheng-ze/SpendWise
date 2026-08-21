# 39. A budget names one category (or none); combined caps use category-parent rollup

## Status

Accepted (revised — see ADR-0045 for the later reversal of the top-level-only restriction)

## Context

Some users want one spending cap covering several related categories at once (a combined "Food"
budget covering Fast Food and Restaurants separately). The obvious model is a multi-select set of
category ids on a budget. But categories already form a real two-level parent/child hierarchy, and
the app already rolls a parent's spend up across its children elsewhere in the UI.

## Decision

`Budget.categoryID` is a single nullable field, fixed at creation (`null` means an overall budget
covering every category; at most one budget may have a null category at a time). A budget placed on
a parent category can use the existing parent/child spend rollup to cover the "combined cap" use
case a multi-select set was meant to solve — a cap over Food covers Fast Food and Restaurants for
free, provided they already share the Food parent. This removed the need for a multi-select category
set entirely.

**Alternative considered:** a `Set<String> categoryIDs` field. Rejected — it needs its own overlap
and uniqueness rules, and the parent-rollup approach gives the same practical outcome for the
common case (categories that already share a parent) without a new collection-valued field.

## Consequences

Two categories that don't already share a parent can never be capped by one budget — a permanent
limitation of this model, not a temporary gap. A user wanting that needs to restructure their
category tree so the two share a parent, or track two budgets separately. This is accepted as the
direct cost of avoiding multi-select.
