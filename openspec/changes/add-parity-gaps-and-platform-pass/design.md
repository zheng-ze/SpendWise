# Design — parity gaps and platform pass

## What this phase is

Phases 1–5 translate. This phase changes behavior on purpose, which is why it is separate: a
translation that quietly improved things would make it impossible to tell a port bug from a
deliberate difference.

Everything here was deferred with a reason, not forgotten.

## Decisions

### New account types are appended, never inserted

The loan and overdraft types go at the end of the type list. Enum codes are persisted, so inserting a
case would silently change what every stored code above it means — every savings account becoming a
card, and no error anywhere. Appending is the only safe option, and it is why the domain pins explicit
codes rather than using declaration order.

### Eligibility is a gate, and it is forced on save

Only types representing money leaving the user's control may treat incoming transfers as expenses.
Cash, checking, card and prepaid are everyday spending holders — a transfer into one is moving money,
not spending it, and counting it as spending would double-count the eventual purchase.

The flag is forced off when an ineligible type is saved, rather than merely hidden. Hiding it would
leave a stale true flag on a holder that later becomes ineligible, and analysis would keep honoring
it.

### Synthetic bucket ids are derived, not stored

Each eligible type gets a deterministic synthetic id. Deriving it means no migration, no rows to keep
in sync, and the same id on every device — which matters once ledgers sync.

These buckets are not categories. They have no row, so their slices carry their own name and symbol
and cannot be drilled into; a detail screen would have nothing to show.

### Pocket destinations resolve to the parent's type

A pocket has no type of its own. Resolving to the parent is the only answer that keeps two transfers
into the same account — one to the account, one to its pocket — in the same bucket.

### The totals ruling is made here, not earlier

Phases 2 and 5 were told to leave the transactions-versus-stats divergence open and keep the call site
singular. This is where it gets decided, because deciding it earlier would have meant deciding it
before both screens existed to compare.

The spec deliberately states the *obligation* — agree, or state the difference — rather than
presuming which way it lands. That choice needs both screens in front of a person.

### Transfer scope display is designed but was never built

V2's handover designed scope-aware transfer sign and color; V1 never shipped it. A transfer out of the
account you are looking at should not read identically to a transfer into it — at scope, it is money
gone.

Account scope includes the account's active pockets, so moving money into your own pocket is internal
and stays neutral. Viewed at the pocket's own scope, the same transfer is incoming and reads as a
gain. Both are correct; the scope is what changes.

### Accessibility is specified, not "passed over"

The donut is the hard case: V1 marked it hidden from assistive technology with no alternative, so the
entire stats screen conveyed nothing. A text alternative listing buckets, amounts and shares is the
requirement.

Swipe actions and the expanding button are the other gaps — both are gesture-only affordances, which
means gesture-only functionality unless custom actions are added.

### Stored English strings stay stored

"Opening balance" and "Balance adjustment" are entry *names*, written to disk. Localization cannot
retroactively translate data. The port already marks these entries structurally at schema level, so
display-time naming can take over later without rewriting anyone's history. This phase does not
rewrite them.

## Test approach

The bucketing changes existing analysis output, so existing tests will change. That is expected — each
changed expectation should be visible in review, not absorbed by loosening an assertion.

The append-only type change gets a test that data written with the old codes still loads with the same
types. That is the test that catches an inserted case.

Eligibility needs the forced-off case tested, not just the hidden-control case: set the flag, change
the type to an ineligible one, save, and confirm the flag is false.

Scope display gets the three-way matrix — out of scope, into scope, both endpoints in scope — at both
account and pocket scope.

Accessibility gets tests that the donut exposes a text alternative and that swipe actions appear as
custom actions.
