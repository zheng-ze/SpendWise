# 58. Views call named ViewModel methods through an interface; loading/error via `AsyncNotifier`; navigation via a nonce-based intent field

## Status

Accepted

## Context

ADR-0057 required every ViewModel to expose exactly one entry point, `transform(Input) ->
Output`, built on `Stream`-based `Input` and `ValueListenable`-based `Output`. Before any code
was written against it, a consensus check (two independent models reviewing the design) found
its core premise broken:

- **`transform` cannot run exactly once.** Riverpod recreates a ViewModel and re-runs `build()`
  whenever `autoDispose` reclaims it, a `family` parameter changes, or a `ref.watch` dependency
  changes. The View's `Input` streams, created once, are orphaned from the new ViewModel
  instance — a silent freeze, not a crash.
- **Dart `Stream`s are single-subscription.** Any re-binding attempt throws `StateError`, rather
  than degrading gracefully, the moment the pattern above occurs.
- **The design contradicted itself on disposal.** "ViewModel has zero Riverpod import" and
  "disposal is provider-owned via `ref.onDispose`" cannot both hold, since the ViewModel has no
  way to call `ref.onDispose` itself without importing Riverpod.
- **No home for loading or error state.** `ValueListenable`-based `Output` discards Riverpod's
  `AsyncValue`, which every screen loading from persistence (nearly all of them) needs.
- **No answer for navigation, dialogs, or awaited results.** A fire-once `Stream<void>` models
  "a tap happened," not "show a dialog and use its result."

A follow-up `/grilling` session re-examined the actual goal behind ADR-0057: the View must never
*decide* what a user's input means — parsing, validation, and interpretation belong to the
ViewModel. That goal does not require a single entry point; it only requires that a View's calls
into its ViewModel carry raw, uninterpreted values.

## Decision

**Views call named methods on their ViewModel.** Each method takes only raw, unparsed values —
a `String` from a text field, a `bool` from a toggle, an enum selection — never a value the View
computed or validated. Interpreting that raw value (parsing a `String` into a `Decimal`,
validating it, deciding what it implies) happens inside the method body, on the ViewModel side.
This preserves ADR-0057's actual goal — the View never decides what an input means — without the
single-entry-point mechanism that broke under Riverpod's lifecycle.

**Each ViewModel implements an abstract interface declared per screen.** For example:

```dart
abstract class BudgetDetailViewModel {
  Future<void> saveBudget(String rawAmount, String? rawNote);
  Future<void> deleteBudget();
}
```

The View depends on this interface type, never on the concrete Riverpod-wrapped class. This is
the decoupling ADR-0057 was reaching for: the View is testable against the interface without
touching Riverpod, and swapping the ViewModel's internals never touches View code. The interface
is not enforced by tooling — no custom lint — since that is disproportionate infrastructure for a
solo-maintainer project; it is a documented convention, checked the same way any other code
review catches a violation.

**Any ViewModel backing a screen that loads data uses `AsyncNotifier<ViewState>` as its base**,
and the View renders via `AsyncValue.when(data:, loading:, error:)`. This is Riverpod's own
idiomatic equivalent of Flutter's official architecture guide's `Command<T>` wrapper — the guide's
pattern is state-management-agnostic and predates Riverpod-specific tooling; `AsyncNotifier` is
what the same concept looks like in the state-management library this app already depends on.
Nearly every screen in `app/lib/ui` loads from persistence, so this is the default, not a special
case. A ViewModel that also wraps a plain `ChangeNotifier` service (not only `Ledger`) inside
`build()` must await that service's own async work there rather than firing it and forgetting it —
see ADR-0059's issue-#38 amendment for the race this avoids.

**Superseded by ADR-0059**: the `NavigationIntent` mechanism below, and the View performing
`Navigator` calls itself, is replaced by ADR-0059's `Flow`/`Step` design — the View was found to
still need destination-mapping knowledge under this scheme, which ADR-0059 removes entirely.
Everything else in this ADR (named methods, interface decoupling, `AsyncNotifier`) is unchanged
and still Accepted.

**Navigation is decided by the ViewModel and performed by the View, coordinated through a
nonce-identified field on `ViewState`**, not a boolean or a plain nullable value:

```dart
class NavigationIntent {
  final int id; // monotonically increasing, or any per-instance-unique value
  final Object destination; // whatever shape a route needs
}
```

The ViewModel sets `ViewState.pendingNavigation` when it decides navigation should happen. The
View compares the intent's `id` against the last `id` it acted on; on a new `id`, it performs the
actual `Navigator` call and records that `id` as handled. This is deliberately not a plain
non-null check with an explicit "clear the signal" method call: a nonce makes the View's
navigation-handling purely reactive and idempotent against unrelated rebuilds, closing the same
class of "forgot a step" gap that broke ADR-0057 — there is no step the View can forget, only a
comparison it always performs. No Coordinator or Navigator class is introduced; no router package
(`go_router`, `auto_route`) is a dependency of this app, and no such class is an established
convention in the Flutter/Riverpod ecosystem the way ReactiveCocoa's coordinators are on iOS. The
research behind this finding is in the ticket resolution for the map's charting session
(wayfinder map issue #30).

## Consequences

A ViewModel's public surface is now a small, named set of methods instead of one method — the
tradeoff ADR-0057 was trying to avoid. This is accepted because the property that actually
mattered (the View never interprets an input) does not depend on method-count; it depends on
methods taking raw values only. Reviewing a View for a violation means checking its ViewModel
calls carry no computed arguments, not counting methods.

Testing a ViewModel now means calling its methods directly and asserting on the resulting
`AsyncValue<ViewState>` — closer to testing any other Riverpod notifier, with no bespoke `Input`
harness needed. This is less novel, and less risky, than testing the dropped `transform` shape
would have been.

`ViewState` carries both the data a screen renders and, when relevant, a one-shot navigation
signal in the same object. This is an accepted mixing of concerns: splitting navigation intent
into a separate provider was considered and rejected as more machinery than a nonce-identified
field justifies for a solo-maintainer project. If a screen's navigation logic grows complex enough
that this stops being comfortable, revisit this decision rather than special-casing that one
screen.

The `budgets/` proof migration (issue #33) is the first ViewModel built against this design; any
gap it surfaces gets folded back into this ADR and `CONTEXT.md`'s MVVM vocabulary before that
ticket closes, the same commitment ADR-0057 made and did not get to keep.
