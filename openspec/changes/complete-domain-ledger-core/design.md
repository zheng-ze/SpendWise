## Context

See proposal.md — Why. `packages/domain` currently holds the int-coded enums and the model value types
(`Entry`, `Account`, `SubPocket`, `TransactionCategory`, `MoneySource`, `HolderReferencing`, `ids.dart`)
and nothing else. This change adds everything between those models and the surfaces that will consume
them.

Constraints that shape the approach:

- The frozen SwiftUI app at `../SpendWise-SwiftUI` is the behavioral source of truth. The port is a
  translation; deviations happen only where a spec sanctions one.
- `docs/modules/domain_models.md` is the authoritative spec for this change. Section numbers referenced
  below are its own: §1.7/§1.9 (types), §2 (queries), §3.1–3.8 (mutators), §6 (invariants), §7 (the
  defect), §8 (the 68-test inventory).
- `packages/domain` must stay Flutter-free, which the absent `flutter:` key in its pubspec enforces.
- Recurring Plans are out of the MVP, so the plans map, plan mutators and the plan cascade in
  `deleteAccount` are absent by design.

## Goals / Non-Goals

**Goals:**

- A `LedgerState` whose behavior matches the Swift original clause for clause, except where §7 mandates
  the fix.
- An observable check order in entry validation that a later refactor cannot silently reorder.
- Test-ordering matchers that assert exactly as much as the spec guarantees and no more.
- A commit sequence where each step is independently green.

**Non-Goals:**

- Accounting, balances and statement math (Phase 2). Where a Swift test asserted through `balance`, the
  Dart test asserts on stored entry fields and is upgraded in Phase 2.
- Persistence (Phase 4). This change only makes sure the codes and id casing persistence will depend on
  stay pinned.
- Any `copyWith` or null-sentinel machinery. The mutator surface takes whole objects, so there is no
  "omitted versus explicitly null" ambiguity to model.
- Range validation on `statementDay`. The spec specifies only the non-card null-forcing and has no test
  for a range; its real consumer is statement-cut math in a later phase.

## Decisions

### Sealed class hierarchies for `LedgerChange` and `LedgerError`

Swift models both as enums with associated values. Dart's closest faithful shape is a sealed base class
with one final subclass per case, giving exhaustive `switch` and per-case payload types.

`LedgerError implements Exception` so it can be thrown directly. Both hierarchies get hand-written
value `==`/`hashCode`, because tests compare whole change lists and exact error values.

The `targetID` getter is declared abstract on the sealed base rather than implemented as a `switch` in
one place. An abstract member makes a missing case a compile error at the point a new case is added,
which is what "total" has to mean for a getter persistence coalesces by.

`LedgerChange.upsertSource(MoneySource)` is a static factory that switches on the source variant. Swift
overloads `upsert(_:)`; Dart cannot, so the name differs deliberately.

Alternative considered: a single enum plus a dynamic payload field. Rejected — it loses payload typing
and makes exhaustiveness unenforceable.

### File layout mirrors the Swift section order

`ledger_state.dart` orders its members as accounts and pockets (§3.1), entries and `_validated`
(§3.2–3.3), categories (§3.4), archive (§3.6), restore (§3.7), purge and sweep (§3.8), then the private
reference helpers. Queries and invariants live in `part of` files so they can reach private members
while keeping `ledger_state.dart` navigable.

Alternative considered: extensions in separate libraries. Rejected — extensions cannot see private
members across files, and the sweep and reference helpers are private by design.

### `_validated` is a literal top-to-bottom sequence

The 9-step check order is externally observable: a transfer carrying a category throws a kind mismatch
even when the destination is also invalid, and a zero amount throws before any lookup. The
implementation is a flat sequence of guards in spec order, not a set of composed validators, precisely
so a refactor cannot reorder it without visibly rewriting it.

### The §7 defect fix lands as one indivisible commit

The corrected reference rule, the pocket-before-account purge order, the deferred parent cascade and the
sweep rule interlock across four call sites. Splitting them produces a red intermediate state. The three
regression tests are written first, inside that same commit: they are the only tests a faithful Swift
translation would fail, so they are the proof the fix landed rather than the bug.

The invariant amendment that clause 9 needs (an account satisfies reference-only via a surviving pocket)
is inseparable from the fix but lands with the invariants commit, since no invariant code exists before
it.

### Two ordering matchers, decided before the emission suite

Where Swift iterated a `Set` or `Dictionary`, order within that group is unspecified and only
between-group order is guaranteed. So `addPocket`'s two changes assert as an ordered list, while an
account archiving N pockets asserts containment plus relative position. Both matchers live in
`test/support/matchers.dart` and the choice is made per assertion. Dart's insertion-ordered maps may
make the weaker case deterministic in practice; tests must still not demand more than the spec
guarantees, or they pin an implementation detail.

This is the most likely source of flaky ported tests, which is why the convention is fixed before the
emission suite is written rather than during it.

### Test support is two small files

`builders.dart` (a default savings account named "acc", a default expense category with colour
"#888888", symbol "tag", included in analysis) and `matchers.dart`. Nothing more is built until a test
needs it.

Swift's `applyIgnoringChanges` is not ported. It existed only because the mutators lacked
`@discardableResult`, so every setup line warned; Dart does not warn on an ignored return value, and the
wrapper would make every setup line longer while changing nothing.

### The account/pocket link stays on the parent, and the maps get closed

`Account.subPocketIDs` keeps the link; `SubPocket` gains no `parentID`. This was weighed on engineering
merit alone, not on Swift parity, after the orphan-pocket work exposed how much guard machinery exists
to keep the two structures agreeing.

Inverting was rejected because it relocates costs rather than removing them. The guard does not go
away: `_willOutliveParentCategory` is the same guard on the `parentID` side, so a hierarchy with an
ordered lifecycle needs a child-side check either way. Accounts and pockets share one id space and one
table, so a bare `String parentID` on a pocket is not type-constrained to accounts — pocket-parented-to-
pocket, self-parenting and cycles all become representable and would need a runtime validator, which is
exactly the `_validateParent`/`CategoryTooDeep`/`CategoryKindMismatch` tax the category side already
pays and the pocket side does not. `activePockets` and both lifecycle cascades are O(children) today and
would become full table scans, and `netWorth` would turn O(accounts) into O(accounts × sources) unless
callers remember to pre-group.

The real defect the investigation surfaced is not the link direction. It is that `moneySources`,
`entries` and `categories` are handed out as mutable maps, so one direct write bypasses every guard.
Probing all four public-API routes to an orphan active pocket — `addPocket` onto an archived parent,
`restorePocket` under one, `updatePocket` forcing active, `updateAccount` dropping the link — found all
four already closed; only a direct map write produces one. The same hole is what makes a pocket with two
parents and an order-dependent `_owningAccount` reachable. Closing the maps (task 7.0) fixes that class
of bug whichever way the link points, and `_detachAndTombstonePocket` as the sole pocket-row remover
(7.3) makes detach-and-survive unreachable by construction.

Two costs of this decision are accepted rather than solved. `sourceName` pays an O(accounts) scan per
rendered row to build "Parent/Child", which inversion would make O(1) for free; revisit with
measurements from the real UI, not on principle. And the cost of inverting rises monotonically — there
is no persistence layer or on-disk data yet, so this is the cheapest this change will ever be. Neither
outweighs the above today.

## Risks / Trade-offs

- **A faithful translation of §7's call sites reproduces the bug.** → Regression tests are written
  before the fix within commit 1.9, and each is required to fail against the unfixed behavior.
- **Ported tests over-assert on unspecified iteration order and go flaky.** → The two-matcher convention
  is fixed before the emission suite, and containment-plus-position is the default for set-derived
  groups.
- **Mutable models would let a mutator edit an object already emitted in a change**, making the emission
  tests compare an object to itself and pass regardless. → Models are immutable with hand-written value
  equality, and `equatable` stays out: its `props` list is a silent-failure surface for exactly these
  tests.
- **Check-order regressions are invisible to ordinary tests.** → The validation tests assert which error
  wins when two conditions are simultaneously violated, not merely that some error is thrown.
- **The dereference sweep is the only reference-only exit**, so a missed sweep call leaks rows that
  invariant clause 9 will only catch on the next check. → `assertInvariants` runs after every mutation
  in debug, and the ported suite calls it explicitly at the end of lifecycle tests.
- **`sourceName` scans every money source per rendered row**, so a long transaction list pays
  O(rows × accounts) to display "Parent/Child". → Accepted for now; the constant is small at realistic
  cardinalities. If it ever shows under real UI load the fix is a derived `pocketID → accountID` index
  rebuilt on mutation, which is a cache validatable against the table rather than a second authority.
- **Keeping the link on the parent leaves "pocket in two accounts" representable**, where a single
  `parentID` field could not hold two values. → Closing the maps (7.0) makes it unreachable through the
  API, `_detachAndTombstonePocket` (7.3) is the sole remover, and invariant clause 2 is the backstop.
  The residual risk is that a future mutator reintroduces it, which is what 8.2's post-mutation
  `assert` exists to catch.

## Migration Plan

Not applicable. `packages/domain` has no consumers beyond its own tests and no persisted data yet.

## Open Questions

None. The three rulings the completed reviews flagged as blocking — half-open windows, version-vector
decode-as-error, reserved persistence columns — are already resolved in the module specs and are not
re-litigated here.
