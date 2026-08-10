# Design — settings screens

## Layout

`app/lib/ui/settings/` holds the three sub-screens and their forms. Ordering, the kind-lock
predicate, the plan sort and the bin's section membership are pure functions; widgets call them.

## Decisions

### Plans are created from the entry form, never here

The plan list has no add button. A plan is a recurring entry, and its template needs every field the
entry form already collects — source, category, amount, analysis flag. A second creation path here
would either duplicate that form or create plans with incomplete templates.

### The plan form cannot change a plan's source

Source is displayed read-only. Changing it would silently orphan the plan's already-generated
entries from the holder they were posted to, and there is no sensible answer to what should happen to
them.

### Amount is a magnitude; the sign is preserved

The form edits the amount as a positive number and reapplies the template's original sign on save.
Letting a user type a sign here would let an expense plan quietly become an income plan, which no
other surface in the app allows.

### Editing a plan does not regenerate history

Moving the anchor earlier generates nothing for the intervening period; the resolution cursor governs
what comes next. This follows from the domain's forward-only cursor and is stated in the spec because
it is the behavior a user is most likely to expect otherwise.

### A deterministic tiebreak where V1 had none — flagged strengthening

V1 sorts plans by next occurrence with ended plans last, tiebreaking by name only between two ended
plans. Two plans sharing a non-null next date have unspecified relative order, so the list can
reshuffle between renders for no visible reason.

The port applies the name tiebreak in both cases. Strictly more predictable, and flagged rather than
silent.

### The restore no-op is preserved deliberately

Restoring a pocket whose parent is still archived does nothing at all — the swipe appears to work and
the row stays. That is a domain rule (restore the parent first), not a UI bug, so the port keeps it.

Making the affordance honest — disabling it, or offering to restore the parent too — is a real UX
improvement and belongs to Phase 6. Doing it here would be redesigning during a translation.

### The purge copy gets its missing space

V1's string interpolation swallowed the space after a sentence-ending period, rendering two words run
together. The corrected copy is the spec. This is a typo fix, not a rewrite.

### Two deletion paths, two confirmation rules

Deleting a category from the list confirms; deleting from within its form does not. Same asymmetry as
the entry form, same reasoning: the form path is already several deliberate taps deep. V1 parity.

## Test approach

The pure functions carry the weight: category list ordering, the kind-lock predicate, the delete
copy's singular and plural forms, the plan sort matrix including plans with no next occurrence and the
tiebreak, the plan save's sign preservation, bin section membership with reference counts, and purge
routing by row kind.

The sign-preservation test matters most — it is the one that catches a plan silently changing kind,
which no other test in the suite would notice.
