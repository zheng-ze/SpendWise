# Add the settings screens

## Why

Three domain capabilities have no surface at all: categories can be created and nested but not
managed, plans can be created from the entry form but never edited or deleted, and the recycle bin —
the entire reason deletion archives rather than destroys — is unreachable. An archived account is
currently gone from the user's point of view, with no way to bring it back.

This is the last screen group of Phase 5.

## What Changes

- Add the settings root: navigation into categories, recurring plans and the recycle bin.
- Add the category list: income and expense sections with roots and their indented children, an edit
  mode, an analysis-exclusion marker, and per-parent subcategory creation.
- Add the category form: name, a kind that locks while entries reference the category, symbol, color,
  analysis inclusion and parent, with one level of nesting enforced by the domain.
- Add the symbol picker: a searchable sectioned grid over the catalog.
- Add the plan list, ordered by next occurrence with ended plans last, and the plan form, which
  preserves the template's original sign and cannot change a plan's source.
- Add the recycle bin: archived accounts, pockets and categories with their reference counts, restore
  by swipe, and purge behind a confirmation that explains what purging costs.
- Fix the purge confirmation's missing space, which V1 rendered as run-together words.

Not **BREAKING**: additive. No domain, runtime or persistence behavior changes.

## Capabilities

### New Capabilities

- `category-management`: listing, creating, editing and deleting categories, including the kind lock
  and the symbol and color pickers.
- `plan-management`: listing and editing recurring plans, including their ordering and what a plan's
  form may and may not change.
- `recycle-bin`: viewing archived rows with their reference counts, restoring them, and purging them.

### Modified Capabilities

None.

## Impact

- New code in `app/lib/ui/settings/`, with the derivations kept separate from widgets.
- New tests in `app/test/ui/settings/`.
- No new dependencies.
- No change to `packages/domain/`, the runtime or persistence.
- Two deliberate deviations from V1 (`design.md`): the fixed confirmation copy, and a deterministic
  name tiebreak for plans sharing a next occurrence date, where V1's order was unspecified.
- One V1 behavior deliberately preserved despite looking like a bug: restoring a pocket whose parent
  is still archived does nothing. That is a domain rule, and changing the affordance is Phase 6 work,
  not a port default.
